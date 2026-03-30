#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-cf-worker" "$@"
header "Cloudflare Workers + Hono 4 + TypeScript + D1/KV"

create_project_dir

# ── package.json ─────────────────────────────────────────────
section "Package configuration"
write_package_json '{
  "name": "'"$PROJECT_NAME"'",
  "version": "0.0.1",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "wrangler dev",
    "build": "wrangler deploy --dry-run --outdir=dist",
    "deploy": "wrangler deploy",
    "test": "vitest run",
    "test:watch": "vitest",
    "db:migrate:local": "wrangler d1 execute DB --local --file=src/db/schema.sql",
    "db:migrate:remote": "wrangler d1 execute DB --remote --file=src/db/schema.sql",
    "tail": "wrangler tail"
  },
  "dependencies": {
    "hono": "^4.7.0"
  },
  "devDependencies": {
    "@cloudflare/vitest-pool-workers": "^0.8.0",
    "@cloudflare/workers-types": "^4.20250214.0",
    "typescript": "^5.8.0",
    "vitest": "^3.2.0",
    "wrangler": "^4.14.0"
  }
}'

# ── TypeScript ───────────────────────────────────────────────
section "TypeScript configuration"
write_tsconfig '{
  "compilerOptions": {
    "target": "ESNext",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "lib": ["ESNext"],
    "types": ["@cloudflare/workers-types", "@cloudflare/vitest-pool-workers"],
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "jsx": "react-jsx",
    "jsxImportSource": "hono/jsx",
    "noEmit": true
  },
  "include": ["src"],
  "exclude": ["node_modules", "dist"]
}'

# ── wrangler.toml ────────────────────────────────────────────
section "Wrangler configuration"
write_file_heredoc wrangler.toml << EOF
name = "$PROJECT_NAME"
main = "src/index.ts"
compatibility_date = "2025-03-01"
compatibility_flags = ["nodejs_compat"]

# D1 Database
[[d1_databases]]
binding = "DB"
database_name = "$PROJECT_NAME-db"
database_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
migrations_dir = "src/db/migrations"

# KV Namespace
[[kv_namespaces]]
binding = "KV"
id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# Environment variables
[vars]
ENVIRONMENT = "development"

# Production overrides
[env.production]
vars = { ENVIRONMENT = "production" }

# [env.production.d1_databases]
# [[env.production.d1_databases]]
# binding = "DB"
# database_name = "$PROJECT_NAME-db-prod"
# database_id = "your-production-database-id"
EOF
success "Created wrangler.toml"

# ── Vitest ───────────────────────────────────────────────────
section "Vitest configuration"
write_file_heredoc vitest.config.ts << 'EOF'
import { defineWorkersConfig } from "@cloudflare/vitest-pool-workers/config";

export default defineWorkersConfig({
  test: {
    globals: true,
    poolOptions: {
      workers: {
        wrangler: { configPath: "./wrangler.toml" },
      },
    },
  },
});
EOF
success "Created vitest.config.ts"

# ── Source files ─────────────────────────────────────────────
section "Application source files"
mkdir -p src/routes src/db/migrations src/middleware

# src/index.ts
write_file_heredoc src/index.ts << 'EOF'
import { Hono } from "hono";
import { cors } from "hono/cors";
import { logger } from "hono/logger";
import { prettyJSON } from "hono/pretty-json";
import { userRoutes } from "./routes/users";
import { healthRoutes } from "./routes/health";
import type { Env } from "./types";

const app = new Hono<{ Bindings: Env }>();

// Middleware
app.use("*", logger());
app.use("*", cors());
app.use("*", prettyJSON());

// Routes
app.route("/", healthRoutes);
app.route("/api/users", userRoutes);

// 404 handler
app.notFound((c) => {
  return c.json({ error: "Not Found", path: c.req.path }, 404);
});

// Error handler
app.onError((err, c) => {
  console.error(`${err}`);
  return c.json({ error: "Internal Server Error" }, 500);
});

export default app;
EOF
success "Created src/index.ts"

# src/types.ts
write_file_heredoc src/types.ts << 'EOF'
export interface Env {
  DB: D1Database;
  KV: KVNamespace;
  ENVIRONMENT: string;
}

export interface User {
  id: number;
  email: string;
  name: string | null;
  created_at: string;
  updated_at: string;
}
EOF
success "Created src/types.ts"

# src/routes/health.ts
write_file_heredoc src/routes/health.ts << 'EOF'
import { Hono } from "hono";
import type { Env } from "../types";

export const healthRoutes = new Hono<{ Bindings: Env }>();

healthRoutes.get("/health", (c) => {
  return c.json({
    status: "ok",
    environment: c.env.ENVIRONMENT,
    timestamp: new Date().toISOString(),
  });
});
EOF
success "Created src/routes/health.ts"

# src/routes/users.ts
write_file_heredoc src/routes/users.ts << 'EOF'
import { Hono } from "hono";
import type { Env, User } from "../types";

export const userRoutes = new Hono<{ Bindings: Env }>();

// List all users
userRoutes.get("/", async (c) => {
  const { results } = await c.env.DB.prepare(
    "SELECT * FROM users ORDER BY created_at DESC"
  ).all<User>();
  return c.json({ users: results });
});

// Get user by ID
userRoutes.get("/:id", async (c) => {
  const id = c.req.param("id");
  const user = await c.env.DB.prepare(
    "SELECT * FROM users WHERE id = ?"
  ).bind(id).first<User>();

  if (!user) {
    return c.json({ error: "User not found" }, 404);
  }
  return c.json({ user });
});

// Create user
userRoutes.post("/", async (c) => {
  const body = await c.req.json<{ email: string; name?: string }>();

  if (!body.email) {
    return c.json({ error: "Email is required" }, 400);
  }

  const result = await c.env.DB.prepare(
    "INSERT INTO users (email, name) VALUES (?, ?) RETURNING *"
  ).bind(body.email, body.name ?? null).first<User>();

  return c.json({ user: result }, 201);
});

// Update user
userRoutes.put("/:id", async (c) => {
  const id = c.req.param("id");
  const body = await c.req.json<{ email?: string; name?: string }>();

  const user = await c.env.DB.prepare(
    "UPDATE users SET email = COALESCE(?, email), name = COALESCE(?, name), updated_at = datetime('now') WHERE id = ? RETURNING *"
  ).bind(body.email ?? null, body.name ?? null, id).first<User>();

  if (!user) {
    return c.json({ error: "User not found" }, 404);
  }
  return c.json({ user });
});

// Delete user
userRoutes.delete("/:id", async (c) => {
  const id = c.req.param("id");
  await c.env.DB.prepare("DELETE FROM users WHERE id = ?").bind(id).run();
  return c.body(null, 204);
});

// Cache example with KV
userRoutes.get("/:id/cached", async (c) => {
  const id = c.req.param("id");
  const cacheKey = `user:${id}`;

  // Try KV cache first
  const cached = await c.env.KV.get(cacheKey, "json");
  if (cached) {
    return c.json({ user: cached, source: "cache" });
  }

  // Fetch from D1
  const user = await c.env.DB.prepare(
    "SELECT * FROM users WHERE id = ?"
  ).bind(id).first<User>();

  if (!user) {
    return c.json({ error: "User not found" }, 404);
  }

  // Cache for 5 minutes
  await c.env.KV.put(cacheKey, JSON.stringify(user), { expirationTtl: 300 });
  return c.json({ user, source: "database" });
});
EOF
success "Created src/routes/users.ts"

# ── Database schema ──────────────────────────────────────────
section "Database schema"

write_file_heredoc src/db/schema.sql << 'EOF'
-- Users table
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT UNIQUE NOT NULL,
    name TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- Seed data
INSERT OR IGNORE INTO users (email, name) VALUES
    ('alice@example.com', 'Alice'),
    ('bob@example.com', 'Bob');
EOF
success "Created src/db/schema.sql"

write_file_heredoc src/db/migrations/0001_initial.sql << 'EOF'
-- Migration: Initial schema
-- Created at: 2025-01-01

CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT UNIQUE NOT NULL,
    name TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
EOF
success "Created src/db/migrations/0001_initial.sql"

# ── Tests ────────────────────────────────────────────────────
section "Tests"
write_file_heredoc src/index.test.ts << 'EOF'
import { describe, it, expect } from "vitest";
import { SELF } from "cloudflare:test";

describe("Worker", () => {
  it("should return health check", async () => {
    const response = await SELF.fetch("http://localhost/health");
    expect(response.status).toBe(200);
    const body = await response.json() as { status: string };
    expect(body.status).toBe("ok");
  });

  it("should return 404 for unknown routes", async () => {
    const response = await SELF.fetch("http://localhost/unknown");
    expect(response.status).toBe(404);
  });
});
EOF
success "Created src/index.test.ts"

# ── .nvmrc ───────────────────────────────────────────────────
write_nvmrc "22"

# ── Finalize ─────────────────────────────────────────────────
section "Finalizing"
write_gitignore ".env" ".wrangler/" ".dev.vars"
write_editorconfig
init_git

write_readme "$PROJECT_NAME" \
  "Cloudflare Workers API with Hono, D1 database, and KV storage." \
  "npm install" \
  "npm run dev" \
  "Run \`npm run db:migrate:local\` to set up the local D1 database."

finish "npm install" "npm run db:migrate:local && npm run dev"
