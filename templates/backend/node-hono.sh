#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-hono-app" "$@"
header "Node.js + Hono 4 + TypeScript + Drizzle ORM + PostgreSQL"

create_project_dir

# ── package.json ──────────────────────────────────────────────
section "Package configuration"
write_package_json '{
  "name": "'"$PROJECT_NAME"'",
  "version": "0.0.1",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "tsx watch src/index.ts",
    "build": "tsc",
    "start": "node dist/index.js",
    "lint": "eslint .",
    "test": "vitest run",
    "db:generate": "drizzle-kit generate",
    "db:migrate": "drizzle-kit migrate",
    "db:push": "drizzle-kit push",
    "db:studio": "drizzle-kit studio"
  },
  "dependencies": {
    "hono": "^4.7.0",
    "@hono/node-server": "^1.14.0",
    "@hono/zod-validator": "^0.5.0",
    "drizzle-orm": "^0.44.0",
    "postgres": "^3.4.5",
    "zod": "^3.24.0",
    "dotenv": "^16.5.0"
  },
  "devDependencies": {
    "typescript": "^5.8.0",
    "tsx": "^4.19.0",
    "@types/node": "^22.15.0",
    "drizzle-kit": "^0.31.0",
    "eslint": "^9.27.0",
    "@eslint/js": "^9.27.0",
    "typescript-eslint": "^8.32.0",
    "vitest": "^3.2.0"
  }
}'

# ── TypeScript ────────────────────────────────────────────────
section "TypeScript configuration"
write_tsconfig '{
  "compilerOptions": {
    "target": "ES2024",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "lib": ["ES2024"],
    "outDir": "dist",
    "rootDir": "src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "declaration": true,
    "sourceMap": true
  },
  "include": ["src", "drizzle.config.ts"],
  "exclude": ["node_modules", "dist"]
}'

# ── ESLint 9 ──────────────────────────────────────────────────
section "ESLint configuration"
write_file_heredoc eslint.config.js << 'EOF'
import js from "@eslint/js";
import tseslint from "typescript-eslint";

export default tseslint.config(
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    ignores: ["dist/", "node_modules/"],
  },
);
EOF
success "Created eslint.config.js"

# ── Drizzle config ───────────────────────────────────────────
section "Drizzle ORM configuration"
write_file_heredoc drizzle.config.ts << 'EOF'
import "dotenv/config";
import { defineConfig } from "drizzle-kit";

export default defineConfig({
  out: "./drizzle",
  schema: "./src/db/schema.ts",
  dialect: "postgresql",
  dbCredentials: {
    url: process.env.DATABASE_URL!,
  },
});
EOF
success "Created drizzle.config.ts"

# ── Database ─────────────────────────────────────────────────
mkdir -p src/db

write_file_heredoc src/db/schema.ts << 'EOF'
import { pgTable, text, boolean, timestamp } from "drizzle-orm/pg-core";

export const users = pgTable("users", {
  id: text("id").primaryKey().$defaultFn(() => crypto.randomUUID()),
  email: text("email").notNull().unique(),
  name: text("name"),
  createdAt: timestamp("created_at").defaultNow().notNull(),
  updatedAt: timestamp("updated_at").defaultNow().notNull(),
});

export const posts = pgTable("posts", {
  id: text("id").primaryKey().$defaultFn(() => crypto.randomUUID()),
  title: text("title").notNull(),
  content: text("content"),
  published: boolean("published").default(false).notNull(),
  authorId: text("author_id").notNull().references(() => users.id),
  createdAt: timestamp("created_at").defaultNow().notNull(),
  updatedAt: timestamp("updated_at").defaultNow().notNull(),
});
EOF
success "Created src/db/schema.ts"

write_file_heredoc src/db/index.ts << 'EOF'
import "dotenv/config";
import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import * as schema from "./schema.js";

const client = postgres(process.env.DATABASE_URL!);
export const db = drizzle(client, { schema });
EOF
success "Created src/db/index.ts"

# ── Docker Compose ────────────────────────────────────────────
section "Docker Compose"
write_file_heredoc docker-compose.yml << 'EOF'
services:
  postgres:
    image: postgres:17-alpine
    restart: unless-stopped
    ports:
      - "5432:5432"
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: app
    volumes:
      - pgdata:/var/lib/postgresql/data

volumes:
  pgdata:
EOF
success "Created docker-compose.yml"

# ── .env ──────────────────────────────────────────────────────
write_file_heredoc .env.example << 'EOF'
DATABASE_URL="postgresql://postgres:postgres@localhost:5432/app"
PORT=3000
NODE_ENV=development
EOF
success "Created .env.example"
cp .env.example .env

# ── Source files ──────────────────────────────────────────────
section "Application source files"

mkdir -p src/routes

# src/index.ts
write_file_heredoc src/index.ts << 'EOF'
import "dotenv/config";
import { serve } from "@hono/node-server";
import { app } from "./routes/index.js";

const port = Number(process.env.PORT) || 3000;

console.log(`Server running on http://localhost:${port}`);

serve({ fetch: app.fetch, port });
EOF
success "Created src/index.ts"

# src/routes/index.ts
write_file_heredoc src/routes/index.ts << 'EOF'
import { Hono } from "hono";
import { cors } from "hono/cors";
import { logger } from "hono/logger";
import { userRoutes } from "./users.js";

export const app = new Hono();

app.use("*", logger());
app.use("*", cors());

app.get("/health", (c) => {
  return c.json({ status: "ok", timestamp: new Date().toISOString() });
});

app.route("/api/users", userRoutes);
EOF
success "Created src/routes/index.ts"

# src/routes/users.ts
write_file_heredoc src/routes/users.ts << 'EOF'
import { Hono } from "hono";
import { zValidator } from "@hono/zod-validator";
import { z } from "zod";
import { eq } from "drizzle-orm";
import { db } from "../db/index.js";
import { users } from "../db/schema.js";

export const userRoutes = new Hono();

const createUserSchema = z.object({
  email: z.string().email(),
  name: z.string().optional(),
});

userRoutes.get("/", async (c) => {
  const result = await db.select().from(users);
  return c.json(result);
});

userRoutes.get("/:id", async (c) => {
  const id = c.req.param("id");
  const result = await db.select().from(users).where(eq(users.id, id));
  if (result.length === 0) {
    return c.json({ error: "User not found" }, 404);
  }
  return c.json(result[0]);
});

userRoutes.post("/", zValidator("json", createUserSchema), async (c) => {
  const data = c.req.valid("json");
  const result = await db.insert(users).values(data).returning();
  return c.json(result[0], 201);
});

userRoutes.delete("/:id", async (c) => {
  const id = c.req.param("id");
  await db.delete(users).where(eq(users.id, id));
  return c.body(null, 204);
});
EOF
success "Created src/routes/users.ts"

# ── .nvmrc ────────────────────────────────────────────────────
write_nvmrc "22"

# ── Finalize ──────────────────────────────────────────────────
section "Finalizing"
write_gitignore ".env" "drizzle/"
write_editorconfig
init_git

write_readme "$PROJECT_NAME" \
  "Node.js + Hono 4 + TypeScript + Drizzle ORM + PostgreSQL API" \
  "npm install" \
  "npm run dev"

finish "npm install" "docker compose up -d && npm run db:push && npm run dev"
