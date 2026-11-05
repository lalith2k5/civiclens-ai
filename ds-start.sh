#!/bin/bash
kill -9 $(lsof -ti:8000) 2>/dev/null
kill -9 $(lsof -ti:3000) 2>/dev/null
osascript -e "tell application \"Terminal\" to do script \"cd ~/Desktop/civiclens-ai && source .venv/bin/activate && cd apps/api && uvicorn app.main:app --reload\""
osascript -e "tell application \"Terminal\" to do script \"cd ~/Desktop/civiclens-ai/apps/web && npm run dev\""
echo "Started!"
