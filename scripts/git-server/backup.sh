#!/bin/bash

# 🎩 GENTLEMAN Git Server Backup Script
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

# 📋 Configuration
BACKUP_DIR="/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="gitea_backup_${TIMESTAMP}"
RETENTION_DAYS=${BACKUP_RETENTION:-30}

# 🎨 Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 📝 Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# 🚀 Main backup function
perform_backup() {
    log "Starting Gitea backup process..."
    
    # Create backup directory
    mkdir -p "${BACKUP_DIR}/${BACKUP_NAME}"
    
    # 1. 🗄️ Database Backup
    log "Backing up PostgreSQL database..."
    if PGPASSWORD="${POSTGRES_PASSWORD}" pg_dump \
        -h gitea-db \
        -U "${POSTGRES_USER}" \
        -d "${POSTGRES_DB}" \
        --no-password \
        --verbose \
        --format=custom \
        --compress=9 \
        > "${BACKUP_DIR}/${BACKUP_NAME}/database.dump"; then
        success "Database backup completed"
    else
        error "Database backup failed"
        return 1
    fi
    
    # 2. 📁 Gitea Data Backup
    log "Backing up Gitea data directory..."
    if tar -czf "${BACKUP_DIR}/${BACKUP_NAME}/gitea-data.tar.gz" \
        -C /gitea-data . \
        --exclude='*.log' \
        --exclude='tmp/*' \
        --exclude='cache/*'; then
        success "Gitea data backup completed"
    else
        error "Gitea data backup failed"
        return 1
    fi
    
    # 3. 📊 Create backup metadata
    log "Creating backup metadata..."
    cat > "${BACKUP_DIR}/${BACKUP_NAME}/metadata.json" << EOF
{
    "backup_name": "${BACKUP_NAME}",
    "timestamp": "${TIMESTAMP}",
    "date": "$(date -Iseconds)",
    "gitea_version": "1.21",
    "database_type": "postgresql",
    "backup_type": "full",
    "retention_days": ${RETENTION_DAYS}
}
EOF
    
    # 4. 🗜️ Compress final backup
    log "Compressing backup archive..."
    if tar -czf "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" \
        -C "${BACKUP_DIR}" "${BACKUP_NAME}"; then
        success "Backup compression completed"
        rm -rf "${BACKUP_DIR}/${BACKUP_NAME}"
    else
        error "Backup compression failed"
        return 1
    fi
    
    # 5. 📏 Calculate backup size
    BACKUP_SIZE=$(du -h "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" | cut -f1)
    success "Backup completed: ${BACKUP_NAME}.tar.gz (${BACKUP_SIZE})"
}

# 🧹 Cleanup old backups
cleanup_old_backups() {
    log "Cleaning up backups older than ${RETENTION_DAYS} days..."
    
    find "${BACKUP_DIR}" -name "gitea_backup_*.tar.gz" -type f -mtime +${RETENTION_DAYS} -print0 | \
    while IFS= read -r -d '' file; do
        warning "Removing old backup: $(basename "$file")"
        rm -f "$file"
    done
    
    success "Cleanup completed"
}

# 🏥 Health check
health_check() {
    log "Performing health check..."
    
    # Check if Gitea is responding
    if curl -f -s "http://gitea:3000/api/healthz" > /dev/null; then
        success "Gitea is healthy"
    else
        warning "Gitea health check failed"
    fi
    
    # Check database connectivity
    if PGPASSWORD="${POSTGRES_PASSWORD}" pg_isready \
        -h gitea-db \
        -U "${POSTGRES_USER}" \
        -d "${POSTGRES_DB}" > /dev/null; then
        success "Database is healthy"
    else
        error "Database health check failed"
        return 1
    fi
}

# 📊 Backup statistics
show_statistics() {
    log "Backup Statistics:"
    echo "  📁 Backup Directory: ${BACKUP_DIR}"
    echo "  📊 Total Backups: $(find "${BACKUP_DIR}" -name "gitea_backup_*.tar.gz" | wc -l)"
    echo "  💾 Total Size: $(du -sh "${BACKUP_DIR}" 2>/dev/null | cut -f1 || echo "Unknown")"
    echo "  🕒 Retention: ${RETENTION_DAYS} days"
}

# 🚀 Main execution
main() {
    log "🎩 GENTLEMAN Git Server Backup Starting..."
    
    # Perform health check
    if ! health_check; then
        error "Health check failed, aborting backup"
        exit 1
    fi
    
    # Perform backup
    if perform_backup; then
        success "Backup process completed successfully"
    else
        error "Backup process failed"
        exit 1
    fi
    
    # Cleanup old backups
    cleanup_old_backups
    
    # Show statistics
    show_statistics
    
    success "🎩 GENTLEMAN Git Server Backup Completed!"
}

# Execute main function
main "$@" 