#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-next-drizzle" "$@"
create_project_dir

# --- package.json ---
write_package_json '{
  "name": "'"$PROJECT_NAME"'",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "next dev --turbopack",
    "build": "next build",
    "start": "next start",
    "lint": "next lint",
    "db:generate": "drizzle-kit generate",
    "db:migrate": "drizzle-kit migrate",
    "db:push": "drizzle-kit push",
    "db:studio": "drizzle-kit studio"
  },
  "dependencies": {
    "@auth/core": "^0.37.4",
    "@auth/drizzle-adapter": "^1.7.6",
    "drizzle-orm": "^0.40.1",
    "next": "^15.3.0",
    "next-auth": "^5.0.0-beta.28",
    "postgres": "^3.4.5",
    "react": "^19.1.0",
    "react-dom": "^19.1.0",
    "zod": "^3.24.3"
  },
  "devDependencies": {
    "@eslint/eslintrc": "^3.3.1",
    "@tailwindcss/postcss": "^4.1.3",
    "@types/node": "^22.14.0",
    "@types/react": "^19.1.0",
    "@types/react-dom": "^19.1.0",
    "drizzle-kit": "^0.30.5",
    "eslint": "^9.24.0",
    "eslint-config-next": "^15.3.0",
    "tailwindcss": "^4.1.3",
    "typescript": "^5.8.3"
  }
}'

# --- next.config.ts ---
write_file "next.config.ts" 'import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  /* config options here */
};

export default nextConfig;'

# --- tsconfig.json ---
write_tsconfig '{
  "compilerOptions": {
    "target": "ES2017",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [
      { "name": "next" }
    ],
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}'

# --- postcss.config.mjs ---
write_file "postcss.config.mjs" 'const config = {
  plugins: {
    "@tailwindcss/postcss": {},
  },
};

export default config;'

# --- eslint.config.mjs ---
write_file "eslint.config.mjs" 'import { dirname } from "path";
import { fileURLToPath } from "url";
import { FlatCompat } from "@eslint/eslintrc";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const compat = new FlatCompat({
  baseDirectory: __dirname,
});

const eslintConfig = [
  ...compat.extends("next/core-web-vitals", "next/typescript"),
];

export default eslintConfig;'

# --- .env.example ---
write_file ".env.example" '# Database
DATABASE_URL="postgresql://postgres:password@localhost:5432/'"$PROJECT_NAME"'"

# NextAuth
AUTH_SECRET="your-secret-here"
AUTH_URL="http://localhost:3000"

# GitHub OAuth (optional)
AUTH_GITHUB_ID=""
AUTH_GITHUB_SECRET=""'

# --- drizzle.config.ts ---
write_file_heredoc "drizzle.config.ts" << 'EOF'
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

# --- docker-compose.yml ---
write_file_heredoc "docker-compose.yml" << DCOMPOSE
services:
  db:
    image: postgres:17-alpine
    restart: unless-stopped
    ports:
      - "5432:5432"
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: password
      POSTGRES_DB: ${PROJECT_NAME}
    volumes:
      - pgdata:/var/lib/postgresql/data

volumes:
  pgdata:
DCOMPOSE

# --- src/db/index.ts ---
write_file_heredoc "src/db/index.ts" << 'EOF'
import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import * as schema from "./schema";

const globalForDb = globalThis as unknown as {
  conn: postgres.Sql | undefined;
};

const conn = globalForDb.conn ?? postgres(process.env.DATABASE_URL!);
if (process.env.NODE_ENV !== "production") globalForDb.conn = conn;

export const db = drizzle(conn, { schema });
EOF

# --- src/db/schema.ts ---
write_file_heredoc "src/db/schema.ts" << 'EOF'
import {
  pgTable,
  text,
  timestamp,
  integer,
  primaryKey,
  serial,
} from "drizzle-orm/pg-core";
import type { AdapterAccountType } from "next-auth/adapters";

export const users = pgTable("user", {
  id: text("id")
    .primaryKey()
    .$defaultFn(() => crypto.randomUUID()),
  name: text("name"),
  email: text("email").unique(),
  emailVerified: timestamp("emailVerified", { mode: "date" }),
  image: text("image"),
});

export const accounts = pgTable(
  "account",
  {
    userId: text("userId")
      .notNull()
      .references(() => users.id, { onDelete: "cascade" }),
    type: text("type").$type<AdapterAccountType>().notNull(),
    provider: text("provider").notNull(),
    providerAccountId: text("providerAccountId").notNull(),
    refresh_token: text("refresh_token"),
    access_token: text("access_token"),
    expires_at: integer("expires_at"),
    token_type: text("token_type"),
    scope: text("scope"),
    id_token: text("id_token"),
    session_state: text("session_state"),
  },
  (account) => [
    primaryKey({ columns: [account.provider, account.providerAccountId] }),
  ]
);

export const sessions = pgTable("session", {
  sessionToken: text("sessionToken").primaryKey(),
  userId: text("userId")
    .notNull()
    .references(() => users.id, { onDelete: "cascade" }),
  expires: timestamp("expires", { mode: "date" }).notNull(),
});

export const verificationTokens = pgTable(
  "verificationToken",
  {
    identifier: text("identifier").notNull(),
    token: text("token").notNull(),
    expires: timestamp("expires", { mode: "date" }).notNull(),
  },
  (vt) => [primaryKey({ columns: [vt.identifier, vt.token] })]
);

// --- App-specific tables ---

export const posts = pgTable("post", {
  id: serial("id").primaryKey(),
  title: text("title").notNull(),
  content: text("content"),
  authorId: text("authorId")
    .notNull()
    .references(() => users.id, { onDelete: "cascade" }),
  createdAt: timestamp("createdAt", { mode: "date" }).defaultNow().notNull(),
  updatedAt: timestamp("updatedAt", { mode: "date" }).defaultNow().notNull(),
});
EOF

# --- src/server/auth.ts ---
write_file_heredoc "src/server/auth.ts" << 'EOF'
import NextAuth from "next-auth";
import GitHub from "next-auth/providers/github";
import { DrizzleAdapter } from "@auth/drizzle-adapter";
import { db } from "@/db";

export const { handlers, auth, signIn, signOut } = NextAuth({
  adapter: DrizzleAdapter(db),
  providers: [
    GitHub,
  ],
  callbacks: {
    session: ({ session, user }) => ({
      ...session,
      user: {
        ...session.user,
        id: user.id,
      },
    }),
  },
});
EOF

# --- src/app/api/auth/[...nextauth]/route.ts ---
write_file_heredoc "src/app/api/auth/[...nextauth]/route.ts" << 'EOF'
import { handlers } from "@/server/auth";

export const { GET, POST } = handlers;
EOF

# --- src/app/actions.ts ---
write_file_heredoc "src/app/actions.ts" << 'EOF'
"use server";

import { db } from "@/db";
import { posts } from "@/db/schema";
import { auth } from "@/server/auth";
import { eq } from "drizzle-orm";
import { revalidatePath } from "next/cache";
import { z } from "zod";

const createPostSchema = z.object({
  title: z.string().min(1, "Title is required"),
  content: z.string().optional(),
});

export async function createPost(formData: FormData) {
  const session = await auth();
  if (!session?.user?.id) throw new Error("Unauthorized");

  const parsed = createPostSchema.parse({
    title: formData.get("title"),
    content: formData.get("content"),
  });

  await db.insert(posts).values({
    title: parsed.title,
    content: parsed.content ?? null,
    authorId: session.user.id,
  });

  revalidatePath("/dashboard");
}

export async function deletePost(postId: number) {
  const session = await auth();
  if (!session?.user?.id) throw new Error("Unauthorized");

  await db.delete(posts).where(eq(posts.id, postId));
  revalidatePath("/dashboard");
}

export async function getPosts() {
  return db.select().from(posts).orderBy(posts.createdAt);
}
EOF

# --- src/app/layout.tsx ---
write_file_heredoc "src/app/layout.tsx" << 'EOF'
import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Next.js + Drizzle",
  description: "Created with monorepo-helper",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className="antialiased">
        {children}
      </body>
    </html>
  );
}
EOF

# --- src/app/globals.css ---
write_file "src/app/globals.css" '@import "tailwindcss";'

# --- src/app/page.tsx ---
write_file_heredoc "src/app/page.tsx" << 'EOF'
import { auth } from "@/server/auth";
import Link from "next/link";

export default async function Home() {
  const session = await auth();

  return (
    <div className="grid min-h-screen items-center justify-items-center p-8 sm:p-20">
      <main className="flex flex-col items-center gap-8">
        <h1 className="text-4xl font-bold tracking-tight sm:text-6xl">
          Next.js + <span className="text-orange-600">Drizzle</span>
        </h1>
        <p className="text-lg text-gray-600 max-w-md text-center">
          Full-stack app with Drizzle ORM, NextAuth, and PostgreSQL
        </p>
        {session?.user ? (
          <div className="flex flex-col items-center gap-4">
            <p className="text-sm text-gray-600">Signed in as {session.user.email}</p>
            <Link
              href="/dashboard"
              className="rounded-full bg-orange-600 text-white px-6 py-3 text-sm font-medium hover:bg-orange-700 transition-colors"
            >
              Dashboard
            </Link>
          </div>
        ) : (
          <a
            href="/api/auth/signin"
            className="rounded-full bg-orange-600 text-white px-6 py-3 text-sm font-medium hover:bg-orange-700 transition-colors"
          >
            Sign In
          </a>
        )}
      </main>
    </div>
  );
}
EOF

# --- src/app/dashboard/page.tsx ---
write_file_heredoc "src/app/dashboard/page.tsx" << 'EOF'
import { auth } from "@/server/auth";
import { redirect } from "next/navigation";
import { getPosts, createPost, deletePost } from "@/app/actions";

export default async function DashboardPage() {
  const session = await auth();
  if (!session?.user) redirect("/api/auth/signin");

  const allPosts = await getPosts();

  return (
    <div className="min-h-screen p-8 max-w-2xl mx-auto">
      <div className="flex items-center justify-between mb-8">
        <h1 className="text-2xl font-bold">Dashboard</h1>
        <p className="text-sm text-gray-500">{session.user.email}</p>
      </div>

      <form action={createPost} className="mb-8 flex flex-col gap-3">
        <input
          name="title"
          placeholder="Post title"
          required
          className="rounded-lg border border-gray-300 px-4 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-orange-500"
        />
        <textarea
          name="content"
          placeholder="Content (optional)"
          rows={3}
          className="rounded-lg border border-gray-300 px-4 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-orange-500"
        />
        <button
          type="submit"
          className="self-start rounded-lg bg-orange-600 text-white px-4 py-2 text-sm font-medium hover:bg-orange-700 transition-colors"
        >
          Create Post
        </button>
      </form>

      <div className="flex flex-col gap-4">
        {allPosts.length === 0 ? (
          <p className="text-gray-500 text-sm">No posts yet. Create one above!</p>
        ) : (
          allPosts.map((post) => (
            <div
              key={post.id}
              className="rounded-lg border border-gray-200 p-4 flex items-start justify-between"
            >
              <div>
                <h3 className="font-semibold">{post.title}</h3>
                {post.content && (
                  <p className="text-sm text-gray-600 mt-1">{post.content}</p>
                )}
                <p className="text-xs text-gray-400 mt-2">
                  {post.createdAt.toLocaleDateString()}
                </p>
              </div>
              <form action={deletePost.bind(null, post.id)}>
                <button
                  type="submit"
                  className="text-red-500 hover:text-red-700 text-sm"
                >
                  Delete
                </button>
              </form>
            </div>
          ))
        )}
      </div>
    </div>
  );
}
EOF

# --- next-env.d.ts ---
write_file "next-env.d.ts" '/// <reference types="next" />
/// <reference types="next/image-types/global" />

// NOTE: This file should not be edited
// see https://nextjs.org/docs/app/api-reference/config/typescript for more information.'

# --- drizzle/ ---
mkdir -p drizzle
mkdir -p public

init_git
write_gitignore
write_editorconfig
write_nvmrc

finish "npm install" "npm run dev"
