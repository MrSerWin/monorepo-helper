#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-socket-chat" "$@"
create_project_dir

# --- Root package.json (workspaces) ---
write_package_json '{
  "name": "'"$PROJECT_NAME"'",
  "version": "0.1.0",
  "private": true,
  "workspaces": ["shared", "server", "client"],
  "scripts": {
    "dev": "concurrently \"npm run dev --workspace=server\" \"npm run dev --workspace=client\"",
    "build": "npm run build --workspace=shared && npm run build --workspace=server && npm run build --workspace=client"
  },
  "devDependencies": {
    "concurrently": "^9.1.0"
  }
}'

# ========== SHARED ==========

write_file "shared/package.json" '{
  "name": "'"$PROJECT_NAME"'-shared",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "main": "./src/index.ts",
  "types": "./src/index.ts",
  "scripts": {
    "build": "tsc",
    "typecheck": "tsc --noEmit"
  },
  "devDependencies": {
    "typescript": "^5.8.3"
  }
}'

write_file "shared/tsconfig.json" '{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "declaration": true,
    "outDir": "./dist",
    "rootDir": "./src"
  },
  "include": ["src"]
}'

write_file "shared/src/index.ts" 'export interface Message {
  id: string;
  text: string;
  username: string;
  room: string;
  timestamp: number;
}

export interface User {
  id: string;
  username: string;
  room: string;
}

export interface ServerToClientEvents {
  message: (message: Message) => void;
  "room-users": (users: User[]) => void;
  "user-joined": (user: User) => void;
  "user-left": (user: User) => void;
  "message-history": (messages: Message[]) => void;
}

export interface ClientToServerEvents {
  "send-message": (text: string) => void;
  "join-room": (data: { username: string; room: string }) => void;
  "leave-room": () => void;
}

export const ROOMS = ["general", "random", "tech", "gaming"] as const;
export type RoomName = (typeof ROOMS)[number];'

# ========== SERVER ==========

write_file "server/package.json" '{
  "name": "'"$PROJECT_NAME"'-server",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "tsx watch src/index.ts",
    "build": "tsc",
    "start": "node dist/index.js"
  },
  "dependencies": {
    "'"$PROJECT_NAME"'-shared": "*",
    "cors": "^2.8.5",
    "express": "^5.1.0",
    "socket.io": "^4.8.0"
  },
  "devDependencies": {
    "@types/cors": "^2.8.17",
    "@types/express": "^5.0.0",
    "@types/node": "^22.14.0",
    "tsx": "^4.19.0",
    "typescript": "^5.8.3"
  }
}'

write_file "server/tsconfig.json" '{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "outDir": "./dist",
    "rootDir": "./src",
    "declaration": true,
    "sourceMap": true
  },
  "include": ["src"],
  "exclude": ["node_modules", "dist"]
}'

write_file "server/src/index.ts" 'import express from "express";
import { createServer } from "http";
import { Server } from "socket.io";
import cors from "cors";
import type {
  ServerToClientEvents,
  ClientToServerEvents,
  Message,
  User,
} from "'"$PROJECT_NAME"'-shared";

const app = express();
app.use(cors());

const httpServer = createServer(app);
const io = new Server<ClientToServerEvents, ServerToClientEvents>(httpServer, {
  cors: {
    origin: "http://localhost:5173",
    methods: ["GET", "POST"],
  },
});

// In-memory storage
const users = new Map<string, User>();
const messageHistory = new Map<string, Message[]>();

function getRoomUsers(room: string): User[] {
  return Array.from(users.values()).filter((u) => u.room === room);
}

function addMessage(room: string, message: Message): void {
  if (!messageHistory.has(room)) {
    messageHistory.set(room, []);
  }
  const messages = messageHistory.get(room)!;
  messages.push(message);
  // Keep last 100 messages per room
  if (messages.length > 100) {
    messages.shift();
  }
}

io.on("connection", (socket) => {
  console.log(`User connected: ${socket.id}`);

  socket.on("join-room", ({ username, room }) => {
    // Leave previous room if any
    const prevUser = users.get(socket.id);
    if (prevUser) {
      socket.leave(prevUser.room);
      users.delete(socket.id);
      io.to(prevUser.room).emit("user-left", prevUser);
      io.to(prevUser.room).emit("room-users", getRoomUsers(prevUser.room));
    }

    const user: User = { id: socket.id, username, room };
    users.set(socket.id, user);
    socket.join(room);

    // Send message history
    const history = messageHistory.get(room) || [];
    socket.emit("message-history", history);

    // Notify room
    io.to(room).emit("user-joined", user);
    io.to(room).emit("room-users", getRoomUsers(room));
  });

  socket.on("send-message", (text) => {
    const user = users.get(socket.id);
    if (!user) return;

    const message: Message = {
      id: `${socket.id}-${Date.now()}`,
      text,
      username: user.username,
      room: user.room,
      timestamp: Date.now(),
    };

    addMessage(user.room, message);
    io.to(user.room).emit("message", message);
  });

  socket.on("leave-room", () => {
    const user = users.get(socket.id);
    if (user) {
      socket.leave(user.room);
      users.delete(socket.id);
      io.to(user.room).emit("user-left", user);
      io.to(user.room).emit("room-users", getRoomUsers(user.room));
    }
  });

  socket.on("disconnect", () => {
    const user = users.get(socket.id);
    if (user) {
      users.delete(socket.id);
      io.to(user.room).emit("user-left", user);
      io.to(user.room).emit("room-users", getRoomUsers(user.room));
    }
    console.log(`User disconnected: ${socket.id}`);
  });
});

app.get("/health", (_req, res) => {
  res.json({ status: "ok" });
});

const PORT = process.env.PORT || 3001;
httpServer.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});'

# ========== CLIENT ==========

write_file "client/package.json" '{
  "name": "'"$PROJECT_NAME"'-client",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "'"$PROJECT_NAME"'-shared": "*",
    "react": "^19.1.0",
    "react-dom": "^19.1.0",
    "socket.io-client": "^4.8.0"
  },
  "devDependencies": {
    "@types/react": "^19.1.0",
    "@types/react-dom": "^19.1.0",
    "@vitejs/plugin-react": "^4.4.0",
    "typescript": "^5.8.3",
    "vite": "^6.2.0"
  }
}'

write_file "client/tsconfig.json" '{
  "compilerOptions": {
    "target": "ES2020",
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "noEmit": true,
    "jsx": "react-jsx",
    "allowImportingTsExtensions": true,
    "isolatedModules": true,
    "resolveJsonModule": true
  },
  "include": ["src"],
  "exclude": ["node_modules"]
}'

write_file "client/vite.config.ts" 'import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    open: true,
  },
});'

write_file "client/index.html" '<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>'"$PROJECT_NAME"' - Chat</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>'

write_file "client/src/main.tsx" 'import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import App from "./App";
import "./styles.css";

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <App />
  </StrictMode>
);'

write_file "client/src/socket.ts" 'import { io, Socket } from "socket.io-client";
import type { ServerToClientEvents, ClientToServerEvents } from "'"$PROJECT_NAME"'-shared";

const SERVER_URL = "http://localhost:3001";

export const socket: Socket<ServerToClientEvents, ClientToServerEvents> = io(SERVER_URL, {
  autoConnect: false,
});'

write_file "client/src/App.tsx" 'import { useState } from "react";
import { JoinForm } from "./components/JoinForm";
import { ChatRoom } from "./components/ChatRoom";

export default function App() {
  const [joined, setJoined] = useState(false);
  const [username, setUsername] = useState("");
  const [room, setRoom] = useState("");

  const handleJoin = (name: string, selectedRoom: string) => {
    setUsername(name);
    setRoom(selectedRoom);
    setJoined(true);
  };

  const handleLeave = () => {
    setJoined(false);
    setUsername("");
    setRoom("");
  };

  return (
    <div className="app">
      {!joined ? (
        <JoinForm onJoin={handleJoin} />
      ) : (
        <ChatRoom username={username} room={room} onLeave={handleLeave} />
      )}
    </div>
  );
}'

write_file "client/src/components/JoinForm.tsx" 'import { useState } from "react";
import { ROOMS } from "'"$PROJECT_NAME"'-shared";

type JoinFormProps = {
  onJoin: (username: string, room: string) => void;
};

export function JoinForm({ onJoin }: JoinFormProps) {
  const [username, setUsername] = useState("");
  const [room, setRoom] = useState<string>(ROOMS[0]);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (username.trim() && room) {
      onJoin(username.trim(), room);
    }
  };

  return (
    <div className="join-container">
      <h1>Socket Chat</h1>
      <form onSubmit={handleSubmit} className="join-form">
        <div className="form-group">
          <label htmlFor="username">Username</label>
          <input
            id="username"
            type="text"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            placeholder="Enter your name"
            required
            autoFocus
          />
        </div>
        <div className="form-group">
          <label htmlFor="room">Room</label>
          <select
            id="room"
            value={room}
            onChange={(e) => setRoom(e.target.value)}
          >
            {ROOMS.map((r) => (
              <option key={r} value={r}>
                #{r}
              </option>
            ))}
          </select>
        </div>
        <button type="submit" className="btn-join">
          Join Chat
        </button>
      </form>
    </div>
  );
}'

write_file "client/src/components/ChatRoom.tsx" 'import { useState, useEffect, useRef } from "react";
import { socket } from "../socket";
import type { Message, User } from "'"$PROJECT_NAME"'-shared";

type ChatRoomProps = {
  username: string;
  room: string;
  onLeave: () => void;
};

export function ChatRoom({ username, room, onLeave }: ChatRoomProps) {
  const [messages, setMessages] = useState<Message[]>([]);
  const [users, setUsers] = useState<User[]>([]);
  const [input, setInput] = useState("");
  const messagesEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    socket.connect();
    socket.emit("join-room", { username, room });

    socket.on("message-history", (history) => {
      setMessages(history);
    });

    socket.on("message", (message) => {
      setMessages((prev) => [...prev, message]);
    });

    socket.on("room-users", (roomUsers) => {
      setUsers(roomUsers);
    });

    return () => {
      socket.emit("leave-room");
      socket.off("message-history");
      socket.off("message");
      socket.off("room-users");
      socket.disconnect();
    };
  }, [username, room]);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  const sendMessage = (e: React.FormEvent) => {
    e.preventDefault();
    if (input.trim()) {
      socket.emit("send-message", input.trim());
      setInput("");
    }
  };

  const handleLeave = () => {
    socket.emit("leave-room");
    socket.disconnect();
    onLeave();
  };

  return (
    <div className="chat-container">
      <div className="chat-sidebar">
        <div className="room-header">
          <h2>#{room}</h2>
          <button onClick={handleLeave} className="btn-leave">Leave</button>
        </div>
        <div className="user-list">
          <h3>Online ({users.length})</h3>
          <ul>
            {users.map((user) => (
              <li key={user.id}>{user.username}</li>
            ))}
          </ul>
        </div>
      </div>
      <div className="chat-main">
        <div className="messages">
          {messages.map((msg) => (
            <div
              key={msg.id}
              className={`message ${msg.username === username ? "own" : ""}`}
            >
              <span className="message-author">{msg.username}</span>
              <span className="message-text">{msg.text}</span>
              <span className="message-time">
                {new Date(msg.timestamp).toLocaleTimeString()}
              </span>
            </div>
          ))}
          <div ref={messagesEndRef} />
        </div>
        <form onSubmit={sendMessage} className="message-form">
          <input
            type="text"
            value={input}
            onChange={(e) => setInput(e.target.value)}
            placeholder="Type a message..."
            autoFocus
          />
          <button type="submit">Send</button>
        </form>
      </div>
    </div>
  );
}'

write_file "client/src/styles.css" '* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: system-ui, -apple-system, sans-serif;
  background: #f5f5f5;
  color: #1a1a1a;
}

.app {
  height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
}

/* Join Form */
.join-container {
  background: white;
  padding: 2rem;
  border-radius: 12px;
  box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
  width: 100%;
  max-width: 400px;
}

.join-container h1 {
  text-align: center;
  margin-bottom: 1.5rem;
}

.join-form {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.form-group {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.form-group label {
  font-weight: 600;
  font-size: 0.875rem;
}

.form-group input,
.form-group select {
  padding: 0.75rem;
  border: 1px solid #ddd;
  border-radius: 8px;
  font-size: 1rem;
}

.btn-join {
  background: #2563eb;
  color: white;
  padding: 0.75rem;
  border: none;
  border-radius: 8px;
  font-size: 1rem;
  font-weight: 600;
  cursor: pointer;
}

.btn-join:hover {
  background: #1d4ed8;
}

/* Chat Room */
.chat-container {
  display: flex;
  width: 100vw;
  height: 100vh;
}

.chat-sidebar {
  width: 240px;
  background: #1e293b;
  color: white;
  display: flex;
  flex-direction: column;
}

.room-header {
  padding: 1rem;
  border-bottom: 1px solid #334155;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.room-header h2 {
  font-size: 1.125rem;
}

.btn-leave {
  background: #ef4444;
  color: white;
  border: none;
  padding: 0.375rem 0.75rem;
  border-radius: 6px;
  cursor: pointer;
  font-size: 0.8rem;
}

.user-list {
  padding: 1rem;
  flex: 1;
  overflow-y: auto;
}

.user-list h3 {
  font-size: 0.8rem;
  text-transform: uppercase;
  color: #94a3b8;
  margin-bottom: 0.5rem;
}

.user-list ul {
  list-style: none;
}

.user-list li {
  padding: 0.25rem 0;
  font-size: 0.9rem;
}

.user-list li::before {
  content: "";
  display: inline-block;
  width: 8px;
  height: 8px;
  background: #22c55e;
  border-radius: 50%;
  margin-right: 0.5rem;
}

/* Chat Main */
.chat-main {
  flex: 1;
  display: flex;
  flex-direction: column;
}

.messages {
  flex: 1;
  padding: 1rem;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.message {
  display: flex;
  flex-direction: column;
  background: white;
  padding: 0.5rem 0.75rem;
  border-radius: 8px;
  max-width: 70%;
  align-self: flex-start;
}

.message.own {
  align-self: flex-end;
  background: #dbeafe;
}

.message-author {
  font-weight: 600;
  font-size: 0.8rem;
  color: #2563eb;
}

.message.own .message-author {
  color: #1d4ed8;
}

.message-text {
  margin: 0.125rem 0;
}

.message-time {
  font-size: 0.7rem;
  color: #94a3b8;
  align-self: flex-end;
}

.message-form {
  display: flex;
  padding: 1rem;
  gap: 0.5rem;
  border-top: 1px solid #e2e8f0;
  background: white;
}

.message-form input {
  flex: 1;
  padding: 0.75rem;
  border: 1px solid #ddd;
  border-radius: 8px;
  font-size: 1rem;
}

.message-form button {
  background: #2563eb;
  color: white;
  border: none;
  padding: 0.75rem 1.5rem;
  border-radius: 8px;
  font-weight: 600;
  cursor: pointer;
}

.message-form button:hover {
  background: #1d4ed8;
}'

write_file "client/src/vite-env.d.ts" '/// <reference types="vite/client" />'

init_git
write_gitignore
write_editorconfig
write_nvmrc

finish "npm install" "npm run dev"
