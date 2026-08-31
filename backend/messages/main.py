"""
PawStay Message Service — FastAPI + Socket.IO microservice.

Run with:
    python main.py

Runs on port 8001 (independent from main PawStay API on port 8000).
Supports real-time Socket.IO chat and persists all conversations & messages in chats.json.
"""

import os
import sys
import json
from datetime import datetime
from typing import Optional

# Allow imports from this directory when running directly
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import sqlite3
import uvicorn
import socketio
from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from sqlalchemy.orm import Session

from database.db import get_db, engine
from database.models import Base, Conversation, Message

DB_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "pawstay.db")

def get_user_aliases(identifier: str) -> set:
    if not identifier:
        return set()
    aliases = {identifier, identifier.lower()}
    if not os.path.exists(DB_PATH):
        return aliases
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute(
            "SELECT username, email, id FROM users WHERE username = ? OR email = ? OR id = ?",
            (identifier, identifier, int(identifier) if identifier.isdigit() else -1)
        )
        row = cursor.fetchone()
        if row:
            username, email, uid = row
            if username:
                aliases.add(username)
                aliases.add(username.lower())
            if email:
                aliases.add(email)
                aliases.add(email.lower())
            if uid is not None:
                aliases.add(str(uid))
        conn.close()
    except Exception as e:
        print(f"[WARN] Failed to query user aliases: {e}")
    return aliases



# ---------------------------------------------------------------------------
# Create SQLite tables on startup
# ---------------------------------------------------------------------------
Base.metadata.create_all(bind=engine)

# ---------------------------------------------------------------------------
# JSON Storage Helper
# ---------------------------------------------------------------------------
CHATS_FILE = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "chats.json")

def load_chats_data() -> dict:
    if not os.path.exists(CHATS_FILE):
        return {"conversations": [], "messages": []}
    try:
        with open(CHATS_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        print(f"[WARN] Failed to load chats.json: {e}")
        return {"conversations": [], "messages": []}

def save_chats_data(data: dict) -> None:
    try:
        with open(CHATS_FILE, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
    except Exception as e:
        print(f"[ERROR] Failed to save chats.json: {e}")

# ---------------------------------------------------------------------------
# Socket.IO Async Server Setup
# ---------------------------------------------------------------------------
sio = socketio.AsyncServer(async_mode="asgi", cors_allowed_origins="*")
fastapi_app = FastAPI(
    title="PawStay Message Service",
    description="Chat and messaging microservice with Socket.IO & JSON persistence",
    version="1.0.0",
)

fastapi_app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Combine Socket.IO and FastAPI into single ASGI App
app = socketio.ASGIApp(sio, other_asgi_app=fastapi_app)

# ---------------------------------------------------------------------------
# Socket.IO Events
# ---------------------------------------------------------------------------
@sio.event
async def connect(sid, environ):
    print(f"[SOCKET] Client connected: {sid}")

@sio.event
async def disconnect(sid):
    print(f"[SOCKET] Client disconnected: {sid}")

@sio.event
async def join_room(sid, data):
    conversation_id = data.get("conversation_id")
    if conversation_id:
        room = f"conversation_{conversation_id}"
        await sio.enter_room(sid, room)
        print(f"[SOCKET] Client {sid} joined room: {room}")

@sio.event
async def send_message(sid, data):
    conversation_id = data.get("conversation_id")
    sender_id = data.get("sender_id")
    content = data.get("content", "")
    image_url = data.get("image_url")

    if not conversation_id or not sender_id or not content.strip():
        return

    chats = load_chats_data()
    messages = chats.get("messages", [])
    new_id = max([m.get("id", 0) for m in messages], default=0) + 1
    now_iso = datetime.now().isoformat()

    msg_obj = {
        "id": new_id,
        "conversation_id": int(conversation_id),
        "sender_id": str(sender_id),
        "content": content.strip(),
        "timestamp": now_iso,
        "is_read": False,
        "image_url": image_url,
    }
    messages.append(msg_obj)
    chats["messages"] = messages

    # Update conversation's updated_at timestamp in JSON
    for c in chats.get("conversations", []):
        if c.get("id") == int(conversation_id):
            c["updated_at"] = now_iso
            break

    save_chats_data(chats)

    # Broadcast message to room
    room = f"conversation_{conversation_id}"
    await sio.emit("new_message", msg_obj, room=room)
    print(f"[SOCKET] Message emitted to room {room}: {content}")

# ---------------------------------------------------------------------------
# Pydantic Schemas
# ---------------------------------------------------------------------------
class ConversationCreate(BaseModel):
    user_id: str
    contact_id: str
    contact_name: str
    contact_avatar_url: Optional[str] = None

class MessageCreate(BaseModel):
    sender_id: str
    content: str
    image_url: Optional[str] = None

# ---------------------------------------------------------------------------
# REST Routes (synced with chats.json)
# ---------------------------------------------------------------------------
@fastapi_app.get("/", tags=["Health"])
def health_check():
    return {"status": "ok", "service": "PawStay Message Service", "port": 8001}

@fastapi_app.get("/conversations", tags=["Conversations"])
def list_conversations(user_id: str):
    """
    Return all conversations involving given user_id from chats.json using alias sets
    """
    chats = load_chats_data()
    conversations = chats.get("conversations", [])
    messages = chats.get("messages", [])

    my_aliases = get_user_aliases(user_id)

    user_convs = [
        c for c in conversations
        if c.get("user_id") in my_aliases or c.get("contact_id") in my_aliases
    ]
    user_convs.sort(key=lambda x: x.get("updated_at", ""), reverse=True)

    result = []
    for conv in user_convs:
        conv_id = conv.get("id")
        conv_msgs = [m for m in messages if m.get("conversation_id") == conv_id]
        conv_msgs.sort(key=lambda x: x.get("timestamp", ""))

        last_msg = conv_msgs[-1] if conv_msgs else None
        unread = sum(1 for m in conv_msgs if m.get("sender_id") not in my_aliases and not m.get("is_read", False))

        is_initiator = conv.get("user_id") in my_aliases
        other_user_id = conv.get("contact_id") if is_initiator else conv.get("user_id")

        c_name = conv.get("contact_name") if is_initiator else conv.get("user_id")
        c_avatar = conv.get("contact_avatar_url") if is_initiator else None
        c_id = other_user_id

        # Query DB for other user details to show correct display name & avatar
        try:
            if os.path.exists(DB_PATH):
                conn = sqlite3.connect(DB_PATH)
                cursor = conn.cursor()
                cursor.execute(
                    "SELECT username, full_name, profile_image FROM users WHERE username = ? OR email = ? OR id = ?",
                    (other_user_id, other_user_id, int(other_user_id) if other_user_id.isdigit() else -1)
                )
                row = cursor.fetchone()
                if row:
                    username, full_name, profile_image = row
                    c_name = full_name or username or c_name
                    c_avatar = profile_image or c_avatar
                    c_id = username or c_id
                conn.close()
        except Exception as e:
            print(f"[WARN] Failed to fetch user details: {e}")


        result.append({
            "id": conv_id,
            "user_id": user_id,
            "contact_id": c_id,
            "contact_name": c_name,
            "contact_avatar_url": c_avatar,
            "last_message": last_msg.get("content") if last_msg else None,
            "last_message_time": last_msg.get("timestamp") if last_msg else None,
            "unread_count": unread,
        })

    return result

@fastapi_app.post("/conversations", status_code=status.HTTP_201_CREATED, tags=["Conversations"])
def create_or_get_conversation(payload: ConversationCreate):
    """
    Find existing conversation or create a new one in chats.json with alias matching
    """
    chats = load_chats_data()
    conversations = chats.get("conversations", [])

    user1_aliases = get_user_aliases(payload.user_id)
    user2_aliases = get_user_aliases(payload.contact_id)

    for conv in conversations:
        c_user = conv.get("user_id")
        c_contact = conv.get("contact_id")
        if (c_user in user1_aliases and c_contact in user2_aliases) or \
           (c_user in user2_aliases and c_contact in user1_aliases):
            return {"id": conv.get("id"), "created": False}

    new_id = max([c.get("id", 0) for c in conversations], default=0) + 1
    now_iso = datetime.now().isoformat()

    new_conv = {
        "id": new_id,
        "user_id": payload.user_id,
        "contact_id": payload.contact_id,
        "contact_name": payload.contact_name,
        "contact_avatar_url": payload.contact_avatar_url,
        "updated_at": now_iso,
    }
    conversations.append(new_conv)
    chats["conversations"] = conversations
    save_chats_data(chats)

    return {"id": new_id, "created": True}

@fastapi_app.get("/conversations/{conversation_id}/messages", tags=["Messages"])
def get_messages(conversation_id: int):
    """
    Return all messages in a conversation from chats.json
    """
    chats = load_chats_data()
    messages = chats.get("messages", [])

    conv_msgs = [m for m in messages if m.get("conversation_id") == conversation_id]
    conv_msgs.sort(key=lambda x: x.get("timestamp", ""))
    return conv_msgs

@fastapi_app.post("/conversations/{conversation_id}/messages", status_code=status.HTTP_201_CREATED, tags=["Messages"])
async def send_message_rest(conversation_id: int, payload: MessageCreate):
    """
    Send a message via REST endpoint and emit Socket.IO notification
    """
    chats = load_chats_data()
    messages = chats.get("messages", [])

    new_id = max([m.get("id", 0) for m in messages], default=0) + 1
    now_iso = datetime.now().isoformat()

    msg_obj = {
        "id": new_id,
        "conversation_id": conversation_id,
        "sender_id": payload.sender_id,
        "content": payload.content.strip(),
        "timestamp": now_iso,
        "is_read": False,
        "image_url": payload.image_url,
    }
    messages.append(msg_obj)
    chats["messages"] = messages

    for c in chats.get("conversations", []):
        if c.get("id") == conversation_id:
            c["updated_at"] = now_iso
            break

    save_chats_data(chats)

    # Emit to Socket.IO room as well
    room = f"conversation_{conversation_id}"
    await sio.emit("new_message", msg_obj, room=room)

    return msg_obj

@fastapi_app.patch("/conversations/{conversation_id}/messages/read", tags=["Messages"])
def mark_messages_read(conversation_id: int, user_id: str):
    """
    Mark all messages in a conversation from other users as read in chats.json
    """
    chats = load_chats_data()
    messages = chats.get("messages", [])
    my_aliases = get_user_aliases(user_id)

    updated = False
    for m in messages:
        if m.get("conversation_id") == conversation_id and m.get("sender_id") not in my_aliases:
            if not m.get("is_read", False):
                m["is_read"] = True
                updated = True

    if updated:
        chats["messages"] = messages
        save_chats_data(chats)

    return {"success": True, "message": "Messages marked as read."}


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8001,
        reload=True,
    )
