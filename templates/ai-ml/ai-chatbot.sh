#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-ai-chatbot" "$@"
header "Next.js 15 + Vercel AI SDK 4 + TypeScript + Tailwind CSS 4"

create_project_dir

# ── package.json ──────────────────────────────────────────────
section "Package configuration"
write_package_json '{
  "name": "'"$PROJECT_NAME"'",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "next dev --turbopack",
    "build": "next build",
    "start": "next start",
    "lint": "next lint"
  },
  "dependencies": {
    "ai": "^4.3.0",
    "@ai-sdk/openai": "^1.3.0",
    "@ai-sdk/anthropic": "^1.3.0",
    "next": "^15.3.0",
    "react": "^19.1.0",
    "react-dom": "^19.1.0",
    "zod": "^3.24.3"
  },
  "devDependencies": {
    "@tailwindcss/postcss": "^4.1.3",
    "@types/node": "^22.14.0",
    "@types/react": "^19.1.0",
    "@types/react-dom": "^19.1.0",
    "eslint": "^9.24.0",
    "eslint-config-next": "^15.3.0",
    "tailwindcss": "^4.1.3",
    "typescript": "^5.8.3"
  }
}'

# ── next.config.ts ────────────────────────────────────────────
write_file "next.config.ts" 'import type { NextConfig } from "next";

const nextConfig: NextConfig = {};

export default nextConfig;'

# ── tsconfig.json ─────────────────────────────────────────────
section "TypeScript configuration"
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
    "plugins": [{ "name": "next" }],
    "paths": { "@/*": ["./src/*"] }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}'

# ── postcss.config.mjs ───────────────────────────────────────
write_file "postcss.config.mjs" 'const config = {
  plugins: {
    "@tailwindcss/postcss": {},
  },
};

export default config;'

# ── eslint.config.mjs ────────────────────────────────────────
write_file_heredoc "eslint.config.mjs" << 'EOF'
import { dirname } from "path";
import { fileURLToPath } from "url";
import { FlatCompat } from "@eslint/eslintrc";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const compat = new FlatCompat({ baseDirectory: __dirname });

const eslintConfig = [
  ...compat.extends("next/core-web-vitals", "next/typescript"),
];

export default eslintConfig;
EOF
success "Created eslint.config.mjs"

# ── .env.example ──────────────────────────────────────────────
write_file_heredoc ".env.example" << 'EOF'
# OpenAI
OPENAI_API_KEY=sk-your-openai-key

# Anthropic
ANTHROPIC_API_KEY=sk-ant-your-anthropic-key

# Default provider: "openai" or "anthropic"
AI_PROVIDER=openai
EOF
success "Created .env.example"

# ── src/app/globals.css ───────────────────────────────────────
section "Application source files"
write_file "src/app/globals.css" '@import "tailwindcss";'

# ── src/app/layout.tsx ────────────────────────────────────────
write_file_heredoc "src/app/layout.tsx" << 'EOF'
import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "AI Chatbot",
  description: "AI Chatbot powered by Vercel AI SDK",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className="antialiased bg-gray-50 text-gray-900">{children}</body>
    </html>
  );
}
EOF
success "Created src/app/layout.tsx"

# ── src/app/page.tsx ──────────────────────────────────────────
write_file_heredoc "src/app/page.tsx" << 'EOF'
"use client";

import { useChat } from "ai/react";
import { useState } from "react";

type Provider = "openai" | "anthropic";

export default function Home() {
  const [provider, setProvider] = useState<Provider>("openai");

  const { messages, input, handleInputChange, handleSubmit, isLoading, error } =
    useChat({
      api: "/api/chat",
      body: { provider },
    });

  return (
    <div className="flex min-h-screen flex-col items-center">
      <header className="w-full border-b bg-white px-4 py-3">
        <div className="mx-auto flex max-w-3xl items-center justify-between">
          <h1 className="text-lg font-semibold">AI Chatbot</h1>
          <select
            value={provider}
            onChange={(e) => setProvider(e.target.value as Provider)}
            className="rounded-md border border-gray-300 bg-white px-3 py-1.5 text-sm"
          >
            <option value="openai">OpenAI</option>
            <option value="anthropic">Anthropic</option>
          </select>
        </div>
      </header>

      <main className="mx-auto flex w-full max-w-3xl flex-1 flex-col p-4">
        <div className="flex-1 space-y-4 overflow-y-auto pb-4">
          {messages.length === 0 && (
            <div className="flex h-full items-center justify-center text-gray-400">
              <p>Send a message to start chatting.</p>
            </div>
          )}
          {messages.map((message) => (
            <div
              key={message.id}
              className={`flex ${message.role === "user" ? "justify-end" : "justify-start"}`}
            >
              <div
                className={`max-w-[80%] rounded-2xl px-4 py-2.5 text-sm leading-relaxed ${
                  message.role === "user"
                    ? "bg-blue-600 text-white"
                    : "bg-white text-gray-900 shadow-sm border border-gray-200"
                }`}
              >
                <p className="whitespace-pre-wrap">{message.content}</p>
              </div>
            </div>
          ))}
          {isLoading && (
            <div className="flex justify-start">
              <div className="rounded-2xl bg-white px-4 py-2.5 text-sm text-gray-400 shadow-sm border border-gray-200">
                Thinking...
              </div>
            </div>
          )}
          {error && (
            <div className="rounded-lg bg-red-50 px-4 py-3 text-sm text-red-600">
              Error: {error.message}
            </div>
          )}
        </div>

        <form onSubmit={handleSubmit} className="flex gap-2 pt-2">
          <input
            value={input}
            onChange={handleInputChange}
            placeholder="Type a message..."
            className="flex-1 rounded-xl border border-gray-300 bg-white px-4 py-3 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
          />
          <button
            type="submit"
            disabled={isLoading || !input.trim()}
            className="rounded-xl bg-blue-600 px-5 py-3 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          >
            Send
          </button>
        </form>
      </main>
    </div>
  );
}
EOF
success "Created src/app/page.tsx"

# ── src/app/api/chat/route.ts ────────────────────────────────
write_file_heredoc "src/app/api/chat/route.ts" << 'EOF'
import { streamText } from "ai";
import { openai } from "@ai-sdk/openai";
import { anthropic } from "@ai-sdk/anthropic";

export const maxDuration = 30;

export async function POST(req: Request) {
  const { messages, provider = "openai" } = await req.json();

  const model =
    provider === "anthropic"
      ? anthropic("claude-sonnet-4-20250514")
      : openai("gpt-4o");

  const result = streamText({
    model,
    system: "You are a helpful assistant. Be concise and clear in your responses.",
    messages,
  });

  return result.toDataStreamResponse();
}
EOF
success "Created src/app/api/chat/route.ts"

# ── next-env.d.ts ─────────────────────────────────────────────
write_file "next-env.d.ts" '/// <reference types="next" />
/// <reference types="next/image-types/global" />

// NOTE: This file should not be edited
// see https://nextjs.org/docs/app/api-reference/config/typescript for more information.'

mkdir -p public

# ── Finalize ──────────────────────────────────────────────────
section "Finalizing"
init_git
write_gitignore
write_editorconfig
write_nvmrc

write_readme "$PROJECT_NAME" \
  "AI Chatbot built with Next.js 15, Vercel AI SDK 4, and Tailwind CSS 4. Supports OpenAI and Anthropic providers." \
  "npm install" \
  "npm run dev"

finish "npm install" "npm run dev"
