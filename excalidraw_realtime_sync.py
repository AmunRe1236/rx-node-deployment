#!/usr/bin/env python3
"""
🎨 EXCALIDRAW REAL-TIME SYNC SERVER
==================================
High-Performance WebSocket Server für Excalidraw Synchronisation
Unterstützt 1Hz (pro Sekunde) Updates zwischen allen Nodes
"""

import asyncio
import websockets
import json
import time
import logging
import sqlite3
import hashlib
from datetime import datetime
from pathlib import Path
from typing import Dict, Set, Any
import threading

# Logging Setup
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

class ExcalidrawSyncServer:
    def __init__(self, host="0.0.0.0", port=3001):
        self.host = host
        self.port = port
        self.clients: Set[websockets.WebSocketServerProtocol] = set()
        self.rooms: Dict[str, Set[websockets.WebSocketServerProtocol]] = {}
        self.drawings: Dict[str, Dict] = {}
        self.last_sync = {}
        
        # Datenbank für Persistierung
        self.db_path = "excalidraw_sync.db"
        self.init_database()
        
        # Sync-Konfiguration
        self.sync_interval = 1.0  # 1 Sekunde
        self.max_clients_per_room = 50
        
        logging.info(f"🎨 Excalidraw Sync Server initialisiert")
        logging.info(f"   Host: {self.host}:{self.port}")
        logging.info(f"   Sync-Interval: {self.sync_interval}s")
    
    def init_database(self):
        """Initialisiere SQLite Datenbank"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS drawings (
                room_id TEXT PRIMARY KEY,
                data TEXT NOT NULL,
                last_modified TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                checksum TEXT NOT NULL
            )
        ''')
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS sync_events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                room_id TEXT NOT NULL,
                event_type TEXT NOT NULL,
                timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                client_count INTEGER DEFAULT 0
            )
        ''')
        
        conn.commit()
        conn.close()
        logging.info("✅ Datenbank initialisiert")
    
    async def register_client(self, websocket, room_id="default"):
        """Registriere neuen Client"""
        self.clients.add(websocket)
        
        if room_id not in self.rooms:
            self.rooms[room_id] = set()
        
        if len(self.rooms[room_id]) >= self.max_clients_per_room:
            await websocket.send(json.dumps({
                "type": "error",
                "message": f"Room {room_id} ist voll (max {self.max_clients_per_room} Clients)"
            }))
            return False
        
        self.rooms[room_id].add(websocket)
        
        # Sende aktuelle Zeichnung an neuen Client
        if room_id in self.drawings:
            await websocket.send(json.dumps({
                "type": "full_sync",
                "room_id": room_id,
                "data": self.drawings[room_id],
                "timestamp": time.time()
            }))
        
        # Event loggen
        self.log_sync_event(room_id, "client_join", len(self.rooms[room_id]))
        
        logging.info(f"✅ Client zu Room '{room_id}' hinzugefügt ({len(self.rooms[room_id])} Clients)")
        return True
    
    async def unregister_client(self, websocket):
        """Entferne Client"""
        self.clients.discard(websocket)
        
        for room_id, room_clients in self.rooms.items():
            if websocket in room_clients:
                room_clients.remove(websocket)
                self.log_sync_event(room_id, "client_leave", len(room_clients))
                logging.info(f"❌ Client aus Room '{room_id}' entfernt ({len(room_clients)} Clients)")
                break
    
    async def handle_message(self, websocket, message):
        """Verarbeite eingehende Nachrichten"""
        try:
            data = json.loads(message)
            msg_type = data.get("type")
            room_id = data.get("room_id", "default")
            
            if msg_type == "join_room":
                success = await self.register_client(websocket, room_id)
                if success:
                    await self.broadcast_to_room(room_id, {
                        "type": "user_joined",
                        "room_id": room_id,
                        "client_count": len(self.rooms[room_id])
                    }, exclude=websocket)
            
            elif msg_type == "drawing_update":
                await self.handle_drawing_update(room_id, data)
            
            elif msg_type == "cursor_update":
                await self.handle_cursor_update(room_id, data, websocket)
            
            elif msg_type == "ping":
                await websocket.send(json.dumps({
                    "type": "pong",
                    "timestamp": time.time()
                }))
            
        except json.JSONDecodeError:
            await websocket.send(json.dumps({
                "type": "error",
                "message": "Ungültiges JSON Format"
            }))
        except Exception as e:
            logging.error(f"Fehler bei Nachrichtenverarbeitung: {e}")
    
    async def handle_drawing_update(self, room_id, data):
        """Verarbeite Zeichnungs-Updates"""
        drawing_data = data.get("data", {})
        
        # Prüfe ob Update notwendig ist
        current_checksum = self.calculate_checksum(drawing_data)
        if room_id in self.last_sync and self.last_sync[room_id] == current_checksum:
            return  # Keine Änderung
        
        # Update Zeichnung
        self.drawings[room_id] = drawing_data
        self.last_sync[room_id] = current_checksum
        
        # Speichere in Datenbank
        await self.save_drawing_to_db(room_id, drawing_data, current_checksum)
        
        # Broadcast an alle Clients im Room
        await self.broadcast_to_room(room_id, {
            "type": "drawing_sync",
            "room_id": room_id,
            "data": drawing_data,
            "timestamp": time.time(),
            "checksum": current_checksum
        })
        
        self.log_sync_event(room_id, "drawing_update", len(self.rooms.get(room_id, [])))
    
    async def handle_cursor_update(self, room_id, data, sender):
        """Verarbeite Cursor-Updates (sehr häufig)"""
        cursor_data = {
            "type": "cursor_update",
            "room_id": room_id,
            "cursor": data.get("cursor", {}),
            "user_id": data.get("user_id", "anonymous"),
            "timestamp": time.time()
        }
        
        # Broadcast nur an andere Clients (nicht an Sender)
        await self.broadcast_to_room(room_id, cursor_data, exclude=sender)
    
    async def broadcast_to_room(self, room_id, message, exclude=None):
        """Sende Nachricht an alle Clients in einem Room"""
        if room_id not in self.rooms:
            return
        
        message_str = json.dumps(message)
        disconnected_clients = set()
        
        for client in self.rooms[room_id]:
            if client == exclude:
                continue
            
            try:
                await client.send(message_str)
            except websockets.exceptions.ConnectionClosed:
                disconnected_clients.add(client)
            except Exception as e:
                logging.error(f"Fehler beim Senden an Client: {e}")
                disconnected_clients.add(client)
        
        # Entferne getrennte Clients
        for client in disconnected_clients:
            self.rooms[room_id].discard(client)
            self.clients.discard(client)
    
    def calculate_checksum(self, data):
        """Berechne Checksum für Daten"""
        data_str = json.dumps(data, sort_keys=True)
        return hashlib.md5(data_str.encode()).hexdigest()
    
    async def save_drawing_to_db(self, room_id, data, checksum):
        """Speichere Zeichnung in Datenbank"""
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            cursor.execute('''
                INSERT OR REPLACE INTO drawings (room_id, data, checksum)
                VALUES (?, ?, ?)
            ''', (room_id, json.dumps(data), checksum))
            
            conn.commit()
            conn.close()
        except Exception as e:
            logging.error(f"Datenbankfehler: {e}")
    
    def log_sync_event(self, room_id, event_type, client_count):
        """Logge Sync-Event"""
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            cursor.execute('''
                INSERT INTO sync_events (room_id, event_type, client_count)
                VALUES (?, ?, ?)
            ''', (room_id, event_type, client_count))
            
            conn.commit()
            conn.close()
        except Exception as e:
            logging.error(f"Event-Log Fehler: {e}")
    
    async def periodic_sync(self):
        """Periodische Synchronisation (1Hz)"""
        while True:
            try:
                await asyncio.sleep(self.sync_interval)
                
                # Heartbeat an alle Clients
                heartbeat_msg = {
                    "type": "heartbeat",
                    "timestamp": time.time(),
                    "server_status": "active",
                    "total_clients": len(self.clients),
                    "active_rooms": len(self.rooms)
                }
                
                for client in list(self.clients):
                    try:
                        await client.send(json.dumps(heartbeat_msg))
                    except:
                        self.clients.discard(client)
                
            except Exception as e:
                logging.error(f"Periodic Sync Fehler: {e}")
    
    async def handle_client(self, websocket, path):
        """Handle WebSocket Client Verbindung"""
        client_ip = websocket.remote_address[0]
        logging.info(f"🔗 Neue Verbindung von {client_ip}")
        
        try:
            await websocket.send(json.dumps({
                "type": "welcome",
                "message": "Excalidraw Sync Server bereit",
                "server_time": time.time()
            }))
            
            async for message in websocket:
                await self.handle_message(websocket, message)
                
        except websockets.exceptions.ConnectionClosed:
            logging.info(f"🔌 Verbindung zu {client_ip} getrennt")
        except Exception as e:
            logging.error(f"Client Handler Fehler: {e}")
        finally:
            await self.unregister_client(websocket)
    
    def get_stats(self):
        """Hole Server-Statistiken"""
        return {
            "total_clients": len(self.clients),
            "active_rooms": len(self.rooms),
            "rooms_detail": {room: len(clients) for room, clients in self.rooms.items()},
            "total_drawings": len(self.drawings),
            "sync_interval": self.sync_interval,
            "uptime": time.time()
        }
    
    async def start_server(self):
        """Starte WebSocket Server"""
        logging.info(f"🚀 Starte Excalidraw Sync Server auf {self.host}:{self.port}")
        
        # Starte periodische Synchronisation
        asyncio.create_task(self.periodic_sync())
        
        # Starte WebSocket Server
        async with websockets.serve(self.handle_client, self.host, self.port):
            logging.info(f"✅ Server läuft auf ws://{self.host}:{self.port}")
            logging.info(f"📊 Web Interface: http://{self.host}:{self.port}")
            await asyncio.Future()  # Run forever

async def main():
    """Hauptfunktion"""
    sync_server = ExcalidrawSyncServer()
    await sync_server.start_server()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logging.info("🛑 Server gestoppt") 
"""
🎨 EXCALIDRAW REAL-TIME SYNC SERVER
==================================
High-Performance WebSocket Server für Excalidraw Synchronisation
Unterstützt 1Hz (pro Sekunde) Updates zwischen allen Nodes
"""

import asyncio
import websockets
import json
import time
import logging
import sqlite3
import hashlib
from datetime import datetime
from pathlib import Path
from typing import Dict, Set, Any
import threading

# Logging Setup
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

class ExcalidrawSyncServer:
    def __init__(self, host="0.0.0.0", port=3001):
        self.host = host
        self.port = port
        self.clients: Set[websockets.WebSocketServerProtocol] = set()
        self.rooms: Dict[str, Set[websockets.WebSocketServerProtocol]] = {}
        self.drawings: Dict[str, Dict] = {}
        self.last_sync = {}
        
        # Datenbank für Persistierung
        self.db_path = "excalidraw_sync.db"
        self.init_database()
        
        # Sync-Konfiguration
        self.sync_interval = 1.0  # 1 Sekunde
        self.max_clients_per_room = 50
        
        logging.info(f"🎨 Excalidraw Sync Server initialisiert")
        logging.info(f"   Host: {self.host}:{self.port}")
        logging.info(f"   Sync-Interval: {self.sync_interval}s")
    
    def init_database(self):
        """Initialisiere SQLite Datenbank"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS drawings (
                room_id TEXT PRIMARY KEY,
                data TEXT NOT NULL,
                last_modified TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                checksum TEXT NOT NULL
            )
        ''')
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS sync_events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                room_id TEXT NOT NULL,
                event_type TEXT NOT NULL,
                timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                client_count INTEGER DEFAULT 0
            )
        ''')
        
        conn.commit()
        conn.close()
        logging.info("✅ Datenbank initialisiert")
    
    async def register_client(self, websocket, room_id="default"):
        """Registriere neuen Client"""
        self.clients.add(websocket)
        
        if room_id not in self.rooms:
            self.rooms[room_id] = set()
        
        if len(self.rooms[room_id]) >= self.max_clients_per_room:
            await websocket.send(json.dumps({
                "type": "error",
                "message": f"Room {room_id} ist voll (max {self.max_clients_per_room} Clients)"
            }))
            return False
        
        self.rooms[room_id].add(websocket)
        
        # Sende aktuelle Zeichnung an neuen Client
        if room_id in self.drawings:
            await websocket.send(json.dumps({
                "type": "full_sync",
                "room_id": room_id,
                "data": self.drawings[room_id],
                "timestamp": time.time()
            }))
        
        # Event loggen
        self.log_sync_event(room_id, "client_join", len(self.rooms[room_id]))
        
        logging.info(f"✅ Client zu Room '{room_id}' hinzugefügt ({len(self.rooms[room_id])} Clients)")
        return True
    
    async def unregister_client(self, websocket):
        """Entferne Client"""
        self.clients.discard(websocket)
        
        for room_id, room_clients in self.rooms.items():
            if websocket in room_clients:
                room_clients.remove(websocket)
                self.log_sync_event(room_id, "client_leave", len(room_clients))
                logging.info(f"❌ Client aus Room '{room_id}' entfernt ({len(room_clients)} Clients)")
                break
    
    async def handle_message(self, websocket, message):
        """Verarbeite eingehende Nachrichten"""
        try:
            data = json.loads(message)
            msg_type = data.get("type")
            room_id = data.get("room_id", "default")
            
            if msg_type == "join_room":
                success = await self.register_client(websocket, room_id)
                if success:
                    await self.broadcast_to_room(room_id, {
                        "type": "user_joined",
                        "room_id": room_id,
                        "client_count": len(self.rooms[room_id])
                    }, exclude=websocket)
            
            elif msg_type == "drawing_update":
                await self.handle_drawing_update(room_id, data)
            
            elif msg_type == "cursor_update":
                await self.handle_cursor_update(room_id, data, websocket)
            
            elif msg_type == "ping":
                await websocket.send(json.dumps({
                    "type": "pong",
                    "timestamp": time.time()
                }))
            
        except json.JSONDecodeError:
            await websocket.send(json.dumps({
                "type": "error",
                "message": "Ungültiges JSON Format"
            }))
        except Exception as e:
            logging.error(f"Fehler bei Nachrichtenverarbeitung: {e}")
    
    async def handle_drawing_update(self, room_id, data):
        """Verarbeite Zeichnungs-Updates"""
        drawing_data = data.get("data", {})
        
        # Prüfe ob Update notwendig ist
        current_checksum = self.calculate_checksum(drawing_data)
        if room_id in self.last_sync and self.last_sync[room_id] == current_checksum:
            return  # Keine Änderung
        
        # Update Zeichnung
        self.drawings[room_id] = drawing_data
        self.last_sync[room_id] = current_checksum
        
        # Speichere in Datenbank
        await self.save_drawing_to_db(room_id, drawing_data, current_checksum)
        
        # Broadcast an alle Clients im Room
        await self.broadcast_to_room(room_id, {
            "type": "drawing_sync",
            "room_id": room_id,
            "data": drawing_data,
            "timestamp": time.time(),
            "checksum": current_checksum
        })
        
        self.log_sync_event(room_id, "drawing_update", len(self.rooms.get(room_id, [])))
    
    async def handle_cursor_update(self, room_id, data, sender):
        """Verarbeite Cursor-Updates (sehr häufig)"""
        cursor_data = {
            "type": "cursor_update",
            "room_id": room_id,
            "cursor": data.get("cursor", {}),
            "user_id": data.get("user_id", "anonymous"),
            "timestamp": time.time()
        }
        
        # Broadcast nur an andere Clients (nicht an Sender)
        await self.broadcast_to_room(room_id, cursor_data, exclude=sender)
    
    async def broadcast_to_room(self, room_id, message, exclude=None):
        """Sende Nachricht an alle Clients in einem Room"""
        if room_id not in self.rooms:
            return
        
        message_str = json.dumps(message)
        disconnected_clients = set()
        
        for client in self.rooms[room_id]:
            if client == exclude:
                continue
            
            try:
                await client.send(message_str)
            except websockets.exceptions.ConnectionClosed:
                disconnected_clients.add(client)
            except Exception as e:
                logging.error(f"Fehler beim Senden an Client: {e}")
                disconnected_clients.add(client)
        
        # Entferne getrennte Clients
        for client in disconnected_clients:
            self.rooms[room_id].discard(client)
            self.clients.discard(client)
    
    def calculate_checksum(self, data):
        """Berechne Checksum für Daten"""
        data_str = json.dumps(data, sort_keys=True)
        return hashlib.md5(data_str.encode()).hexdigest()
    
    async def save_drawing_to_db(self, room_id, data, checksum):
        """Speichere Zeichnung in Datenbank"""
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            cursor.execute('''
                INSERT OR REPLACE INTO drawings (room_id, data, checksum)
                VALUES (?, ?, ?)
            ''', (room_id, json.dumps(data), checksum))
            
            conn.commit()
            conn.close()
        except Exception as e:
            logging.error(f"Datenbankfehler: {e}")
    
    def log_sync_event(self, room_id, event_type, client_count):
        """Logge Sync-Event"""
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            cursor.execute('''
                INSERT INTO sync_events (room_id, event_type, client_count)
                VALUES (?, ?, ?)
            ''', (room_id, event_type, client_count))
            
            conn.commit()
            conn.close()
        except Exception as e:
            logging.error(f"Event-Log Fehler: {e}")
    
    async def periodic_sync(self):
        """Periodische Synchronisation (1Hz)"""
        while True:
            try:
                await asyncio.sleep(self.sync_interval)
                
                # Heartbeat an alle Clients
                heartbeat_msg = {
                    "type": "heartbeat",
                    "timestamp": time.time(),
                    "server_status": "active",
                    "total_clients": len(self.clients),
                    "active_rooms": len(self.rooms)
                }
                
                for client in list(self.clients):
                    try:
                        await client.send(json.dumps(heartbeat_msg))
                    except:
                        self.clients.discard(client)
                
            except Exception as e:
                logging.error(f"Periodic Sync Fehler: {e}")
    
    async def handle_client(self, websocket, path):
        """Handle WebSocket Client Verbindung"""
        client_ip = websocket.remote_address[0]
        logging.info(f"🔗 Neue Verbindung von {client_ip}")
        
        try:
            await websocket.send(json.dumps({
                "type": "welcome",
                "message": "Excalidraw Sync Server bereit",
                "server_time": time.time()
            }))
            
            async for message in websocket:
                await self.handle_message(websocket, message)
                
        except websockets.exceptions.ConnectionClosed:
            logging.info(f"🔌 Verbindung zu {client_ip} getrennt")
        except Exception as e:
            logging.error(f"Client Handler Fehler: {e}")
        finally:
            await self.unregister_client(websocket)
    
    def get_stats(self):
        """Hole Server-Statistiken"""
        return {
            "total_clients": len(self.clients),
            "active_rooms": len(self.rooms),
            "rooms_detail": {room: len(clients) for room, clients in self.rooms.items()},
            "total_drawings": len(self.drawings),
            "sync_interval": self.sync_interval,
            "uptime": time.time()
        }
    
    async def start_server(self):
        """Starte WebSocket Server"""
        logging.info(f"🚀 Starte Excalidraw Sync Server auf {self.host}:{self.port}")
        
        # Starte periodische Synchronisation
        asyncio.create_task(self.periodic_sync())
        
        # Starte WebSocket Server
        async with websockets.serve(self.handle_client, self.host, self.port):
            logging.info(f"✅ Server läuft auf ws://{self.host}:{self.port}")
            logging.info(f"📊 Web Interface: http://{self.host}:{self.port}")
            await asyncio.Future()  # Run forever

async def main():
    """Hauptfunktion"""
    sync_server = ExcalidrawSyncServer()
    await sync_server.start_server()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logging.info("🛑 Server gestoppt") 
 