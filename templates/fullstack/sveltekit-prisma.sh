#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-sveltekit-app" "$@"
create_project_dir

# --- package.json ---
write_package_json '{
  "name": "'"$PROJECT_NAME"'",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite dev",
    "build": "vite build",
    "preview": "vite preview",
    "check": "svelte-kit sync && svelte-check --tsconfig ./tsconfig.json",
    "check:watch": "svelte-kit sync && svelte-check --tsconfig ./tsconfig.json --watch",
    "db:push": "prisma db push",
    "db:generate": "prisma generate",
    "db:studio": "prisma studio",
    "db:migrate": "prisma migrate dev"
  },
  "dependencies": {
    "@prisma/client": "^6.5.0",
    "arctic": "^3.5.0",
    "oslo": "^1.2.1"
  },
  "devDependencies": {
    "@sveltejs/adapter-auto": "^4.0.0",
    "@sveltejs/kit": "^2.16.0",
    "@sveltejs/vite-plugin-svelte": "^5.0.3",
    "@tailwindcss/vite": "^4.1.3",
    "prisma": "^6.5.0",
    "svelte": "^5.25.0",
    "svelte-check": "^4.1.5",
    "tailwindcss": "^4.1.3",
    "typescript": "^5.8.3",
    "vite": "^6.2.4"
  }
}'

# --- svelte.config.js ---
write_file_heredoc "svelte.config.js" << 'EOF'
import adapter from "@sveltejs/adapter-auto";
import { vitePreprocess } from "@sveltejs/vite-plugin-svelte";

/** @type {import('@sveltejs/kit').Config} */
const config = {
  preprocess: vitePreprocess(),
  kit: {
    adapter: adapter(),
    alias: {
      $lib: "./src/lib",
    },
  },
};

export default config;
EOF

# --- vite.config.ts ---
write_file_heredoc "vite.config.ts" << 'EOF'
import { sveltekit } from "@sveltejs/kit/vite";
import tailwindcss from "@tailwindcss/vite";
import { defineConfig } from "vite";

export default defineConfig({
  plugins: [tailwindcss(), sveltekit()],
});
EOF

# --- tsconfig.json ---
write_tsconfig '{
  "extends": "./.svelte-kit/tsconfig.json",
  "compilerOptions": {
    "allowJs": true,
    "checkJs": true,
    "esModuleInterop": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "skipLibCheck": true,
    "sourceMap": true,
    "strict": true,
    "moduleResolution": "bundler"
  }
}'

# --- .env.example ---
write_file ".env.example" '# Database
DATABASE_URL="postgresql://postgres:password@localhost:5432/'"$PROJECT_NAME"'?schema=public"

# Auth (GitHub OAuth)
GITHUB_CLIENT_ID=""
GITHUB_CLIENT_SECRET=""'

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

# --- prisma/schema.prisma ---
write_file_heredoc "prisma/schema.prisma" << 'PRISMA'
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id             String    @id @default(cuid())
  email          String    @unique
  name           String?
  githubId       Int?      @unique
  avatarUrl      String?
  sessions       Session[]
  createdAt      DateTime  @default(now())
  updatedAt      DateTime  @updatedAt
}

model Session {
  id        String   @id @default(cuid())
  userId    String
  expiresAt DateTime
  user      User     @relation(fields: [userId], references: [id], onDelete: Cascade)
}
PRISMA

# --- src/lib/server/db.ts ---
write_file_heredoc "src/lib/server/db.ts" << 'EOF'
import { PrismaClient } from "@prisma/client";

const globalForPrisma = globalThis as unknown as {
  prisma: PrismaClient | undefined;
};

export const db =
  globalForPrisma.prisma ??
  new PrismaClient({
    log: import.meta.env.DEV ? ["query", "error", "warn"] : ["error"],
  });

if (import.meta.env.DEV) globalForPrisma.prisma = db;
EOF

# --- src/lib/server/auth.ts ---
write_file_heredoc "src/lib/server/auth.ts" << 'EOF'
import { GitHub } from "arctic";
import { db } from "$lib/server/db";
import type { RequestEvent } from "@sveltejs/kit";

export const github = new GitHub(
  process.env.GITHUB_CLIENT_ID!,
  process.env.GITHUB_CLIENT_SECRET!,
  null
);

export type SessionUser = {
  id: string;
  email: string;
  name: string | null;
  avatarUrl: string | null;
};

export async function createSession(userId: string): Promise<string> {
  const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000); // 30 days
  const session = await db.session.create({
    data: {
      userId,
      expiresAt,
    },
  });
  return session.id;
}

export async function validateSession(sessionId: string) {
  const session = await db.session.findUnique({
    where: { id: sessionId },
    include: { user: true },
  });

  if (!session) return { session: null, user: null };

  if (session.expiresAt < new Date()) {
    await db.session.delete({ where: { id: sessionId } });
    return { session: null, user: null };
  }

  // Extend session if it expires in less than 15 days
  if (session.expiresAt.getTime() - Date.now() < 15 * 24 * 60 * 60 * 1000) {
    await db.session.update({
      where: { id: sessionId },
      data: { expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000) },
    });
  }

  const user: SessionUser = {
    id: session.user.id,
    email: session.user.email,
    name: session.user.name,
    avatarUrl: session.user.avatarUrl,
  };

  return { session, user };
}

export async function invalidateSession(sessionId: string) {
  await db.session.delete({ where: { id: sessionId } });
}

export function setSessionCookie(event: RequestEvent, sessionId: string) {
  event.cookies.set("session", sessionId, {
    httpOnly: true,
    sameSite: "lax",
    expires: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
    path: "/",
    secure: !import.meta.env.DEV,
  });
}

export function deleteSessionCookie(event: RequestEvent) {
  event.cookies.set("session", "", {
    httpOnly: true,
    sameSite: "lax",
    maxAge: 0,
    path: "/",
    secure: !import.meta.env.DEV,
  });
}
EOF

# --- src/app.css ---
write_file "src/app.css" '@import "tailwindcss";'

# --- src/app.d.ts ---
write_file_heredoc "src/app.d.ts" << 'EOF'
declare global {
  namespace App {
    interface Locals {
      user: import("$lib/server/auth").SessionUser | null;
      sessionId: string | null;
    }
  }
}

export {};
EOF

# --- src/app.html ---
write_file_heredoc "src/app.html" << 'EOF'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <link rel="icon" href="%sveltekit.assets%/favicon.png" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    %sveltekit.head%
  </head>
  <body data-sveltekit-preload-data="hover">
    <div style="display: contents">%sveltekit.body%</div>
  </body>
</html>
EOF

# --- src/hooks.server.ts ---
write_file_heredoc "src/hooks.server.ts" << 'EOF'
import { validateSession } from "$lib/server/auth";
import type { Handle } from "@sveltejs/kit";

export const handle: Handle = async ({ event, resolve }) => {
  const sessionId = event.cookies.get("session");

  if (sessionId) {
    const { user } = await validateSession(sessionId);
    event.locals.user = user;
    event.locals.sessionId = sessionId;
  } else {
    event.locals.user = null;
    event.locals.sessionId = null;
  }

  return resolve(event);
};
EOF

# --- src/routes/+layout.svelte ---
write_file_heredoc "src/routes/+layout.svelte" << 'EOF'
<script lang="ts">
  import "../app.css";
  let { children } = $props();
</script>

{@render children()}
EOF

# --- src/routes/+layout.server.ts ---
write_file_heredoc "src/routes/+layout.server.ts" << 'EOF'
import type { LayoutServerLoad } from "./$types";

export const load: LayoutServerLoad = async ({ locals }) => {
  return {
    user: locals.user,
  };
};
EOF

# --- src/routes/+page.svelte ---
write_file_heredoc "src/routes/+page.svelte" << 'EOF'
<script lang="ts">
  import type { PageData } from "./$types";
  let { data }: { data: PageData } = $props();
</script>

<div class="grid min-h-screen items-center justify-items-center p-8 sm:p-20">
  <main class="flex flex-col items-center gap-8">
    <h1 class="text-4xl font-bold tracking-tight sm:text-6xl">
      SvelteKit + <span class="text-indigo-600">Prisma</span>
    </h1>
    <p class="text-lg text-gray-600 max-w-md text-center">
      Full-stack app with Prisma, Lucia-style auth, and PostgreSQL
    </p>
    {#if data.user}
      <div class="flex flex-col items-center gap-4">
        <p class="text-sm text-gray-600">Signed in as {data.user.email}</p>
        <a
          href="/dashboard"
          class="rounded-full bg-indigo-600 text-white px-6 py-3 text-sm font-medium hover:bg-indigo-700 transition-colors"
        >
          Dashboard
        </a>
        <form method="POST" action="/auth/logout">
          <button
            type="submit"
            class="rounded-full border border-gray-300 px-6 py-3 text-sm font-medium hover:bg-gray-50 transition-colors"
          >
            Sign Out
          </button>
        </form>
      </div>
    {:else}
      <a
        href="/auth/login/github"
        class="rounded-full bg-indigo-600 text-white px-6 py-3 text-sm font-medium hover:bg-indigo-700 transition-colors"
      >
        Sign In with GitHub
      </a>
    {/if}
  </main>
</div>
EOF

# --- src/routes/auth/login/github/+server.ts ---
write_file_heredoc "src/routes/auth/login/github/+server.ts" << 'EOF'
import { redirect } from "@sveltejs/kit";
import { generateState } from "arctic";
import { github } from "$lib/server/auth";
import type { RequestEvent } from "@sveltejs/kit";

export async function GET(event: RequestEvent) {
  const state = generateState();
  const url = github.createAuthorizationURL(state, ["user:email"]);

  event.cookies.set("github_oauth_state", state, {
    httpOnly: true,
    sameSite: "lax",
    path: "/",
    maxAge: 60 * 10,
    secure: !import.meta.env.DEV,
  });

  redirect(302, url.toString());
}
EOF

# --- src/routes/auth/login/github/callback/+server.ts ---
write_file_heredoc "src/routes/auth/login/github/callback/+server.ts" << 'EOF'
import { redirect } from "@sveltejs/kit";
import { github, createSession, setSessionCookie } from "$lib/server/auth";
import { db } from "$lib/server/db";
import type { RequestEvent } from "@sveltejs/kit";

interface GitHubUser {
  id: number;
  login: string;
  email: string | null;
  avatar_url: string;
}

interface GitHubEmail {
  email: string;
  primary: boolean;
  verified: boolean;
}

export async function GET(event: RequestEvent) {
  const code = event.url.searchParams.get("code");
  const state = event.url.searchParams.get("state");
  const storedState = event.cookies.get("github_oauth_state");

  if (!code || !state || !storedState || state !== storedState) {
    redirect(302, "/auth/error");
  }

  const tokens = await github.validateAuthorizationCode(code);
  const accessToken = tokens.accessToken();

  const githubUserRes = await fetch("https://api.github.com/user", {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  const githubUser: GitHubUser = await githubUserRes.json();

  let email = githubUser.email;
  if (!email) {
    const emailsRes = await fetch("https://api.github.com/user/emails", {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    const emails: GitHubEmail[] = await emailsRes.json();
    const primary = emails.find((e) => e.primary && e.verified);
    email = primary?.email ?? emails[0]?.email ?? null;
  }

  if (!email) redirect(302, "/auth/error");

  let user = await db.user.findUnique({ where: { githubId: githubUser.id } });

  if (!user) {
    user = await db.user.create({
      data: {
        email: email!,
        name: githubUser.login,
        githubId: githubUser.id,
        avatarUrl: githubUser.avatar_url,
      },
    });
  }

  const sessionId = await createSession(user.id);
  setSessionCookie(event, sessionId);

  redirect(302, "/");
}
EOF

# --- src/routes/auth/logout/+server.ts ---
write_file_heredoc "src/routes/auth/logout/+server.ts" << 'EOF'
import { redirect } from "@sveltejs/kit";
import { invalidateSession, deleteSessionCookie } from "$lib/server/auth";
import type { RequestEvent } from "@sveltejs/kit";

export async function POST(event: RequestEvent) {
  if (event.locals.sessionId) {
    await invalidateSession(event.locals.sessionId);
  }
  deleteSessionCookie(event);
  redirect(302, "/");
}
EOF

# --- src/routes/auth/error/+page.svelte ---
write_file_heredoc "src/routes/auth/error/+page.svelte" << 'EOF'
<div class="grid min-h-screen items-center justify-items-center p-8">
  <div class="text-center">
    <h1 class="text-2xl font-bold mb-4">Authentication Error</h1>
    <p class="text-gray-600 mb-6">Something went wrong during authentication.</p>
    <a href="/" class="text-indigo-600 hover:underline text-sm">Back to Home</a>
  </div>
</div>
EOF

# --- src/routes/dashboard/+page.server.ts ---
write_file_heredoc "src/routes/dashboard/+page.server.ts" << 'EOF'
import { redirect } from "@sveltejs/kit";
import type { PageServerLoad } from "./$types";

export const load: PageServerLoad = async ({ locals }) => {
  if (!locals.user) redirect(302, "/");
  return { user: locals.user };
};
EOF

# --- src/routes/dashboard/+page.svelte ---
write_file_heredoc "src/routes/dashboard/+page.svelte" << 'EOF'
<script lang="ts">
  import type { PageData } from "./$types";
  let { data }: { data: PageData } = $props();
</script>

<div class="min-h-screen p-8 max-w-2xl mx-auto">
  <div class="flex items-center justify-between mb-8">
    <h1 class="text-2xl font-bold">Dashboard</h1>
    <div class="flex items-center gap-3">
      {#if data.user?.avatarUrl}
        <img src={data.user.avatarUrl} alt="Avatar" class="w-8 h-8 rounded-full" />
      {/if}
      <span class="text-sm text-gray-500">{data.user?.email}</span>
    </div>
  </div>
  <div class="rounded-lg border border-gray-200 p-6">
    <h2 class="font-semibold mb-2">Welcome, {data.user?.name ?? "User"}!</h2>
    <p class="text-sm text-gray-600">This is a protected page. Only authenticated users can see this.</p>
  </div>
</div>
EOF

# --- static/ ---
mkdir -p static

init_git
write_gitignore "prisma/*.db" "prisma/*.db-journal"
write_editorconfig
write_nvmrc

finish "npm install" "npm run dev"
