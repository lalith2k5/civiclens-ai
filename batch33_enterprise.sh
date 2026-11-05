#!/bin/bash
set -e

cd ~/Desktop/civiclens-ai/apps/api
source ../../.venv/bin/activate

echo "1. Expanding Admin API for full CRUD..."
cat > app/api/admin.py << 'EOF'
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from ..database import get_db
from ..models.models import User, Ward, Department, City, UserRole
from ..core.security import get_current_user
from pydantic import BaseModel

router = APIRouter()

class WardCreate(BaseModel):
    name: str
    code: str

class DeptCreate(BaseModel):
    name: str

class UserRoleUpdate(BaseModel):
    role: UserRole

@router.get("/users")
def get_users(db: Session = Depends(get_db)):
    users = db.query(User).all()
    return [{"id": u.id, "name": u.name, "email": u.email, "role": u.role} for u in users]

@router.put("/users/{user_id}/role")
def update_user_role(user_id: int, payload: UserRoleUpdate, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if not user: raise HTTPException(status_code=404, detail="User not found")
    user.role = payload.role
    db.commit()
    return {"message": "Role updated"}

@router.get("/wards")
def get_wards(db: Session = Depends(get_db)):
    return db.query(Ward).all()

@router.post("/wards")
def create_ward(ward: WardCreate, db: Session = Depends(get_db)):
    new_ward = Ward(city_id=1, name=ward.name, code=ward.code)
    db.add(new_ward); db.commit(); db.refresh(new_ward)
    return new_ward

@router.delete("/wards/{ward_id}")
def delete_ward(ward_id: int, db: Session = Depends(get_db)):
    ward = db.query(Ward).filter(Ward.id == ward_id).first()
    if not ward: raise HTTPException(status_code=404, detail="Ward not found")
    db.delete(ward); db.commit()
    return {"message": "Ward deleted"}

@router.get("/departments")
def get_depts(db: Session = Depends(get_db)):
    return db.query(Department).all()

@router.post("/departments")
def create_dept(dept: DeptCreate, db: Session = Depends(get_db)):
    new_dept = Department(city_id=1, name=dept.name)
    db.add(new_dept); db.commit(); db.refresh(new_dept)
    return new_dept
EOF

cd ../..
cd apps/web

echo "2. Installing Map Clustering..."
npm install react-leaflet-cluster

echo "3. Updating Map for Clustering..."
cat > src/app/operations/map/MapClient.tsx << 'EOF'
"use client";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { API_URL, getToken, logout } from "@/lib/api";
import { MapContainer, TileLayer, Marker, Popup } from 'react-leaflet';
import MarkerClusterGroup from 'react-leaflet-cluster';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';

const getMarkerIcon = (priority: string, status: string) => {
  const color = priority === 'Critical' ? '#dc2626' : priority === 'High' ? '#d97706' : status === 'RESOLVED' ? '#16a34a' : '#176b62';
  return L.divIcon({
    className: 'custom-marker',
    html: `<div style="background-color: ${color}; width: 16px; height: 16px; border-radius: 50%; border: 2px solid white; box-shadow: 0 2px 4px rgba(0,0,0,0.3);"></div>`,
    iconSize: [16, 16],
    iconAnchor: [8, 8]
  });
};

export default function MapView() {
  const router = useRouter();
  const [reports, setReports] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    const token = getToken();
    if (!token) { router.push("/login"); return; }

    fetch(`${API_URL}/ops/reports`, { headers: { Authorization: `Bearer ${token}` }})
      .then(res => {
        if (res.status === 401) { logout(); throw new Error("Unauthorized"); }
        if (!res.ok) throw new Error("Failed to fetch");
        return res.json();
      })
      .then(data => { setReports(data); setLoading(false); })
      .catch(err => { setError("Could not load map data."); setLoading(false); });
  }, [router]);

  if (loading) return <div className="h-[calc(100vh-8rem)] flex items-center justify-center bg-slate-50 rounded-xl border">Loading geospatial data...</div>;
  if (error) return <div className="h-[calc(100vh-8rem)] flex items-center justify-center bg-red-50 text-red-600 rounded-xl border">{error}</div>;

  return (
    <div className="h-[calc(100vh-8rem)] relative rounded-xl overflow-hidden border shadow-sm z-0">
      <div className="absolute top-4 right-4 z-[1000] bg-white p-3 rounded-lg shadow-md flex gap-4 text-xs font-medium border">
        <div className="flex items-center gap-1.5"><span className="w-3 h-3 rounded-full bg-red-600"></span> Critical</div>
        <div className="flex items-center gap-1.5"><span className="w-3 h-3 rounded-full bg-amber-600"></span> High</div>
        <div className="flex items-center gap-1.5"><span className="w-3 h-3 rounded-full bg-[#176b62]"></span> Open</div>
        <div className="flex items-center gap-1.5"><span className="w-3 h-3 rounded-full bg-green-600"></span> Resolved</div>
      </div>

      <MapContainer center={[17.3850, 78.4867]} zoom={11} style={{ height: '100%', width: '100%', zIndex: 0 }}>
        <TileLayer url="https://tile.openstreetmap.org/{z}/{x}/{y}.png" />
        
        {/* CLUSTERING ADDED HERE */}
        <MarkerClusterGroup chunkedLoading>
          {reports.map((report) => (
            <Marker key={report.id} position={[report.lat, report.lon]} icon={getMarkerIcon(report.priority, report.status)}>
              <Popup>
                <div className="p-1 min-w-[200px]">
                  <h4 className="font-bold text-sm m-0 text-slate-900">{report.category.replace('_', ' ').toUpperCase()}</h4>
                  <p className="text-xs text-slate-500 m-0 mt-1 font-mono">{report.public_ref}</p>
                  <p className="text-xs text-slate-600 mt-2">{report.description}</p>
                  <a href={`/operations/report/${report.id}`} className="text-xs text-blue-600 font-medium hover:underline mt-2 block">Manage &rarr;</a>
                </div>
              </Popup>
            </Marker>
          ))}
        </MarkerClusterGroup>
      </MapContainer>
    </div>
  );
}
EOF

echo "4. Building Full Admin UI..."
cat > src/app/admin/AdminClient.tsx << 'EOF'
"use client";
import { useState, useEffect } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { API_URL, getToken } from "@/lib/api";

export default function Admin() {
  const [activeTab, setActiveTab] = useState("wards");
  const queryClient = useQueryClient();

  // Queries
  const { data: wards } = useQuery({ queryKey: ["wards"], queryFn: () => fetch(`${API_URL}/admin/wards`).then(r => r.json()) });
  const { data: depts } = useQuery({ queryKey: ["depts"], queryFn: () => fetch(`${API_URL}/admin/departments`).then(r => r.json()) });
  const { data: users } = useQuery({ queryKey: ["users"], queryFn: () => fetch(`${API_URL}/admin/users`).then(r => r.json()) });

  // Mutations
  const addWard = useMutation({
    mutationFn: (name: string) => fetch(`${API_URL}/admin/wards`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ name, code: "NEW" }) }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["wards"] })
  });

  const addDept = useMutation({
    mutationFn: (name: string) => fetch(`${API_URL}/admin/departments`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ name }) }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["depts"] })
  });

  const updateRole = useMutation({
    mutationFn: ({ id, role }: { id: number, role: string }) => fetch(`${API_URL}/admin/users/${id}/role`, { method: "PUT", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ role }) }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["users"] })
  });

  return (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold text-slate-900">Admin Configuration</h2>
      
      <div className="flex gap-2 border-b">
        {["wards", "departments", "users"].map(tab => (
          <button key={tab} onClick={() => setActiveTab(tab)} className={`px-4 py-2 font-medium capitalize border-b-2 ${activeTab === tab ? 'border-primary text-primary' : 'border-transparent text-slate-500'}`}>{tab}</button>
        ))}
      </div>

      {activeTab === "wards" && (
        <div className="bg-white p-6 rounded-xl border shadow-sm">
          <div className="flex gap-2 mb-4">
            <input id="wardName" className="border p-2 rounded w-full" placeholder="New Ward Name" />
            <Button onClick={() => { const el = document.getElementById('wardName') as HTMLInputElement; if(el.value) { addWard.mutate(el.value); el.value = ''; } }}>Add</Button>
          </div>
          <ul className="space-y-2">
            {wards?.map((w: any) => <li key={w.id} className="p-3 bg-slate-50 rounded border flex justify-between">{w.name} <Badge>{w.code}</Badge></li>)}
          </ul>
        </div>
      )}

      {activeTab === "departments" && (
        <div className="bg-white p-6 rounded-xl border shadow-sm">
          <div className="flex gap-2 mb-4">
            <input id="deptName" className="border p-2 rounded w-full" placeholder="New Department Name" />
            <Button onClick={() => { const el = document.getElementById('deptName') as HTMLInputElement; if(el.value) { addDept.mutate(el.value); el.value = ''; } }}>Add</Button>
          </div>
          <ul className="space-y-2">
            {depts?.map((d: any) => <li key={d.id} className="p-3 bg-slate-50 rounded border">{d.name}</li>)}
          </ul>
        </div>
      )}

      {activeTab === "users" && (
        <div className="bg-white rounded-xl border shadow-sm overflow-hidden">
          <table className="w-full text-sm text-left">
            <thead className="bg-slate-50 border-b">
              <tr><th className="px-6 py-4">Name</th><th className="px-6 py-4">Email</th><th className="px-6 py-4">Role</th></tr>
            </thead>
            <tbody>
              {users?.map((u: any) => (
                <tr key={u.id} className="border-b">
                  <td className="px-6 py-4 font-medium">{u.name}</td>
                  <td className="px-6 py-4 text-slate-500">{u.email}</td>
                  <td className="px-6 py-4">
                    <select value={u.role} onChange={(e) => updateRole.mutate({ id: u.id, role: e.target.value })} className="border p-1 rounded bg-white">
                      <option value="citizen">Citizen</option>
                      <option value="field_worker">Field Worker</option>
                      <option value="operator">Operator</option>
                      <option value="admin">Admin</option>
                    </select>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
EOF

echo "5. Building to verify..."
npm run build

cd ~/Desktop/civiclens-ai
git add .
git commit -m "feat(enterprise): map clustering and full admin CRUD tabs"
git push -u origin main
cd ~/Desktop/civiclens-ai-handoff && zip -qr handoff.zip .

echo "============================================================"
echo "Batch 33 Complete. Clustering & Admin CRUD added."
echo "============================================================"
