#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-vercel-api" "$@"
header "Vercel Functions + TypeScript + Vercel KV/Postgres"

create_project_dir

# ── package.json ─────────────────────────────────────────────
section "Package configuration"
write_package_json '{
  "name": "'"$PROJECT_NAME"'",
  "version": "0.0.1",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vercel dev",
    "build": "tsc --noEmit",
    "lint": "eslint api/ lib/",
    "test": "vitest run",
    "test:watch": "vitest",
    "deploy": "vercel --prod",
    "deploy:preview": "vercel"
  },
  "dependencies": {
    "@vercel/postgres": "^0.10.0",
    "@vercel/kv": "^3.0.0",
    "zod": "^3.24.0"
  },
  "devDependencies": {
    "typescript": "^5.8.0",
    "@types/node": "^22.15.0",
    "vercel": "^41.0.0",
    "vitest": "^3.2.0",
    "eslint": "^9.27.0",
    "@eslint/js": "^9.27.0",
    "typescript-eslint": "^8.32.0"
  }
}'

# ── TypeScript ───────────────────────────────────────────────
section "TypeScript configuration"
write_tsconfig '{
  "compilerOptions": {
    "target": "ES2024",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "lib": ["ES2024"],
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "noEmit": true,
    "isolatedModules": true,
    "baseUrl": ".",
    "paths": {
      "@/lib/*": ["lib/*"]
    }
  },
  "include": ["api", "lib"],
  "exclude": ["node_modules"]
}'

# ── vercel.json ──────────────────────────────────────────────
section "Vercel configuration"
write_file_heredoc vercel.json << 'EOF'
{
  "$schema": "https://openapi.vercel.sh/vercel.json",
  "framework": null,
  "functions": {
    "api/**/*.ts": {
      "memory": 256,
      "maxDuration": 30
    }
  },
  "rewrites": [
    { "source": "/api/(.*)", "destination": "/api/$1" }
  ],
  "headers": [
    {
      "source": "/api/(.*)",
      "headers": [
        { "key": "Access-Control-Allow-Origin", "value": "*" },
        { "key": "Access-Control-Allow-Methods", "value": "GET,POST,PUT,DELETE,OPTIONS" },
        { "key": "Access-Control-Allow-Headers", "value": "Content-Type,Authorization" }
      ]
    }
  ]
}
EOF
success "Created vercel.json"

# ── ESLint ───────────────────────────────────────────────────
section "ESLint configuration"
write_file_heredoc eslint.config.js << 'EOF'
import js from "@eslint/js";
import tseslint from "typescript-eslint";

export default tseslint.config(
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    ignores: ["node_modules/", ".vercel/"],
  },
);
EOF
success "Created eslint.config.js"

# ── Vitest ───────────────────────────────────────────────────
section "Vitest configuration"
write_file_heredoc vitest.config.ts << 'EOF'
import { defineConfig } from "vitest/config";
import { resolve } from "path";

export default defineConfig({
  test: {
    globals: true,
    environment: "node",
    include: ["**/*.test.ts"],
  },
  resolve: {
    alias: {
      "@/lib": resolve(__dirname, "lib"),
    },
  },
});
EOF
success "Created vitest.config.ts"

# ── Shared library ───────────────────────────────────────────
section "Shared library"
mkdir -p lib

# lib/db.ts
write_file_heredoc lib/db.ts << 'EOF'
import { sql } from "@vercel/postgres";

export interface User {
  id: number;
  email: string;
  name: string | null;
  created_at: string;
  updated_at: string;
}

export async function getUsers(): Promise<User[]> {
  const { rows } = await sql<User>`SELECT * FROM users ORDER BY created_at DESC`;
  return rows;
}

export async function getUserById(id: number): Promise<User | null> {
  const { rows } = await sql<User>`SELECT * FROM users WHERE id = ${id}`;
  return rows[0] ?? null;
}

export async function createUser(email: string, name?: string): Promise<User> {
  const { rows } = await sql<User>`
    INSERT INTO users (email, name)
    VALUES (${email}, ${name ?? null})
    RETURNING *
  `;
  return rows[0];
}

export async function updateUser(id: number, email?: string, name?: string): Promise<User | null> {
  const { rows } = await sql<User>`
    UPDATE users
    SET
      email = COALESCE(${email ?? null}, email),
      name = COALESCE(${name ?? null}, name),
      updated_at = NOW()
    WHERE id = ${id}
    RETURNING *
  `;
  return rows[0] ?? null;
}

export async function deleteUser(id: number): Promise<boolean> {
  const { rowCount } = await sql`DELETE FROM users WHERE id = ${id}`;
  return (rowCount ?? 0) > 0;
}

// Run this once to initialize the database
export async function initializeDatabase(): Promise<void> {
  await sql`
    CREATE TABLE IF NOT EXISTS users (
      id SERIAL PRIMARY KEY,
      email VARCHAR(255) UNIQUE NOT NULL,
      name VARCHAR(255),
      created_at TIMESTAMPTZ DEFAULT NOW(),
      updated_at TIMESTAMPTZ DEFAULT NOW()
    )
  `;
  await sql`CREATE INDEX IF NOT EXISTS idx_users_email ON users(email)`;
}
EOF
success "Created lib/db.ts"

# lib/cache.ts
write_file_heredoc lib/cache.ts << 'EOF'
import { kv } from "@vercel/kv";

export async function getCached<T>(key: string): Promise<T | null> {
  return kv.get<T>(key);
}

export async function setCache<T>(key: string, value: T, ttlSeconds = 300): Promise<void> {
  await kv.set(key, value, { ex: ttlSeconds });
}

export async function invalidateCache(key: string): Promise<void> {
  await kv.del(key);
}

export async function invalidatePattern(pattern: string): Promise<void> {
  const keys = await kv.keys(pattern);
  if (keys.length > 0) {
    await kv.del(...keys);
  }
}
EOF
success "Created lib/cache.ts"

# lib/response.ts
write_file_heredoc lib/response.ts << 'EOF'
export function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

export function error(message: string, status = 500): Response {
  return json({ error: message }, status);
}

export function noContent(): Response {
  return new Response(null, { status: 204 });
}
EOF
success "Created lib/response.ts"

# lib/validate.ts
write_file_heredoc lib/validate.ts << 'EOF'
import { z } from "zod";

export const CreateUserSchema = z.object({
  email: z.string().email("Invalid email address"),
  name: z.string().min(1).max(255).optional(),
});

export const UpdateUserSchema = z.object({
  email: z.string().email("Invalid email address").optional(),
  name: z.string().min(1).max(255).optional(),
}).refine((data) => data.email || data.name, {
  message: "At least one field must be provided",
});

export type CreateUserInput = z.infer<typeof CreateUserSchema>;
export type UpdateUserInput = z.infer<typeof UpdateUserSchema>;
EOF
success "Created lib/validate.ts"

# ── API Routes ───────────────────────────────────────────────
section "API routes"
mkdir -p api/users

# api/hello.ts
write_file_heredoc api/hello.ts << 'EOF'
export const config = { runtime: "edge" };

export default function handler(request: Request): Response {
  const url = new URL(request.url);
  const name = url.searchParams.get("name") ?? "World";

  return new Response(
    JSON.stringify({
      message: `Hello, ${name}!`,
      timestamp: new Date().toISOString(),
    }),
    {
      status: 200,
      headers: { "Content-Type": "application/json" },
    }
  );
}
EOF
success "Created api/hello.ts"

# api/health.ts
write_file_heredoc api/health.ts << 'EOF'
import { sql } from "@vercel/postgres";
import { json, error } from "../lib/response.js";

export default async function handler(): Promise<Response> {
  try {
    await sql`SELECT 1`;
    return json({
      status: "ok",
      database: "connected",
      timestamp: new Date().toISOString(),
    });
  } catch (err) {
    return error("Database connection failed", 503);
  }
}
EOF
success "Created api/health.ts"

# api/users/index.ts (GET all, POST create)
write_file_heredoc api/users/index.ts << 'EOF'
import { getUsers, createUser } from "../../lib/db.js";
import { json, error } from "../../lib/response.js";
import { CreateUserSchema } from "../../lib/validate.js";

export default async function handler(request: Request): Promise<Response> {
  if (request.method === "GET") {
    try {
      const users = await getUsers();
      return json({ users });
    } catch (err) {
      console.error("Error fetching users:", err);
      return error("Failed to fetch users");
    }
  }

  if (request.method === "POST") {
    try {
      const body = await request.json();
      const parsed = CreateUserSchema.safeParse(body);

      if (!parsed.success) {
        return error(parsed.error.errors[0].message, 400);
      }

      const user = await createUser(parsed.data.email, parsed.data.name);
      return json({ user }, 201);
    } catch (err: any) {
      if (err?.code === "23505") {
        return error("Email already exists", 409);
      }
      console.error("Error creating user:", err);
      return error("Failed to create user");
    }
  }

  return error("Method not allowed", 405);
}
EOF
success "Created api/users/index.ts"

# api/users/[id].ts (GET one, PUT update, DELETE)
write_file_heredoc 'api/users/[id].ts' << 'EOF'
import { getUserById, updateUser, deleteUser } from "../../lib/db.js";
import { json, error, noContent } from "../../lib/response.js";
import { UpdateUserSchema } from "../../lib/validate.js";

export default async function handler(request: Request): Promise<Response> {
  const url = new URL(request.url);
  const id = Number(url.pathname.split("/").pop());

  if (isNaN(id)) {
    return error("Invalid user ID", 400);
  }

  if (request.method === "GET") {
    try {
      const user = await getUserById(id);
      if (!user) {
        return error("User not found", 404);
      }
      return json({ user });
    } catch (err) {
      console.error("Error fetching user:", err);
      return error("Failed to fetch user");
    }
  }

  if (request.method === "PUT") {
    try {
      const body = await request.json();
      const parsed = UpdateUserSchema.safeParse(body);

      if (!parsed.success) {
        return error(parsed.error.errors[0].message, 400);
      }

      const user = await updateUser(id, parsed.data.email, parsed.data.name);
      if (!user) {
        return error("User not found", 404);
      }
      return json({ user });
    } catch (err) {
      console.error("Error updating user:", err);
      return error("Failed to update user");
    }
  }

  if (request.method === "DELETE") {
    try {
      const deleted = await deleteUser(id);
      if (!deleted) {
        return error("User not found", 404);
      }
      return noContent();
    } catch (err) {
      console.error("Error deleting user:", err);
      return error("Failed to delete user");
    }
  }

  return error("Method not allowed", 405);
}
EOF
success "Created api/users/[id].ts"

# api/db-init.ts
write_file_heredoc api/db-init.ts << 'EOF'
import { initializeDatabase } from "../lib/db.js";
import { json, error } from "../lib/response.js";

// One-time endpoint to initialize the database schema.
// Remove or protect this endpoint in production.
export default async function handler(): Promise<Response> {
  try {
    await initializeDatabase();
    return json({ message: "Database initialized successfully" });
  } catch (err) {
    console.error("Error initializing database:", err);
    return error("Failed to initialize database");
  }
}
EOF
success "Created api/db-init.ts"

# ── Tests ────────────────────────────────────────────────────
section "Tests"
write_file_heredoc lib/response.test.ts << 'EOF'
import { describe, it, expect } from "vitest";
import { json, error, noContent } from "./response.js";

describe("response helpers", () => {
  it("should return JSON response", async () => {
    const res = json({ message: "ok" });
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body).toEqual({ message: "ok" });
  });

  it("should return JSON with custom status", async () => {
    const res = json({ id: 1 }, 201);
    expect(res.status).toBe(201);
  });

  it("should return error response", async () => {
    const res = error("Not found", 404);
    expect(res.status).toBe(404);
    const body = await res.json();
    expect(body).toEqual({ error: "Not found" });
  });

  it("should return no content", () => {
    const res = noContent();
    expect(res.status).toBe(204);
    expect(res.body).toBeNull();
  });
});
EOF
success "Created lib/response.test.ts"

write_file_heredoc lib/validate.test.ts << 'EOF'
import { describe, it, expect } from "vitest";
import { CreateUserSchema, UpdateUserSchema } from "./validate.js";

describe("CreateUserSchema", () => {
  it("should validate a valid user", () => {
    const result = CreateUserSchema.safeParse({ email: "test@example.com", name: "Test" });
    expect(result.success).toBe(true);
  });

  it("should reject invalid email", () => {
    const result = CreateUserSchema.safeParse({ email: "not-an-email" });
    expect(result.success).toBe(false);
  });

  it("should allow missing name", () => {
    const result = CreateUserSchema.safeParse({ email: "test@example.com" });
    expect(result.success).toBe(true);
  });
});

describe("UpdateUserSchema", () => {
  it("should accept email only", () => {
    const result = UpdateUserSchema.safeParse({ email: "new@example.com" });
    expect(result.success).toBe(true);
  });

  it("should reject empty body", () => {
    const result = UpdateUserSchema.safeParse({});
    expect(result.success).toBe(false);
  });
});
EOF
success "Created lib/validate.test.ts"

# ── .env.example ─────────────────────────────────────────────
section "Environment configuration"
write_file_heredoc .env.example << 'EOF'
# Vercel Postgres (auto-populated when linked)
POSTGRES_URL=
POSTGRES_PRISMA_URL=
POSTGRES_URL_NON_POOLING=

# Vercel KV (auto-populated when linked)
KV_URL=
KV_REST_API_URL=
KV_REST_API_TOKEN=
KV_REST_API_READ_ONLY_TOKEN=
EOF
success "Created .env.example"

# ── .nvmrc ───────────────────────────────────────────────────
write_nvmrc "22"

# ── Finalize ─────────────────────────────────────────────────
section "Finalizing"
write_gitignore ".env" ".env.local" ".vercel/"
write_editorconfig
init_git

write_readme "$PROJECT_NAME" \
  "Vercel Functions API with TypeScript, Vercel Postgres, and Vercel KV." \
  "npm install" \
  "vercel dev" \
  "Link your Vercel project with \`vercel link\` and add Postgres/KV storage in the dashboard."

finish "npm install && vercel link" "vercel dev"
