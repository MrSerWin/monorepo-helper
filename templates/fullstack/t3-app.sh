#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-t3-app" "$@"
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
    "db:push": "prisma db push",
    "db:generate": "prisma generate",
    "db:studio": "prisma studio",
    "db:migrate": "prisma migrate dev"
  },
  "dependencies": {
    "@auth/core": "^0.37.4",
    "@auth/prisma-adapter": "^2.9.1",
    "@prisma/client": "^6.5.0",
    "@trpc/client": "^11.1.0",
    "@trpc/next": "^11.1.0",
    "@trpc/react-query": "^11.1.0",
    "@trpc/server": "^11.1.0",
    "@tanstack/react-query": "^5.72.2",
    "next": "^15.3.0",
    "next-auth": "^5.0.0-beta.28",
    "react": "^19.1.0",
    "react-dom": "^19.1.0",
    "superjson": "^2.2.2",
    "zod": "^3.24.3"
  },
  "devDependencies": {
    "@eslint/eslintrc": "^3.3.1",
    "@tailwindcss/postcss": "^4.1.3",
    "@types/node": "^22.14.0",
    "@types/react": "^19.1.0",
    "@types/react-dom": "^19.1.0",
    "eslint": "^9.24.0",
    "eslint-config-next": "^15.3.0",
    "prisma": "^6.5.0",
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
DATABASE_URL="postgresql://postgres:password@localhost:5432/'"$PROJECT_NAME"'?schema=public"

# NextAuth
AUTH_SECRET="your-secret-here"
AUTH_URL="http://localhost:3000"

# GitHub OAuth (optional)
AUTH_GITHUB_ID=""
AUTH_GITHUB_SECRET=""'

# --- prisma/schema.prisma ---
write_file_heredoc "prisma/schema.prisma" << 'PRISMA'
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model Account {
  id                       String  @id @default(cuid())
  userId                   String
  type                     String
  provider                 String
  providerAccountId        String
  refresh_token            String? @db.Text
  access_token             String? @db.Text
  expires_at               Int?
  token_type               String?
  scope                    String?
  id_token                 String? @db.Text
  session_state            String?
  user                     User    @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@unique([provider, providerAccountId])
}

model Session {
  id           String   @id @default(cuid())
  sessionToken String   @unique
  userId       String
  expires      DateTime
  user         User     @relation(fields: [userId], references: [id], onDelete: Cascade)
}

model User {
  id            String    @id @default(cuid())
  name          String?
  email         String?   @unique
  emailVerified DateTime?
  image         String?
  accounts      Account[]
  sessions      Session[]
}

model VerificationToken {
  identifier String
  token      String   @unique
  expires    DateTime

  @@unique([identifier, token])
}
PRISMA

# --- src/server/auth.ts ---
write_file_heredoc "src/server/auth.ts" << 'EOF'
import NextAuth from "next-auth";
import { PrismaAdapter } from "@auth/prisma-adapter";
import GitHub from "next-auth/providers/github";
import { db } from "@/server/db";

export const { handlers, auth, signIn, signOut } = NextAuth({
  adapter: PrismaAdapter(db),
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

# --- src/server/db.ts ---
write_file_heredoc "src/server/db.ts" << 'EOF'
import { PrismaClient } from "@prisma/client";

const globalForPrisma = globalThis as unknown as {
  prisma: PrismaClient | undefined;
};

export const db =
  globalForPrisma.prisma ??
  new PrismaClient({
    log: process.env.NODE_ENV === "development" ? ["query", "error", "warn"] : ["error"],
  });

if (process.env.NODE_ENV !== "production") globalForPrisma.prisma = db;
EOF

# --- src/server/api/root.ts ---
write_file_heredoc "src/server/api/root.ts" << 'EOF'
import { createCallerFactory, createTRPCRouter } from "@/server/api/trpc";
import { exampleRouter } from "@/server/api/routers/example";

export const appRouter = createTRPCRouter({
  example: exampleRouter,
});

export type AppRouter = typeof appRouter;

export const createCaller = createCallerFactory(appRouter);
EOF

# --- src/server/api/trpc.ts ---
write_file_heredoc "src/server/api/trpc.ts" << 'EOF'
import { initTRPC, TRPCError } from "@trpc/server";
import superjson from "superjson";
import { ZodError } from "zod";
import { auth } from "@/server/auth";
import { db } from "@/server/db";

export const createTRPCContext = async (opts: { headers: Headers }) => {
  const session = await auth();
  return {
    db,
    session,
    ...opts,
  };
};

const t = initTRPC.context<typeof createTRPCContext>().create({
  transformer: superjson,
  errorFormatter({ shape, error }) {
    return {
      ...shape,
      data: {
        ...shape.data,
        zodError:
          error.cause instanceof ZodError ? error.cause.flatten() : null,
      },
    };
  },
});

export const createCallerFactory = t.createCallerFactory;
export const createTRPCRouter = t.router;
export const publicProcedure = t.procedure;

export const protectedProcedure = t.procedure.use(({ ctx, next }) => {
  if (!ctx.session || !ctx.session.user) {
    throw new TRPCError({ code: "UNAUTHORIZED" });
  }
  return next({
    ctx: {
      session: { ...ctx.session, user: ctx.session.user },
    },
  });
});
EOF

# --- src/server/api/routers/example.ts ---
write_file_heredoc "src/server/api/routers/example.ts" << 'EOF'
import { z } from "zod";
import { createTRPCRouter, publicProcedure, protectedProcedure } from "@/server/api/trpc";

export const exampleRouter = createTRPCRouter({
  hello: publicProcedure
    .input(z.object({ text: z.string() }))
    .query(({ input }) => {
      return {
        greeting: `Hello ${input.text}`,
      };
    }),

  getSecretMessage: protectedProcedure.query(() => {
    return "you can now see this secret message!";
  }),
});
EOF

# --- src/trpc/server.ts ---
write_file_heredoc "src/trpc/server.ts" << 'EOF'
import "server-only";
import { createHydrationHelpers } from "@trpc/react-query/rsc";
import { headers } from "next/headers";
import { cache } from "react";
import { createCaller, type AppRouter } from "@/server/api/root";
import { createTRPCContext } from "@/server/api/trpc";
import { createQueryClient } from "@/trpc/query-client";

const getQueryClient = cache(createQueryClient);

const caller = createCaller(async () =>
  createTRPCContext({ headers: await headers() })
);

export const { trpc: api, HydrateClient } = createHydrationHelpers<AppRouter>(
  caller,
  getQueryClient
);
EOF

# --- src/trpc/client.ts ---
write_file_heredoc "src/trpc/client.ts" << 'EOF'
"use client";

import { type AppRouter } from "@/server/api/root";
import { createTRPCClient, httpBatchStreamLink, loggerLink } from "@trpc/client";
import { createTRPCReact } from "@trpc/react-query";
import superjson from "superjson";

const getBaseUrl = () => {
  if (typeof window !== "undefined") return window.location.origin;
  if (process.env.VERCEL_URL) return `https://${process.env.VERCEL_URL}`;
  return `http://localhost:${process.env.PORT ?? 3000}`;
};

export const api = createTRPCReact<AppRouter>();

export const trpcClient = createTRPCClient<AppRouter>({
  links: [
    loggerLink({
      enabled: (op) =>
        process.env.NODE_ENV === "development" ||
        (op.direction === "down" && op.result instanceof Error),
    }),
    httpBatchStreamLink({
      transformer: superjson,
      url: `${getBaseUrl()}/api/trpc`,
      headers: () => {
        const heads = new Map<string, string>();
        heads.set("x-trpc-source", "nextjs-react");
        return Object.fromEntries(heads);
      },
    }),
  ],
});
EOF

# --- src/trpc/query-client.ts ---
write_file_heredoc "src/trpc/query-client.ts" << 'EOF'
import { QueryClient, defaultShouldDehydrateQuery } from "@tanstack/react-query";
import superjson from "superjson";

export function createQueryClient() {
  return new QueryClient({
    defaultOptions: {
      queries: {
        staleTime: 30 * 1000,
      },
      dehydrate: {
        serializeData: superjson.serialize,
        shouldDehydrateQuery: (query) =>
          defaultShouldDehydrateQuery(query) ||
          query.state.status === "pending",
      },
      hydrate: {
        deserializeData: superjson.deserialize,
      },
    },
  });
}
EOF

# --- src/trpc/react.tsx ---
write_file_heredoc "src/trpc/react.tsx" << 'EOF'
"use client";

import { QueryClientProvider } from "@tanstack/react-query";
import { httpBatchStreamLink, loggerLink } from "@trpc/client";
import { useState } from "react";
import superjson from "superjson";
import { api } from "@/trpc/client";
import { createQueryClient } from "@/trpc/query-client";

let clientQueryClientSingleton: ReturnType<typeof createQueryClient> | undefined;

function getQueryClient() {
  if (typeof window === "undefined") {
    return createQueryClient();
  }
  return (clientQueryClientSingleton ??= createQueryClient());
}

const getBaseUrl = () => {
  if (typeof window !== "undefined") return window.location.origin;
  if (process.env.VERCEL_URL) return `https://${process.env.VERCEL_URL}`;
  return `http://localhost:${process.env.PORT ?? 3000}`;
};

export function TRPCReactProvider(props: { children: React.ReactNode }) {
  const queryClient = getQueryClient();

  const [trpcClient] = useState(() =>
    api.createClient({
      links: [
        loggerLink({
          enabled: (op) =>
            process.env.NODE_ENV === "development" ||
            (op.direction === "down" && op.result instanceof Error),
        }),
        httpBatchStreamLink({
          transformer: superjson,
          url: `${getBaseUrl()}/api/trpc`,
          headers: () => {
            const heads = new Map<string, string>();
            heads.set("x-trpc-source", "nextjs-react");
            return Object.fromEntries(heads);
          },
        }),
      ],
    })
  );

  return (
    <QueryClientProvider client={queryClient}>
      <api.Provider client={trpcClient} queryClient={queryClient}>
        {props.children}
      </api.Provider>
    </QueryClientProvider>
  );
}
EOF

# --- src/app/api/trpc/[trpc]/route.ts ---
write_file_heredoc "src/app/api/trpc/[trpc]/route.ts" << 'EOF'
import { fetchRequestHandler } from "@trpc/server/adapters/fetch";
import { type NextRequest } from "next/server";
import { appRouter } from "@/server/api/root";
import { createTRPCContext } from "@/server/api/trpc";

const handler = (req: NextRequest) =>
  fetchRequestHandler({
    endpoint: "/api/trpc",
    req,
    router: appRouter,
    createContext: () => createTRPCContext({ headers: req.headers }),
    onError:
      process.env.NODE_ENV === "development"
        ? ({ path, error }) => {
            console.error(
              `tRPC failed on ${path ?? "<no-path>"}: ${error.message}`
            );
          }
        : undefined,
  });

export { handler as GET, handler as POST };
EOF

# --- src/app/api/auth/[...nextauth]/route.ts ---
write_file_heredoc "src/app/api/auth/[...nextauth]/route.ts" << 'EOF'
import { handlers } from "@/server/auth";

export const { GET, POST } = handlers;
EOF

# --- src/app/layout.tsx ---
write_file_heredoc "src/app/layout.tsx" << 'EOF'
import type { Metadata } from "next";
import { TRPCReactProvider } from "@/trpc/react";
import "./globals.css";

export const metadata: Metadata = {
  title: "T3 App",
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
        <TRPCReactProvider>{children}</TRPCReactProvider>
      </body>
    </html>
  );
}
EOF

# --- src/app/globals.css ---
write_file "src/app/globals.css" '@import "tailwindcss";'

# --- src/app/page.tsx ---
write_file_heredoc "src/app/page.tsx" << 'EOF'
import { api, HydrateClient } from "@/trpc/server";

export default async function Home() {
  const hello = await api.example.hello({ text: "from tRPC" });

  return (
    <HydrateClient>
      <div className="grid min-h-screen items-center justify-items-center p-8 sm:p-20">
        <main className="flex flex-col items-center gap-8">
          <h1 className="text-4xl font-bold tracking-tight sm:text-6xl">
            T3 <span className="text-violet-600">App</span>
          </h1>
          <p className="text-lg text-gray-600 max-w-md text-center">
            Next.js + tRPC + Prisma + NextAuth + Tailwind CSS
          </p>
          <div className="rounded-lg border border-gray-200 bg-gray-50 px-6 py-4">
            <p className="text-sm text-gray-600">tRPC says:</p>
            <p className="text-lg font-semibold">{hello.greeting}</p>
          </div>
          <div className="flex gap-4">
            <a
              href="/api/auth/signin"
              className="rounded-full bg-violet-600 text-white px-6 py-3 text-sm font-medium hover:bg-violet-700 transition-colors"
            >
              Sign In
            </a>
            <a
              href="https://create.t3.gg/en/introduction"
              target="_blank"
              rel="noopener noreferrer"
              className="rounded-full border border-gray-300 px-6 py-3 text-sm font-medium hover:bg-gray-50 transition-colors"
            >
              T3 Docs
            </a>
          </div>
        </main>
      </div>
    </HydrateClient>
  );
}
EOF

# --- next-env.d.ts ---
write_file "next-env.d.ts" '/// <reference types="next" />
/// <reference types="next/image-types/global" />

// NOTE: This file should not be edited
// see https://nextjs.org/docs/app/api-reference/config/typescript for more information.'

# --- public/ ---
mkdir -p public

init_git
write_gitignore "prisma/*.db" "prisma/*.db-journal"
write_editorconfig
write_nvmrc

finish "npm install" "npm run dev"
