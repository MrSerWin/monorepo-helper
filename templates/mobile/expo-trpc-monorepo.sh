#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-expo-monorepo" "$@"
create_project_dir

# =====================================================
# ROOT
# =====================================================

# --- root package.json ---
write_package_json '{
  "name": "'"$PROJECT_NAME"'",
  "version": "0.0.0",
  "private": true,
  "workspaces": [
    "apps/*",
    "packages/*"
  ],
  "scripts": {
    "dev": "turbo dev",
    "build": "turbo build",
    "lint": "turbo lint",
    "typecheck": "turbo typecheck",
    "db:push": "turbo db:push",
    "db:generate": "turbo db:generate"
  },
  "devDependencies": {
    "turbo": "^2.3.0",
    "typescript": "~5.7.0"
  },
  "packageManager": "npm@10.9.0"
}'

# --- turbo.json ---
write_file_heredoc "turbo.json" << 'EOF'
{
  "$schema": "https://turbo.build/schema.json",
  "globalDependencies": ["**/.env.*local"],
  "tasks": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": [".next/**", "!.next/cache/**", "dist/**"]
    },
    "dev": {
      "cache": false,
      "persistent": true
    },
    "lint": {
      "dependsOn": ["^build"]
    },
    "typecheck": {
      "dependsOn": ["^build"]
    },
    "db:push": {
      "cache": false
    },
    "db:generate": {
      "cache": false
    }
  }
}
EOF

# --- root tsconfig.json ---
write_file "tsconfig.json" '{
  "compilerOptions": {
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "moduleResolution": "bundler",
    "module": "ESNext",
    "target": "ES2022",
    "lib": ["ES2022"],
    "resolveJsonModule": true,
    "isolatedModules": true,
    "incremental": true
  },
  "exclude": ["node_modules"]
}'

# =====================================================
# packages/api - tRPC Router + Prisma
# =====================================================

write_file_heredoc "packages/api/package.json" << 'EOF'
{
  "name": "@repo/api",
  "version": "0.0.0",
  "private": true,
  "type": "module",
  "exports": {
    ".": "./src/root.ts",
    "./client": "./src/client.ts",
    "./server": "./src/server.ts"
  },
  "scripts": {
    "typecheck": "tsc --noEmit",
    "db:push": "prisma db push",
    "db:generate": "prisma generate",
    "db:studio": "prisma studio"
  },
  "dependencies": {
    "@prisma/client": "^6.2.0",
    "@trpc/server": "^11.0.0",
    "superjson": "^2.2.1",
    "zod": "^3.24.0"
  },
  "devDependencies": {
    "prisma": "^6.2.0",
    "typescript": "~5.7.0"
  }
}
EOF

write_file "packages/api/tsconfig.json" '{
  "extends": "../../tsconfig.json",
  "compilerOptions": {
    "outDir": "./dist",
    "rootDir": "./src"
  },
  "include": ["src"]
}'

# --- Prisma schema ---
write_file_heredoc "packages/api/prisma/schema.prisma" << 'EOF'
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "sqlite"
  url      = env("DATABASE_URL")
}

model Post {
  id        Int      @id @default(autoincrement())
  title     String
  content   String
  published Boolean  @default(false)
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}

model User {
  id        Int      @id @default(autoincrement())
  email     String   @unique
  name      String?
  createdAt DateTime @default(now())
}
EOF

write_file "packages/api/.env" 'DATABASE_URL="file:./dev.db"'

# --- tRPC server setup ---
write_file_heredoc "packages/api/src/trpc.ts" << 'EOF'
import { initTRPC } from "@trpc/server";
import superjson from "superjson";

const t = initTRPC.create({
  transformer: superjson,
});

export const router = t.router;
export const publicProcedure = t.procedure;
export const createCallerFactory = t.createCallerFactory;
EOF

# --- Prisma client ---
write_file_heredoc "packages/api/src/db.ts" << 'EOF'
import { PrismaClient } from "@prisma/client";

const globalForPrisma = globalThis as unknown as {
  prisma: PrismaClient | undefined;
};

export const prisma = globalForPrisma.prisma ?? new PrismaClient();

if (process.env.NODE_ENV !== "production") globalForPrisma.prisma = prisma;
EOF

# --- Post router ---
write_file_heredoc "packages/api/src/routers/post.ts" << 'EOF'
import { z } from "zod";
import { router, publicProcedure } from "../trpc";
import { prisma } from "../db";

export const postRouter = router({
  list: publicProcedure.query(async () => {
    return prisma.post.findMany({
      orderBy: { createdAt: "desc" },
    });
  }),

  byId: publicProcedure
    .input(z.object({ id: z.number() }))
    .query(async ({ input }) => {
      return prisma.post.findUniqueOrThrow({
        where: { id: input.id },
      });
    }),

  create: publicProcedure
    .input(
      z.object({
        title: z.string().min(1),
        content: z.string().min(1),
      })
    )
    .mutation(async ({ input }) => {
      return prisma.post.create({ data: input });
    }),

  delete: publicProcedure
    .input(z.object({ id: z.number() }))
    .mutation(async ({ input }) => {
      return prisma.post.delete({ where: { id: input.id } });
    }),
});
EOF

# --- Root router ---
write_file_heredoc "packages/api/src/root.ts" << 'EOF'
import { router, createCallerFactory } from "./trpc";
import { postRouter } from "./routers/post";

export const appRouter = router({
  post: postRouter,
});

export type AppRouter = typeof appRouter;
export const createCaller = createCallerFactory(appRouter);
EOF

# --- Client helper ---
write_file_heredoc "packages/api/src/client.ts" << 'EOF'
export type { AppRouter } from "./root";
export { appRouter, createCaller } from "./root";
EOF

# --- Server helper ---
write_file_heredoc "packages/api/src/server.ts" << 'EOF'
export { appRouter, createCaller } from "./root";
export type { AppRouter } from "./root";
export { prisma } from "./db";
EOF

# =====================================================
# packages/shared - Shared types and utils
# =====================================================

write_file_heredoc "packages/shared/package.json" << 'EOF'
{
  "name": "@repo/shared",
  "version": "0.0.0",
  "private": true,
  "type": "module",
  "exports": {
    ".": "./src/index.ts",
    "./utils": "./src/utils.ts"
  },
  "scripts": {
    "typecheck": "tsc --noEmit"
  },
  "devDependencies": {
    "typescript": "~5.7.0"
  }
}
EOF

write_file "packages/shared/tsconfig.json" '{
  "extends": "../../tsconfig.json",
  "compilerOptions": {
    "outDir": "./dist",
    "rootDir": "./src"
  },
  "include": ["src"]
}'

write_file_heredoc "packages/shared/src/index.ts" << 'EOF'
export * from "./types";
export * from "./utils";
export * from "./constants";
EOF

write_file_heredoc "packages/shared/src/types.ts" << 'EOF'
export interface Post {
  id: number;
  title: string;
  content: string;
  published: boolean;
  createdAt: Date;
  updatedAt: Date;
}

export interface User {
  id: number;
  email: string;
  name: string | null;
  createdAt: Date;
}

export type CreatePostInput = {
  title: string;
  content: string;
};
EOF

write_file_heredoc "packages/shared/src/utils.ts" << 'EOF'
export function formatDate(date: Date): string {
  return new Intl.DateTimeFormat("en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
  }).format(new Date(date));
}

export function truncate(str: string, length: number): string {
  if (str.length <= length) return str;
  return str.slice(0, length) + "...";
}

export function slugify(str: string): string {
  return str
    .toLowerCase()
    .replace(/[^\w\s-]/g, "")
    .replace(/[\s_-]+/g, "-")
    .replace(/^-+|-+$/g, "");
}
EOF

write_file_heredoc "packages/shared/src/constants.ts" << 'EOF'
export const APP_NAME = "Expo tRPC Monorepo";
export const API_VERSION = "v1";
export const MAX_POST_TITLE_LENGTH = 200;
export const MAX_POST_CONTENT_LENGTH = 10000;
export const POSTS_PER_PAGE = 20;
EOF

# =====================================================
# apps/web - Next.js 15
# =====================================================

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
    "lint": "next lint",
    "typecheck": "tsc --noEmit"
  },
  "dependencies": {
    "@repo/api": "workspace:*",
    "@repo/shared": "workspace:*",
    "@tanstack/react-query": "^5.62.0",
    "@trpc/client": "^11.0.0",
    "@trpc/react-query": "^11.0.0",
    "@trpc/server": "^11.0.0",
    "next": "^15.1.0",
    "react": "^19.0.0",
    "react-dom": "^19.0.0",
    "superjson": "^2.2.1"
  },
  "devDependencies": {
    "@types/node": "^22.10.0",
    "@types/react": "^19.0.0",
    "@types/react-dom": "^19.0.0",
    "typescript": "~5.7.0"
  }
}
EOF

write_file "apps/web/tsconfig.json" '{
  "extends": "../../tsconfig.json",
  "compilerOptions": {
    "jsx": "preserve",
    "lib": ["ES2022", "dom", "dom.iterable"],
    "module": "esnext",
    "noEmit": true,
    "incremental": true,
    "plugins": [{ "name": "next" }],
    "paths": {
      "@/*": ["./src/*"],
      "@repo/api": ["../../packages/api/src/root"],
      "@repo/api/*": ["../../packages/api/src/*"],
      "@repo/shared": ["../../packages/shared/src/index"],
      "@repo/shared/*": ["../../packages/shared/src/*"]
    }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}'

write_file_heredoc "apps/web/next.config.ts" << 'EOF'
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  transpilePackages: ["@repo/api", "@repo/shared"],
};

export default nextConfig;
EOF

# --- Next.js tRPC setup ---
write_file_heredoc "apps/web/src/lib/trpc.ts" << 'EOF'
import { createTRPCReact } from "@trpc/react-query";
import type { AppRouter } from "@repo/api";

export const trpc = createTRPCReact<AppRouter>();
EOF

write_file_heredoc "apps/web/src/lib/trpc-server.ts" << 'EOF'
import "server-only";
import { createCaller } from "@repo/api/server";

export const serverApi = createCaller({});
EOF

write_file_heredoc "apps/web/src/lib/providers.tsx" << 'EOF'
"use client";

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { httpBatchLink } from "@trpc/client";
import { useState } from "react";
import superjson from "superjson";
import { trpc } from "./trpc";

function getBaseUrl() {
  if (typeof window !== "undefined") return "";
  return `http://localhost:${process.env.PORT ?? 3000}`;
}

export function TRPCProvider({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(
    () =>
      new QueryClient({
        defaultOptions: { queries: { staleTime: 30 * 1000 } },
      })
  );

  const [trpcClient] = useState(() =>
    trpc.createClient({
      links: [
        httpBatchLink({
          url: `${getBaseUrl()}/api/trpc`,
          transformer: superjson,
        }),
      ],
    })
  );

  return (
    <trpc.Provider client={trpcClient} queryClient={queryClient}>
      <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
    </trpc.Provider>
  );
}
EOF

# --- Next.js tRPC API route ---
write_file_heredoc "apps/web/src/app/api/trpc/[trpc]/route.ts" << 'EOF'
import { fetchRequestHandler } from "@trpc/server/adapters/fetch";
import { appRouter } from "@repo/api/server";

const handler = (req: Request) =>
  fetchRequestHandler({
    endpoint: "/api/trpc",
    req,
    router: appRouter,
    createContext: () => ({}),
  });

export { handler as GET, handler as POST };
EOF

# --- Next.js layout ---
write_file_heredoc "apps/web/src/app/layout.tsx" << 'EOF'
import type { Metadata } from "next";
import { TRPCProvider } from "@/lib/providers";

export const metadata: Metadata = {
  title: "Web App",
  description: "Next.js + tRPC monorepo",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>
        <TRPCProvider>{children}</TRPCProvider>
      </body>
    </html>
  );
}
EOF

# --- Next.js page ---
write_file_heredoc "apps/web/src/app/page.tsx" << 'EOF'
import { serverApi } from "@/lib/trpc-server";
import { formatDate } from "@repo/shared/utils";
import { APP_NAME } from "@repo/shared";

export default async function Home() {
  const posts = await serverApi.post.list();

  return (
    <main style={{ maxWidth: 800, margin: "0 auto", padding: "2rem" }}>
      <h1 style={{ fontSize: "2rem", marginBottom: "1rem" }}>{APP_NAME}</h1>
      <p style={{ color: "#666", marginBottom: "2rem" }}>
        Full-stack monorepo with Next.js, Expo, tRPC, and Prisma.
      </p>

      <h2 style={{ fontSize: "1.5rem", marginBottom: "1rem" }}>Posts</h2>
      {posts.length === 0 ? (
        <p style={{ color: "#999" }}>
          No posts yet. Run `npm run db:push` then add some data.
        </p>
      ) : (
        <ul style={{ listStyle: "none", padding: 0 }}>
          {posts.map((post) => (
            <li
              key={post.id}
              style={{
                border: "1px solid #eee",
                borderRadius: 8,
                padding: "1rem",
                marginBottom: "0.75rem",
              }}
            >
              <h3>{post.title}</h3>
              <p style={{ color: "#666" }}>{post.content}</p>
              <small style={{ color: "#999" }}>
                {formatDate(post.createdAt)}
              </small>
            </li>
          ))}
        </ul>
      )}
    </main>
  );
}
EOF

write_file_heredoc "apps/web/next-env.d.ts" << 'EOF'
/// <reference types="next" />
/// <reference types="next/image-types/global" />

// NOTE: This file should not be edited
EOF

mkdir -p apps/web/public

# =====================================================
# apps/mobile - Expo 52
# =====================================================

write_file_heredoc "apps/mobile/package.json" << 'EOF'
{
  "name": "@repo/mobile",
  "version": "1.0.0",
  "private": true,
  "main": "expo-router/entry",
  "scripts": {
    "dev": "expo start",
    "android": "expo start --android",
    "ios": "expo start --ios",
    "web": "expo start --web",
    "typecheck": "tsc --noEmit"
  },
  "dependencies": {
    "@expo/vector-icons": "^14.0.0",
    "@repo/api": "workspace:*",
    "@repo/shared": "workspace:*",
    "@tanstack/react-query": "^5.62.0",
    "@trpc/client": "^11.0.0",
    "@trpc/react-query": "^11.0.0",
    "expo": "~52.0.0",
    "expo-constants": "~17.0.0",
    "expo-linking": "~7.0.0",
    "expo-router": "~4.0.0",
    "expo-splash-screen": "~0.29.0",
    "expo-status-bar": "~2.0.0",
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "react-native": "~0.76.0",
    "react-native-safe-area-context": "~4.14.0",
    "react-native-screens": "~4.4.0",
    "react-native-web": "~0.19.13",
    "superjson": "^2.2.1"
  },
  "devDependencies": {
    "@babel/core": "^7.26.0",
    "@types/react": "~18.3.0",
    "typescript": "~5.7.0"
  }
}
EOF

write_file_heredoc "apps/mobile/app.json" << EOF
{
  "expo": {
    "name": "${PROJECT_NAME}-mobile",
    "slug": "${PROJECT_NAME}-mobile",
    "version": "1.0.0",
    "orientation": "portrait",
    "icon": "./assets/images/icon.png",
    "scheme": "${PROJECT_NAME}",
    "userInterfaceStyle": "automatic",
    "newArchEnabled": true,
    "splash": {
      "image": "./assets/images/splash-icon.png",
      "resizeMode": "contain",
      "backgroundColor": "#ffffff"
    },
    "ios": {
      "supportsTablet": true,
      "bundleIdentifier": "com.example.${PROJECT_NAME//[-]/}.mobile"
    },
    "android": {
      "package": "com.example.${PROJECT_NAME//[-]/}.mobile"
    },
    "web": {
      "bundler": "metro",
      "output": "static"
    },
    "plugins": ["expo-router"],
    "experiments": {
      "typedRoutes": true
    }
  }
}
EOF

write_file "apps/mobile/tsconfig.json" '{
  "extends": "expo/tsconfig.base",
  "compilerOptions": {
    "strict": true,
    "paths": {
      "@/*": ["./*"],
      "@repo/api": ["../../packages/api/src/root"],
      "@repo/api/*": ["../../packages/api/src/*"],
      "@repo/shared": ["../../packages/shared/src/index"],
      "@repo/shared/*": ["../../packages/shared/src/*"]
    }
  },
  "include": ["**/*.ts", "**/*.tsx", ".expo/types/**/*.ts", "expo-env.d.ts"]
}'

# --- Mobile tRPC client ---
write_file_heredoc "apps/mobile/lib/trpc.ts" << 'EOF'
import { createTRPCReact } from "@trpc/react-query";
import { httpBatchLink } from "@trpc/client";
import { QueryClient } from "@tanstack/react-query";
import superjson from "superjson";
import type { AppRouter } from "@repo/api";

export const trpc = createTRPCReact<AppRouter>();

const getBaseUrl = () => {
  // For local dev: replace with your machine's IP
  return process.env.EXPO_PUBLIC_API_URL ?? "http://localhost:3000/api/trpc";
};

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: { staleTime: 30 * 1000 },
  },
});

export const trpcClient = trpc.createClient({
  links: [
    httpBatchLink({
      url: getBaseUrl(),
      transformer: superjson,
    }),
  ],
});
EOF

write_file_heredoc "apps/mobile/lib/providers.tsx" << 'EOF'
import { QueryClientProvider } from "@tanstack/react-query";
import { trpc, trpcClient, queryClient } from "./trpc";

export function TRPCProvider({ children }: { children: React.ReactNode }) {
  return (
    <trpc.Provider client={trpcClient} queryClient={queryClient}>
      <QueryClientProvider client={queryClient}>
        {children}
      </QueryClientProvider>
    </trpc.Provider>
  );
}
EOF

# --- Mobile app layout ---
write_file_heredoc "apps/mobile/app/_layout.tsx" << 'EOF'
import { Stack } from "expo-router";
import { StatusBar } from "expo-status-bar";
import { TRPCProvider } from "@/lib/providers";

export default function RootLayout() {
  return (
    <TRPCProvider>
      <Stack>
        <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
      </Stack>
      <StatusBar style="auto" />
    </TRPCProvider>
  );
}
EOF

write_file_heredoc "apps/mobile/app/(tabs)/_layout.tsx" << 'EOF'
import { Tabs } from "expo-router";
import { Ionicons } from "@expo/vector-icons";

export default function TabLayout() {
  return (
    <Tabs
      screenOptions={{
        tabBarActiveTintColor: "#2563eb",
        headerStyle: { backgroundColor: "#2563eb" },
        headerTintColor: "#fff",
      }}
    >
      <Tabs.Screen
        name="index"
        options={{
          title: "Home",
          tabBarIcon: ({ color, size }) => (
            <Ionicons name="home" size={size} color={color} />
          ),
        }}
      />
      <Tabs.Screen
        name="posts"
        options={{
          title: "Posts",
          tabBarIcon: ({ color, size }) => (
            <Ionicons name="list" size={size} color={color} />
          ),
        }}
      />
    </Tabs>
  );
}
EOF

write_file_heredoc "apps/mobile/app/(tabs)/index.tsx" << 'EOF'
import { View, Text } from "react-native";
import { APP_NAME } from "@repo/shared";

export default function HomeScreen() {
  return (
    <View style={{ flex: 1, alignItems: "center", justifyContent: "center", padding: 24 }}>
      <Text style={{ fontSize: 28, fontWeight: "bold", marginBottom: 8 }}>
        {APP_NAME}
      </Text>
      <Text style={{ fontSize: 16, color: "#666", textAlign: "center" }}>
        Mobile app sharing tRPC API with the web app.
      </Text>
    </View>
  );
}
EOF

write_file_heredoc "apps/mobile/app/(tabs)/posts.tsx" << 'EOF'
import {
  View,
  Text,
  FlatList,
  ActivityIndicator,
  Pressable,
  RefreshControl,
} from "react-native";
import { trpc } from "@/lib/trpc";
import { formatDate } from "@repo/shared/utils";

export default function PostsScreen() {
  const posts = trpc.post.list.useQuery();

  if (posts.isLoading) {
    return (
      <View style={{ flex: 1, alignItems: "center", justifyContent: "center" }}>
        <ActivityIndicator size="large" color="#2563eb" />
      </View>
    );
  }

  if (posts.error) {
    return (
      <View style={{ flex: 1, alignItems: "center", justifyContent: "center", padding: 24 }}>
        <Text style={{ color: "red", textAlign: "center" }}>
          Error: {posts.error.message}
        </Text>
        <Pressable
          onPress={() => posts.refetch()}
          style={{
            marginTop: 16,
            backgroundColor: "#2563eb",
            paddingHorizontal: 24,
            paddingVertical: 12,
            borderRadius: 8,
          }}
        >
          <Text style={{ color: "#fff", fontWeight: "600" }}>Retry</Text>
        </Pressable>
      </View>
    );
  }

  return (
    <FlatList
      data={posts.data}
      keyExtractor={(item) => item.id.toString()}
      contentContainerStyle={{ padding: 16 }}
      refreshControl={
        <RefreshControl
          refreshing={posts.isRefetching}
          onRefresh={() => posts.refetch()}
        />
      }
      renderItem={({ item }) => (
        <View
          style={{
            backgroundColor: "#fff",
            borderRadius: 12,
            padding: 16,
            marginBottom: 12,
            shadowColor: "#000",
            shadowOpacity: 0.05,
            shadowRadius: 4,
            elevation: 2,
          }}
        >
          <Text style={{ fontSize: 18, fontWeight: "600" }}>{item.title}</Text>
          <Text style={{ color: "#666", marginTop: 4 }}>{item.content}</Text>
          <Text style={{ color: "#999", marginTop: 8, fontSize: 12 }}>
            {formatDate(item.createdAt)}
          </Text>
        </View>
      )}
      ListEmptyComponent={
        <Text style={{ color: "#999", textAlign: "center", marginTop: 32 }}>
          No posts yet. Start the web app and add some!
        </Text>
      }
    />
  );
}
EOF

write_file_heredoc "apps/mobile/babel.config.js" << 'EOF'
module.exports = function (api) {
  api.cache(true);
  return {
    presets: ["babel-preset-expo"],
  };
};
EOF

write_file_heredoc "apps/mobile/metro.config.js" << 'EOF'
const { getDefaultConfig } = require("expo/metro-config");
const path = require("path");

const projectRoot = __dirname;
const monorepoRoot = path.resolve(projectRoot, "../..");

const config = getDefaultConfig(projectRoot);

config.watchFolders = [monorepoRoot];
config.resolver.nodeModulesPaths = [
  path.resolve(projectRoot, "node_modules"),
  path.resolve(monorepoRoot, "node_modules"),
];

module.exports = config;
EOF

mkdir -p apps/mobile/assets/images

# =====================================================
# Final setup
# =====================================================

# --- Root .env.example ---
write_file ".env.example" 'DATABASE_URL="file:./dev.db"
EXPO_PUBLIC_API_URL="http://localhost:3000/api/trpc"'

init_git
write_gitignore \
  ".expo/" \
  "android/" \
  "ios/" \
  "web-build/" \
  ".next/" \
  "*.jks" \
  "*.keystore" \
  "*.db" \
  "*.db-journal" \
  "packages/api/prisma/dev.db"
write_editorconfig
write_nvmrc

write_readme "$PROJECT_NAME" "Full-stack monorepo with Expo 52, Next.js 15, tRPC 11, and Prisma 6." \
  "npm install && npm run db:generate && npm run db:push" \
  "npm run dev" \
  "- \`npm run dev\` - Start all apps in parallel
- \`npm run build\` - Build all apps
- \`npm run db:push\` - Push Prisma schema to database
- \`npm run db:generate\` - Generate Prisma client"

finish "npm install && npm run db:generate && npm run db:push" "npm run dev"
