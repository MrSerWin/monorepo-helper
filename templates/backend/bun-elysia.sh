#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-elysia-app" "$@"
header "Bun + Elysia 1.2 + TypeScript + Drizzle ORM + PostgreSQL"

create_project_dir

# ── package.json ──────────────────────────────────────────────
section "Package configuration"
write_package_json '{
  "name": "'"$PROJECT_NAME"'",
  "version": "0.0.1",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "bun run --watch src/index.ts",
    "start": "bun run src/index.ts",
    "lint": "eslint .",
    "test": "bun test",
    "db:generate": "drizzle-kit generate",
    "db:migrate": "drizzle-kit migrate",
    "db:push": "drizzle-kit push",
    "db:studio": "drizzle-kit studio"
  },
  "dependencies": {
    "elysia": "^1.2.0",
    "@elysiajs/swagger": "^1.2.0",
    "@elysiajs/cors": "^1.2.0",
    "drizzle-orm": "^0.44.0",
    "postgres": "^3.4.5"
  },
  "devDependencies": {
    "@types/bun": "^1.2.0",
    "typescript": "^5.8.0",
    "drizzle-kit": "^0.31.0",
    "eslint": "^9.27.0",
    "@eslint/js": "^9.27.0",
    "typescript-eslint": "^8.32.0"
  }
}'

# ── TypeScript ────────────────────────────────────────────────
section "TypeScript configuration"
write_tsconfig '{
  "compilerOptions": {
    "target": "ES2024",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "lib": ["ES2024"],
    "types": ["bun-types"],
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "declaration": true,
    "sourceMap": true,
    "outDir": "dist",
    "rootDir": "src"
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

# ── bunfig.toml ──────────────────────────────────────────────
write_file_heredoc bunfig.toml << 'EOF'
[test]
preload = ["./src/test-setup.ts"]
EOF
success "Created bunfig.toml"

write_file_heredoc src/test-setup.ts << 'EOF'
// Test setup file — add global test utilities here
EOF

# ── Drizzle config ───────────────────────────────────────────
section "Drizzle ORM configuration"
write_file_heredoc drizzle.config.ts << 'EOF'
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
import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import * as schema from "./schema";

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
EOF
success "Created .env.example"
cp .env.example .env

# ── Source files ──────────────────────────────────────────────
section "Application source files"

mkdir -p src/routes

# src/index.ts
write_file_heredoc src/index.ts << 'EOF'
import { Elysia } from "elysia";
import { swagger } from "@elysiajs/swagger";
import { cors } from "@elysiajs/cors";
import { userRoutes } from "./routes/users";

const port = Number(process.env.PORT) || 3000;

const app = new Elysia()
  .use(cors())
  .use(swagger({ path: "/docs" }))
  .get("/health", () => ({ status: "ok", timestamp: new Date().toISOString() }))
  .use(userRoutes)
  .listen(port);

console.log(`Server running on http://localhost:${port}`);

export type App = typeof app;
EOF
success "Created src/index.ts"

# src/routes/users.ts
write_file_heredoc src/routes/users.ts << 'EOF'
import { Elysia, t } from "elysia";
import { eq } from "drizzle-orm";
import { db } from "../db";
import { users } from "../db/schema";

export const userRoutes = new Elysia({ prefix: "/api/users" })
  .get("/", async () => {
    return db.select().from(users);
  })
  .get("/:id", async ({ params, set }) => {
    const result = await db.select().from(users).where(eq(users.id, params.id));
    if (result.length === 0) {
      set.status = 404;
      return { error: "User not found" };
    }
    return result[0];
  }, {
    params: t.Object({ id: t.String() }),
  })
  .post("/", async ({ body, set }) => {
    const result = await db.insert(users).values(body).returning();
    set.status = 201;
    return result[0];
  }, {
    body: t.Object({
      email: t.String({ format: "email" }),
      name: t.Optional(t.String()),
    }),
  })
  .delete("/:id", async ({ params, set }) => {
    await db.delete(users).where(eq(users.id, params.id));
    set.status = 204;
  }, {
    params: t.Object({ id: t.String() }),
  });
EOF
success "Created src/routes/users.ts"

# ── Test file ─────────────────────────────────────────────────
write_file_heredoc src/index.test.ts << 'EOF'
import { describe, it, expect } from "bun:test";

describe("App", () => {
  it("should work", () => {
    expect(1 + 1).toBe(2);
  });
});
EOF
success "Created src/index.test.ts"

# ── Finalize ──────────────────────────────────────────────────
section "Finalizing"
write_gitignore ".env" "drizzle/"
write_editorconfig
init_git

write_readme "$PROJECT_NAME" \
  "Bun + Elysia 1.2 + TypeScript + Drizzle ORM + PostgreSQL API" \
  "bun install" \
  "bun run dev"

finish "bun install" "docker compose up -d && bun run db:push && bun run dev"
