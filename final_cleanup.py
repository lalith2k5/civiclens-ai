import os
import subprocess

print("1. Removing Python cache and debug scripts...")
# Remove Python cache
subprocess.run(["git", "rm", "-r", "--cached", "apps/api/app/__pycache__", "apps/api/tests/__pycache__"], stderr=subprocess.DEVNULL)
subprocess.run(["rm", "-rf", "apps/api/app/__pycache__", "apps/api/tests/__pycache__", "apps/api/__pycache__"])

# Remove temporary debug and ingestion scripts
files_to_remove = [
    "apps/api/fix_flood_data.py",
    "apps/api/fix_flood_real.py",
    "apps/api/geocode_flood.py",
    "apps/web/debug-map-errors.mjs",
    "apps/web/debug-map.mjs",
    "apps/web/debug-map.ts",
    "apps/web/debug-prod-map.mjs"
]
for f in files_to_remove:
    if os.path.exists(f):
        subprocess.run(["git", "rm", "--cached", f], stderr=subprocess.DEVNULL)
        os.remove(f)

print("2. Updating .gitignore...")
gitignore_content = """# Environment
.env
.env.local
.env.production

# Python
__pycache__/
*.py[cod]
.venv/
venv/
.pytest_cache/

# Node
node_modules/
.next/
out/
build/
dist/

# Testing
test-results/
playwright-report/
coverage/

# Data (Only keep manifests)
data/raw/
data/processed/

# OS
.DS_Store
"""
with open(".gitignore", "w") as f:
    f.write(gitignore_content)

print("3. Committing and pushing the final clean repository...")
subprocess.run(["git", "add", "-A"])
subprocess.run(["git", "commit", "-m", "chore: remove cache files and debug scripts for final handover"])
subprocess.run(["git", "push", "origin", "main"])

print("REPOSITORY IS NOW 100% CLEAN AND READY FOR HANDOVER.")
