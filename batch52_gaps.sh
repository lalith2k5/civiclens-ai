#!/bin/bash
set -e

ROOT=~/Desktop/civiclens-ai
API_DIR=$ROOT/apps/api
WEB_DIR=$ROOT/apps/web

echo "1. Updating Database Models for Comments and Duplicate Links..."
cat >> $API_DIR/app/models/models.py << 'EOF'

class Comment(Base):
    __tablename__ = "comments"
    id = Column(Integer, primary_key=True, index=True)
    complaint_id = Column(Integer, ForeignKey("complaints.id"))
    author_id = Column(Integer, ForeignKey("users.id"))
    body = Column(String)
    visibility = Column(String, default="public") # public or private
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

class DuplicateLink(Base):
    __tablename__ = "duplicate_links"
    id = Column(Integer, primary_key=True, index=True)
    source_complaint_id = Column(Integer, ForeignKey("complaints.id"))
    parent_complaint_id = Column(Integer, ForeignKey("complaints.id"))
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
EOF

cd $API_DIR && source $ROOT/.venv/bin/activate
export PYTHONPATH=$PYTHONPATH:$(pwd)
python -c "from app.database import engine, Base; from app.models.models import *; Base.metadata.create_all(bind=engine)"
cd ../..

echo "2. Adding Backend Endpoints for Comments and Linking..."
cat >> $API_DIR/app/api/ops.py << 'EOF'

from ..models.models import Comment, DuplicateLink
from pydantic import BaseModel

class CommentCreate(BaseModel):
    body: str
    visibility: str = "public"

class LinkCreate(BaseModel):
    parent_id: int

@router.get("/reports/{report_id}/comments")
def get_comments(report_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    comments = db.query(Comment).filter(Comment.complaint_id == report_id).order_by(Comment.created_at.asc()).all()
    return [{"id": c.id, "body": c.body, "visibility": c.visibility, "created_at": c.created_at, "author": db.query(User).filter(User.id == c.author_id).first().name} for c in comments]

@router.post("/reports/{report_id}/comments")
def add_comment(report_id: int, payload: CommentCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    new_comment = Comment(complaint_id=report_id, author_id=current_user.id, body=payload.body, visibility=payload.visibility)
    db.add(new_comment); db.commit()
    return {"status": "ok"}

@router.post("/reports/{report_id}/link")
def link_duplicate(report_id: int, payload: LinkCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_staff)):
    # Link report_id (source) to payload.parent_id (parent)
    link = DuplicateLink(source_complaint_id=report_id, parent_complaint_id=payload.parent_id)
    db.add(link)
    
    # Mark the source as closed/rejected if needed, or just add a status event
    complaint = db.query(Complaint).filter(Complaint.id == report_id).first()
    event = StatusEvent(complaint_id=report_id, from_status=complaint.status, to_status=complaint.status, actor_id=current_user.id, note=f"Linked as duplicate of {payload.parent_id}")
    db.add(event)
    db.commit()
    return {"status": "linked"}
EOF

echo "3. Adding Rainfall/Flood Endpoint..."
cat >> $API_DIR/app/api/analytics.py << 'EOF'

from ..models.models import FloodEvent

@router.get("/rainfall-context")
def get_rainfall_context(db: Session = Depends(get_db)):
    events = db.query(FloodEvent).limit(20).all()
    return [{"district": e.district, "date": e.date, "severity": e.severity, "lat": e.lat, "lon": e.lon} for e in events]
EOF

echo "4. Updating Frontend: Adding Comments & Link Duplicate to Ops..."
python3 - << 'PYEOF'
import os
file_path = os.path.expanduser("~/Desktop/civiclens-ai/apps/web/src/app/operations/report/[id]/page.tsx")
with open(file_path, "r") as f: code = f.read()

# Add state
code = code.replace('const [history, setHistory] = useState<any[]>([]);', 'const [history, setHistory] = useState<any[]>([]);\n  const [comments, setComments] = useState<any[]>([]);\n  const [newComment, setNewComment] = useState("");\n  const [parentId, setParentId] = useState("");')

# Fetch comments alongside history
code = code.replace(
    'fetch(`${API_URL}/ops/reports/${id}/history`, { headers: { "Authorization": `Bearer ${token}` } })\n      ]);',
    'fetch(`${API_URL}/ops/reports/${id}/history`, { headers: { "Authorization": `Bearer ${token}` } }),\n        fetch(`${API_URL}/ops/reports/${id}/comments`, { headers: { "Authorization": `Bearer ${token}` } })\n      ]);'
)
code = code.replace(
    'const histData = histRes.ok ? await histRes.json() : [];',
    'const histData = histRes.ok ? await histRes.json() : [];\n      const commData = await (await fetch(`${API_URL}/ops/reports/${id}/comments`, { headers: { "Authorization": `Bearer ${token}` } })).json();\n      setComments(Array.isArray(commData) ? commData : []);'
)

# Add comment and link handlers
handlers = '''
  const handleAddComment = async () => {
    if (!newComment) return;
    await fetch(`${API_URL}/ops/reports/${id}/comments`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "Authorization": `Bearer ${getToken()}` },
      body: JSON.stringify({ body: newComment, visibility: "public" })
    });
    setNewComment("");
    fetchData();
  };

  const handleLinkDuplicate = async () => {
    if (!parentId) return;
    await fetch(`${API_URL}/ops/reports/${id}/link`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "Authorization": `Bearer ${getToken()}` },
      body: JSON.stringify({ parent_id: parseInt(parentId) })
    });
    fetchData();
  };
'''
code = code.replace('  if (loading) return <div className="p-10 text-center text-slate-500">Loading report details...</div>;', handlers + '\n  if (loading) return <div className="p-10 text-center text-slate-500">Loading report details...</div>;')

# Add UI for comments and link duplicate at the bottom
extra_ui = '''
          <div className="bg-white p-8 rounded-xl border shadow-sm mt-6">
            <h3 className="font-bold text-lg mb-4">Link Duplicate</h3>
            <div className="flex gap-2">
              <input type="number" placeholder="Parent Report ID" className="border p-2 rounded w-full" value={parentId} onChange={e => setParentId(e.target.value)} />
              <Button onClick={handleLinkDuplicate}>Link as Duplicate</Button>
            </div>
          </div>

          <div className="bg-white p-8 rounded-xl border shadow-sm mt-6">
            <h3 className="font-bold text-lg mb-4">Comments</h3>
            <div className="space-y-4 mb-4">
              {comments.map(c => (
                <div key={c.id} className="p-3 bg-slate-50 rounded border">
                  <p className="text-sm font-bold text-slate-800">{c.author} <span className="text-xs text-slate-400 font-normal ml-2">{new Date(c.created_at).toLocaleString()}</span></p>
                  <p className="text-sm text-slate-600 mt-1">{c.body}</p>
                </div>
              ))}
            </div>
            <div className="flex gap-2">
              <input className="border p-2 rounded w-full" placeholder="Add a public comment..." value={newComment} onChange={e => setNewComment(e.target.value)} />
              <Button onClick={handleAddComment}>Post</Button>
            </div>
          </div>
'''
code = code.replace('        </div>\n      </div>\n    </div>\n  );\n}', extra_ui + '        </div>\n      </div>\n    </div>\n  );\n}')

with open(file_path, "w") as f: f.write(code)
PYEOF

echo "5. Updating Intelligence: Adding Rainfall Context Map..."
cat > $WEB_DIR/src/app/intelligence/rainfall/page.tsx << 'EOF'
"use client";
import { useQuery } from "@tanstack/react-query";
import { API_URL } from "@/lib/api";
import { MapContainer, TileLayer, Marker, Popup } from "react-leaflet";
import L from "leaflet";
import "leaflet/dist/leaflet.css";

const floodIcon = L.divIcon({
  className: 'custom-marker',
  html: `<div style="background-color: #3b82f6; width: 16px; height: 16px; border-radius: 50%; border: 2px solid white; box-shadow: 0 2px 4px rgba(0,0,0,0.3);"></div>`,
  iconSize: [16, 16], iconAnchor: [8, 8]
});

export default function RainfallContext() {
  const { data: floods } = useQuery({ queryKey: ["rainfall"], queryFn: () => fetch(`${API_URL}/analytics/rainfall-context`).then(r => r.json()) });

  return (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold text-slate-900">Rainfall & Flood Context</h2>
      <p className="text-slate-500">Historical flood events ingested from IIT Delhi dataset.</p>
      <div className="h-[500px] rounded-xl overflow-hidden border shadow-sm">
        <MapContainer center={[17.3850, 78.4867]} zoom={10} style={{ height: '100%', width: '100%', zIndex: 0 }}>
          <TileLayer url="https://tile.openstreetmap.org/{z}/{x}/{y}.png" />
          {floods?.map((f: any, i: number) => (
            <Marker key={i} position={[f.lat, f.lon]} icon={floodIcon}>
              <Popup>
                <div className="p-1">
                  <h4 className="font-bold text-sm m-0 text-blue-600">Flood Event</h4>
                  <p className="text-xs text-slate-500 m-0 mt-1">District: {f.district}</p>
                  <p className="text-xs text-slate-500 m-0">Date: {f.date}</p>
                  <p className="text-xs text-slate-500 m-0">Severity: {f.severity}</p>
                </div>
              </Popup>
            </Marker>
          ))}
        </MapContainer>
      </div>
    </div>
  );
}
EOF

# Add Rainfall to Sidebar
python3 - << 'PYEOF'
import os
file_path = os.path.expanduser("~/Desktop/civiclens-ai/apps/web/src/components/layout/app-shell.tsx")
with open(file_path, "r") as f: code = f.read()
code = code.replace('{ name: "Data Quality", href: "/intelligence/quality", icon: Brain },', '{ name: "Data Quality", href: "/intelligence/quality", icon: Brain },\n  { name: "Rainfall Context", href: "/intelligence/rainfall", icon: Brain },')
with open(file_path, "w") as f: f.write(code)
PYEOF

echo "6. Writing Playwright Test for Comments, Duplicate Linking, and Rainfall..."
cat > $WEB_DIR/tests/batch52.spec.ts << 'EOF'
import { test, expect } from '@playwright/test';

test.describe('Comments, Linking & Rainfall', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/login');
    await page.click('button:has-text("Operator")');
    await page.click('button[type="submit"]');
    await expect(page).toHaveURL(/.*operations/);
  });

  test('Operator can add comments and link duplicates', async ({ page }) => {
    await page.click('text=Complaint Queue');
    await page.locator('button:has-text("Manage")').first().click();
    await expect(page).toHaveURL(/.*operations\/report\/.*/);

    // Add Comment
    await page.fill('input[placeholder="Add a public comment..."]', 'Playwright test comment');
    await page.click('button:has-text("Post")');
    await expect(page.locator('text=Playwright test comment')).toBeVisible();

    // Link Duplicate
    await page.fill('input[placeholder="Parent Report ID"]', '1');
    await page.click('button:has-text("Link as Duplicate")');
    await expect(page.locator('text=Linked as duplicate of 1')).toBeVisible();
  });

  test('Intelligence page renders Rainfall context map', async ({ page }) => {
    await page.click('text=Rainfall Context');
    await expect(page.locator('text=Rainfall & Flood Context')).toBeVisible();
    await expect(page.locator('.leaflet-container')).toBeVisible();
  });
});
EOF

echo "7. Starting Servers & Running Tests..."
kill -9 $(lsof -ti:3000) 2>/dev/null || true
kill -9 $(lsof -ti:8000) 2>/dev/null || true

cd $API_DIR && source $ROOT/.venv/bin/activate && uvicorn app.main:app > /tmp/api.log 2>&1 &
cd $WEB_DIR && npm run dev -- --webpack > /tmp/web.log 2>&1 &

for i in {1..30}; do
    if curl -s http://localhost:3000 > /dev/null && curl -s http://localhost:8000/api/v1/health > /dev/null; then break; fi
    sleep 1
done

cd $WEB_DIR
npx playwright test tests/batch52.spec.ts || TEST_FAILED=true

echo "8. Shutting down servers..."
kill $BACKEND_PID 2>/dev/null || true
kill $FRONTEND_PID 2>/dev/null || true
pkill -f "next dev" 2>/dev/null || true
pkill -f "uvicorn app.main:app" 2>/dev/null || true

if [ "$TEST_FAILED" = true ]; then
    echo "❌ TEST FAILED."
    exit 1
else
    echo "✅ TEST PASSED SUCCESSFULLY. Comments, Linking & Rainfall work."
fi
