#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-remix-app" "$@"
create_project_dir

# --- package.json ---
write_package_json '{
  "name": "'"$PROJECT_NAME"'",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "react-router dev",
    "build": "react-router build",
    "start": "react-router-serve ./build/server/index.js",
    "typecheck": "react-router typegen && tsc"
  },
  "dependencies": {
    "@react-router/node": "^7.5.0",
    "@react-router/serve": "^7.5.0",
    "isbot": "^5.1.27",
    "react": "^19.1.0",
    "react-dom": "^19.1.0",
    "react-router": "^7.5.0"
  },
  "devDependencies": {
    "@react-router/dev": "^7.5.0",
    "@tailwindcss/vite": "^4.1.3",
    "@types/node": "^22.14.0",
    "@types/react": "^19.1.0",
    "@types/react-dom": "^19.1.0",
    "tailwindcss": "^4.1.3",
    "typescript": "^5.8.3",
    "vite": "^6.3.0"
  }
}'

# --- vite.config.ts ---
write_file "vite.config.ts" 'import { reactRouter } from "@react-router/dev/vite";
import tailwindcss from "@tailwindcss/vite";
import { defineConfig } from "vite";

export default defineConfig({
  plugins: [
    tailwindcss(),
    reactRouter(),
  ],
});'

# --- react-router.config.ts ---
write_file "react-router.config.ts" 'import type { Config } from "@react-router/dev/config";

export default {
  ssr: true,
} satisfies Config;'

# --- tsconfig.json ---
write_tsconfig '{
  "include": [
    "env.d.ts",
    "**/*.ts",
    "**/*.tsx",
    ".react-router/types/**/*"
  ],
  "compilerOptions": {
    "lib": ["DOM", "DOM.Iterable", "ES2022"],
    "target": "ES2022",
    "module": "ES2022",
    "moduleResolution": "bundler",
    "jsx": "react-jsx",
    "strict": true,
    "skipLibCheck": true,
    "noEmit": true,
    "isolatedModules": true,
    "esModuleInterop": true,
    "resolveJsonModule": true,
    "rootDirs": [".", "./.react-router/types"],
    "paths": {
      "~/*": ["./app/*"]
    }
  }
}'

# --- env.d.ts ---
write_file "env.d.ts" '/// <reference types="vite/client" />'

# --- app/root.tsx ---
write_file "app/root.tsx" 'import {
  Links,
  Meta,
  Outlet,
  Scripts,
  ScrollRestoration,
  type LinksFunction,
} from "react-router";
import "./app.css";

export const links: LinksFunction = () => [];

export function Layout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <head>
        <meta charSet="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <Meta />
        <Links />
      </head>
      <body className="min-h-screen bg-gray-50 antialiased">
        {children}
        <ScrollRestoration />
        <Scripts />
      </body>
    </html>
  );
}

export default function App() {
  return <Outlet />;
}'

# --- app/app.css ---
write_file "app/app.css" '@import "tailwindcss";'

# --- app/routes.ts ---
write_file "app/routes.ts" 'import { type RouteConfig, index, route } from "@react-router/dev/routes";

export default [
  index("routes/home.tsx"),
  route("about", "routes/about.tsx"),
] satisfies RouteConfig;'

# --- app/routes/home.tsx ---
write_file "app/routes/home.tsx" 'import type { MetaFunction } from "react-router";

export const meta: MetaFunction = () => {
  return [
    { title: "'"$PROJECT_NAME"'" },
    { name: "description", content: "Welcome to React Router!" },
  ];
};

export default function Home() {
  return (
    <div className="mx-auto max-w-4xl px-4 py-16 text-center">
      <h1 className="text-5xl font-bold text-gray-900">
        Welcome to <span className="text-blue-600">React Router</span>
      </h1>
      <p className="mt-4 text-lg text-gray-600">
        Remix (React Router 7) + React 19 + TypeScript + Tailwind CSS
      </p>
      <div className="mt-8 flex justify-center gap-4">
        <a
          href="https://reactrouter.com/docs"
          target="_blank"
          rel="noopener noreferrer"
          className="rounded-full bg-blue-600 px-6 py-3 text-sm font-medium text-white hover:bg-blue-700 transition-colors"
        >
          Read the Docs
        </a>
        <a
          href="/about"
          className="rounded-full border border-gray-300 px-6 py-3 text-sm font-medium text-gray-900 hover:bg-gray-100 transition-colors"
        >
          About
        </a>
      </div>
    </div>
  );
}'

# --- app/routes/about.tsx ---
write_file "app/routes/about.tsx" 'import type { MetaFunction } from "react-router";

export const meta: MetaFunction = () => {
  return [
    { title: "About - '"$PROJECT_NAME"'" },
    { name: "description", content: "About this app" },
  ];
};

export default function About() {
  return (
    <div className="mx-auto max-w-4xl px-4 py-16 text-center">
      <h1 className="text-4xl font-bold text-gray-900">About</h1>
      <p className="mt-4 text-lg text-gray-600 max-w-md mx-auto">
        This project was scaffolded with monorepo-helper using React Router 7 (Remix), React 19, and Tailwind CSS.
      </p>
      <div className="mt-8">
        <a
          href="/"
          className="text-blue-600 hover:text-blue-800 font-medium transition-colors"
        >
          &larr; Back to Home
        </a>
      </div>
    </div>
  );
}'

# --- public/ ---
mkdir -p public

init_git
write_gitignore
write_editorconfig
write_nvmrc

finish "npm install" "npm run dev"
