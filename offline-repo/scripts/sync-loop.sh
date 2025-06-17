#!/bin/sh
# 🎩 Gentleman Offline Repository - Continuous Sync Script

echo "🔄 Starting Gentleman Git Sync Service..."
echo "📡 GitHub Repo: $GITHUB_REPO"
echo "📁 Local Repo: $LOCAL_REPO"
echo "⏰ Sync Interval: ${SYNC_INTERVAL}s"

# Create local repo directory
mkdir -p "$LOCAL_REPO"
cd "$LOCAL_REPO"

# Initial clone or update
if [ ! -d ".git" ]; then
    echo "🚀 Initial clone from GitHub..."
    git clone "$GITHUB_REPO" .
    if [ $? -eq 0 ]; then
        echo "✅ Initial clone successful"
    else
        echo "❌ Initial clone failed"
        exit 1
    fi
else
    echo "📂 Repository exists, updating..."
    git fetch origin
    git reset --hard origin/master
fi

# Continuous sync loop
while true; do
    echo "🔄 Syncing at $(date)"
    
    # Fetch latest changes
    git fetch origin
    
    # Check if there are new commits
    LOCAL_COMMIT=$(git rev-parse HEAD)
    REMOTE_COMMIT=$(git rev-parse origin/master)
    
    if [ "$LOCAL_COMMIT" != "$REMOTE_COMMIT" ]; then
        echo "📥 New changes detected, updating..."
        git reset --hard origin/master
        
        # Log the update
        echo "✅ Updated to commit: $(git log -1 --format='%h - %s (%an, %ar)')"
        
        # Trigger webhook to notify other services
        curl -X POST http://gitea:3000/api/v1/repos/gentleman/gentleman/hooks \
             -H "Content-Type: application/json" \
             -d '{"type":"gitea","active":true,"events":["push"],"config":{"url":"http://git-sync:8080/webhook","content_type":"json"}}' \
             2>/dev/null || true
    else
        echo "✅ Repository up to date"
    fi
    
    # Wait for next sync
    sleep "$SYNC_INTERVAL"
done 