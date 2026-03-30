#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-turbo-hono" "$@"
header "Turborepo + Next.js 15 + Hono 4 + Drizzle + Tailwind CSS 4"

create_project_dir

# ══════════════════════════════════════════════════════════════
# Root configuration
# ══════════════════════════════════════════════════════════════
section "Root configuration"

write_package_json '{
  "name": "'"$PROJECT_NAME"'",
  "private": true,
  "scripts": {
    "dev": "turbo dev",
    "build": "turbo build",
    "lint": "turbo lint",
    "db:generate": "turbo db:generate",
    "db:push": "turbo db:push",
    "db:migrate": "turbo db:migrate"
  },
  "devDependencies": {
    "turbo": "^2.5.0"
  },
  "packageManager": "pnpm@10.8.0"
}'

write_file_heredoc "pnpm-workspace.yaml" << 'EOF'
packages:
  - "apps/*"
  - "packages/*"
EOF
success "Created pnpm-workspace.yaml"

write_file_heredoc "turbo.json" << 'EOF'
{
  "$schema": "https://turbo.build/schema.json",
  "tasks": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": [".next/**", "!.next/cache/**", "dist/**"]
    },
    "lint": {
      "dependsOn": ["^build"]
    },
    "dev": {
      "cache": false,
      "persistent": true
    },
    "db:generate": { "cache": false },
    "db:push": { "cache": false },
    "db:migrate": { "cache": false }
  }
}
EOF
success "Created turbo.json"

write_file_heredoc "docker-compose.yml" << 'EOF'
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

write_file_heredoc ".env.example" << 'EOF'
DATABASE_URL="postgresql://postgres:postgres@localhost:5432/app?schema=public"
EOF
success "Created .env.example"

# ══════════════════════════════════════════════════════════════
# packages/tsconfig
# ══════════════════════════════════════════════════════════════
section "packages/tsconfig"
mkdir -p packages/tsconfig

write_file_heredoc "packages/tsconfig/package.json" << 'EOF'
{
  "name": "@repo/tsconfig",
  "version": "0.0.0",
  "private": true,
  "files": ["*.json"]
}
EOF

write_file_heredoc "packages/tsconfig/base.json" << 'EOF'
{
  "compilerOptions": {
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "declaration": true,
    "declarationMap": true
  }
}
EOF

write_file_heredoc "packages/tsconfig/nextjs.json" << 'EOF'
{
  "extends": "./base.json",
  "compilerOptions": {
    "target": "ES2017",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "noEmit": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "jsx": "preserve",
    "incremental": true,
    "plugins": [{ "name": "next" }]
  }
}
EOF

write_file_heredoc "packages/tsconfig/node.json" << 'EOF'
{
  "extends": "./base.json",
  "compilerOptions": {
    "target": "ES2024",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "lib": ["ES2024"],
    "outDir": "dist",
    "sourceMap": true
  }
}
EOF
success "Created packages/tsconfig"

# ══════════════════════════════════════════════════════════════
# packages/shared
# ══════════════════════════════════════════════════════════════
section "packages/shared"
mkdir -p packages/shared/src

write_file_heredoc "packages/shared/package.json" << 'EOF'
{
  "name": "@repo/shared",
  "version": "0.0.0",
  "private": true,
  "type": "module",
  "main": "./src/index.ts",
  "types": "./src/index.ts",
  "devDependencies": {
    "@repo/tsconfig": "workspace:*"
  }
}
EOF

write_file_heredoc "packages/shared/tsconfig.json" << 'EOF'
{
  "extends": "@repo/tsconfig/base.json",
  "compilerOptions": {
    "target": "ES2024",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "outDir": "dist",
    "rootDir": "src"
  },
  "include": ["src"]
}
EOF

write_file_heredoc "packages/shared/src/index.ts" << 'EOF'
export * from "./types.js";
EOF

write_file_heredoc "packages/shared/src/types.ts" << 'EOF'
export interface User {
  id: string;
  email: string;
  name: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface ApiResponse<T> {
  data: T;
  message?: string;
}

export interface PaginatedResponse<T> {
  data: T[];
  total: number;
  page: number;
  limit: number;
}
EOF
success "Created packages/shared"

# ══════════════════════════════════════════════════════════════
# packages/database (Drizzle)
# ══════════════════════════════════════════════════════════════
section "packages/database (Drizzle)"
mkdir -p packages/database/src

write_file_heredoc "packages/database/package.json" << 'EOF'
{
  "name": "@repo/database",
  "version": "0.0.0",
  "private": true,
  "type": "module",
  "main": "./src/index.ts",
  "types": "./src/index.ts",
  "scripts": {
    "db:generate": "drizzle-kit generate",
    "db:push": "drizzle-kit push",
    "db:migrate": "drizzle-kit migrate",
    "db:studio": "drizzle-kit studio"
  },
  "dependencies": {
    "drizzle-orm": "^0.44.0",
    "postgres": "^3.4.5"
  },
  "devDependencies": {
    "@repo/tsconfig": "workspace:*",
    "drizzle-kit": "^0.31.0",
    "typescript": "^5.8.3"
  }
}
EOF

write_file_heredoc "packages/database/tsconfig.json" << 'EOF'
{
  "extends": "@repo/tsconfig/base.json",
  "compilerOptions": {
    "target": "ES2024",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "outDir": "dist",
    "rootDir": "src"
  },
  "include": ["src", "drizzle.config.ts"]
}
EOF

write_file_heredoc "packages/database/drizzle.config.ts" << 'EOF'
import { defineConfig } from "drizzle-kit";

export default defineConfig({
  schema: "./src/schema.ts",
  out: "./drizzle",
  dialect: "postgresql",
  dbCredentials: {
    url: process.env.DATABASE_URL!,
  },
});
EOF

write_file_heredoc "packages/database/src/schema.ts" << 'EOF'
import { pgTable, text, timestamp, boolean } from "drizzle-orm/pg-core";
import { createId } from "./utils.js";

export const users = pgTable("users", {
  id: text("id").primaryKey().$defaultFn(createId),
  email: text("email").notNull().unique(),
  name: text("name"),
  createdAt: timestamp("created_at").defaultNow().notNull(),
  updatedAt: timestamp("updated_at").defaultNow().notNull(),
});

export const posts = pgTable("posts", {
  id: text("id").primaryKey().$defaultFn(createId),
  title: text("title").notNull(),
  content: text("content"),
  published: boolean("published").default(false).notNull(),
  authorId: text("author_id")
    .notNull()
    .references(() => users.id),
  createdAt: timestamp("created_at").defaultNow().notNull(),
  updatedAt: timestamp("updated_at").defaultNow().notNull(),
});
EOF

write_file_heredoc "packages/database/src/utils.ts" << 'EOF'
export function createId(): string {
  return crypto.randomUUID();
}
EOF

write_file_heredoc "packages/database/src/index.ts" << 'EOF'
import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import * as schema from "./schema.js";

const connectionString = process.env.DATABASE_URL!;
const client = postgres(connectionString);

export const db = drizzle(client, { schema });

export { schema };
export * from "./schema.js";
EOF
success "Created packages/database"

# ══════════════════════════════════════════════════════════════
# apps/web (Next.js 15)
# ══════════════════════════════════════════════════════════════
section "apps/web (Next.js 15)"
mkdir -p apps/web/src/app apps/web/public

write_file_heredoc "apps/web/package.json" << 'EOF'
{
  "name": "@repo/web",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "next dev --turbopack --port 3000",
    "build": "next build",
    "start": "next start",
    "lint": "next lint"
  },
  "dependencies": {
    "@repo/shared": "workspace:*",
    "next": "^15.3.0",
    "react": "^19.1.0",
    "react-dom": "^19.1.0"
  },
  "devDependencies": {
    "@repo/tsconfig": "workspace:*",
    "@tailwindcss/postcss": "^4.1.3",
    "@types/node": "^22.14.0",
    "@types/react": "^19.1.0",
    "@types/react-dom": "^19.1.0",
    "eslint": "^9.24.0",
    "eslint-config-next": "^15.3.0",
    "tailwindcss": "^4.1.3",
    "typescript": "^5.8.3"
  }
}
EOF

write_file_heredoc "apps/web/tsconfig.json" << 'EOF'
{
  "extends": "@repo/tsconfig/nextjs.json",
  "compilerOptions": {
    "paths": { "@/*": ["./src/*"] }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
EOF

write_file "apps/web/next.config.ts" 'import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  transpilePackages: ["@repo/shared"],
};

export default nextConfig;'

write_file "apps/web/postcss.config.mjs" 'const config = {
  plugins: {
    "@tailwindcss/postcss": {},
  },
};

export default config;'

write_file "apps/web/src/app/globals.css" '@import "tailwindcss";'

write_file_heredoc "apps/web/src/app/layout.tsx" << 'EOF'
import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Web App",
  description: "Next.js web application",
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body className="antialiased">{children}</body>
    </html>
  );
}
EOF

write_file_heredoc "apps/web/src/app/page.tsx" << 'EOF'
export default function Home() {
  return (
    <div className="grid min-h-screen items-center justify-items-center p-8 sm:p-20">
      <main className="flex flex-col items-center gap-8">
        <h1 className="text-4xl font-bold tracking-tight sm:text-6xl">
          Turbo <span className="text-emerald-600">Hono</span>
        </h1>
        <p className="text-lg text-gray-600 max-w-md text-center">
          Next.js + Hono + Drizzle + Tailwind CSS
        </p>
        <div className="flex gap-4">
          <a
            href="http://localhost:4000"
            className="rounded-full bg-emerald-600 text-white px-6 py-3 text-sm font-medium hover:bg-emerald-700 transition-colors"
          >
            API Server
          </a>
        </div>
      </main>
    </div>
  );
}
EOF

write_file "apps/web/next-env.d.ts" '/// <reference types="next" />
/// <reference types="next/image-types/global" />'

success "Created apps/web"

# ══════════════════════════════════════════════════════════════
# apps/api (Hono 4)
# ══════════════════════════════════════════════════════════════
section "apps/api (Hono 4)"
mkdir -p apps/api/src/routes

write_file_heredoc "apps/api/package.json" << 'EOF'
{
  "name": "@repo/api",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "tsx watch src/index.ts",
    "build": "tsc",
    "start": "node dist/index.js",
    "lint": "eslint ."
  },
  "dependencies": {
    "@repo/database": "workspace:*",
    "@repo/shared": "workspace:*",
    "hono": "^4.7.0",
    "@hono/node-server": "^1.14.0",
    "@hono/zod-validator": "^0.5.0",
    "zod": "^3.24.3"
  },
  "devDependencies": {
    "@repo/tsconfig": "workspace:*",
    "@types/node": "^22.14.0",
    "tsx": "^4.19.0",
    "typescript": "^5.8.3"
  }
}
EOF

write_file_heredoc "apps/api/tsconfig.json" << 'EOF'
{
  "extends": "@repo/tsconfig/node.json",
  "compilerOptions": {
    "rootDir": "src",
    "outDir": "dist"
  },
  "include": ["src"]
}
EOF

write_file_heredoc "apps/api/src/index.ts" << 'EOF'
import { serve } from "@hono/node-server";
import { app } from "./app.js";

const port = Number(process.env.PORT) || 4000;

console.log(`API server running on http://localhost:${port}`);

serve({ fetch: app.fetch, port });
EOF

write_file_heredoc "apps/api/src/app.ts" << 'EOF'
import { Hono } from "hono";
import { cors } from "hono/cors";
import { logger } from "hono/logger";
import { usersRoute } from "./routes/users.js";

export const app = new Hono()
  .use("*", logger())
  .use("*", cors())
  .get("/health", (c) => c.json({ status: "ok", timestamp: new Date().toISOString() }))
  .route("/api/users", usersRoute);

export type AppType = typeof app;
EOF

write_file_heredoc "apps/api/src/routes/users.ts" << 'EOF'
import { Hono } from "hono";
import { zValidator } from "@hono/zod-validator";
import { z } from "zod";
import { db, schema } from "@repo/database";
import { eq } from "drizzle-orm";

const createUserSchema = z.object({
  email: z.string().email(),
  name: z.string().optional(),
});

export const usersRoute = new Hono()
  .get("/", async (c) => {
    const users = await db.select().from(schema.users);
    return c.json({ data: users });
  })
  .get("/:id", async (c) => {
    const id = c.req.param("id");
    const [user] = await db.select().from(schema.users).where(eq(schema.users.id, id));
    if (!user) return c.json({ error: "User not found" }, 404);
    return c.json({ data: user });
  })
  .post("/", zValidator("json", createUserSchema), async (c) => {
    const data = c.req.valid("json");
    const [user] = await db.insert(schema.users).values(data).returning();
    return c.json({ data: user }, 201);
  })
  .delete("/:id", async (c) => {
    const id = c.req.param("id");
    await db.delete(schema.users).where(eq(schema.users.id, id));
    return c.body(null, 204);
  });
EOF
success "Created apps/api"

# ── Finalize ──────────────────────────────────────────────────
section "Finalizing"
init_git
write_gitignore ".env" "drizzle/"
write_editorconfig
write_nvmrc

write_readme "$PROJECT_NAME" \
  "Turborepo monorepo with Next.js 15, Hono 4, Drizzle ORM, and Tailwind CSS 4." \
  "pnpm install" \
  "pnpm dev"

finish "pnpm install" "docker compose up -d && pnpm dev"
