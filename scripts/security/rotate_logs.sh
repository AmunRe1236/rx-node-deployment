#!/bin/bash
# 📝 Security Log Rotation
find logs/ -name "security_*.log" -mtime +30 -delete 2>/dev/null || true
find logs/ -name "audit_*.log" -mtime +90 -delete 2>/dev/null || true
