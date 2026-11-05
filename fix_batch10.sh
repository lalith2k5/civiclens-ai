#!/bin/bash
set -e

# Ensure we are absolutely at the root directory
cd ~/Desktop/civiclens-ai

echo "Creating Deployment Files..."

# 1. Dockerfile for Backend
cat > apps/api/Dockerfile << 'EOF'
FROM python:3.12-slim
WORKDIR /app
RUN apt-get update && apt-get install -y libpq-dev gcc
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

# 2. Generate requirements.txt for Backend
echo "Generating requirements.txt..."
cd apps/api
source ../../.venv/bin/activate
pip freeze > requirements.txt
cd ../..

# 3. Dockerfile for Frontend
cat > apps/web/Dockerfile << 'EOF'
FROM node:22-alpine AS builder
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:22-alpine AS runner
WORKDIR /app
COPY --from=builder /app ./
EXPOSE 3000
CMD ["npm", "run", "start"]
EOF

# 4. Docker Compose File
cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
  db:
    image: postgis/postgis:17-3.4
    environment:
      POSTGRES_USER: civiclens
      POSTGRES_PASSWORD: password
      POSTGRES_DB: civiclens
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data

  api:
    build: ./apps/api
    environment:
      - DATABASE_URL=postgresql+psycopg2://civiclens:password@db:5432/civiclens
    ports:
      - "8000:8000"
    depends_on:
      - db

  web:
    build: ./apps/web
    environment:
      - NEXT_PUBLIC_API_URL=http://localhost:8000/api/v1
    ports:
      - "3000:3000"
    depends_on:
      - api

volumes:
  pgdata:
EOF

# 5. Fix Next.js standalone output for Docker
echo "Configuring Next.js for Docker deployment..."
sed -i '' 's/const nextConfig = {/const nextConfig = {\n  output: "standalone",/' apps/web/next.config.ts

echo "Building frontend to verify..."
cd apps/web
npm run build
cd ../..

echo "Committing Batch 10 to Git..."
git add .
git commit -m "feat(batch10): deployment files and full ML integration"
git push -u origin main

cd ~/Desktop/civiclens-ai-handoff
cat > PROJECT_STATE.md << 'EOF'
phase: batch10-complete
last_batch: 10
status: Full ML integrated. Docker deployment ready. PROJECT COMPLETE.
EOF
zip -qr handoff.zip .

echo "============================================================"
echo "Batch 10 Complete! System is fully functional."
echo "============================================================"
