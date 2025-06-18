#!/bin/bash
# SSH Tunnel zum i7 Node für M1 Mac
# Verwendung vom M1 Mac: ssh -L 8105:localhost:8008 amonbaumgartner@192.168.68.105
# Dann: curl http://localhost:8105/status

echo "🚇 SSH Tunnel zu i7 Node"
echo "Port-Weiterleitung: localhost:8105 → i7:8008"
echo "Verwende: ssh -L 8105:localhost:8008 amonbaumgartner@192.168.68.105"
echo "Dann: curl http://localhost:8105/status"
