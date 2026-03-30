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
    "check": "svelte-kit sync && svelte-check --tsconfig ./tsconfig.json"
  },
  "dependencies": {
    "svelte": "^5.25.0",
    "@sveltejs/kit": "^2.18.0",
    "@sveltejs/adapter-auto": "^4.0.0"
  },
  "devDependencies": {
    "@sveltejs/vite-plugin-svelte": "^5.0.3",
    "@tailwindcss/vite": "^4.1.3",
    "svelte-check": "^4.1.6",
    "tailwindcss": "^4.1.3",
    "typescript": "^5.8.3",
    "vite": "^6.3.0"
  }
}'

# --- vite.config.ts ---
write_file "vite.config.ts" 'import { sveltekit } from "@sveltejs/kit/vite";
import tailwindcss from "@tailwindcss/vite";
import { defineConfig } from "vite";

export default defineConfig({
  plugins: [
    sveltekit(),
    tailwindcss(),
  ],
});'

# --- svelte.config.js ---
write_file "svelte.config.js" 'import adapter from "@sveltejs/adapter-auto";
import { vitePreprocess } from "@sveltejs/vite-plugin-svelte";

/** @type {import("@sveltejs/kit").Config} */
const config = {
  preprocess: vitePreprocess(),
  kit: {
    adapter: adapter(),
  },
};

export default config;'

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

# --- src/app.html ---
write_file "src/app.html" '<!DOCTYPE html>
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
</html>'

# --- src/app.css ---
write_file "src/app.css" '@import "tailwindcss";'

# --- src/app.d.ts ---
write_file "src/app.d.ts" '// See https://svelte.dev/docs/kit/types#app.d.ts
// for information about these interfaces
declare global {
  namespace App {
    // interface Error {}
    // interface Locals {}
    // interface PageData {}
    // interface PageState {}
    // interface Platform {}
  }
}

export {};'

# --- src/routes/+layout.svelte ---
write_file "src/routes/+layout.svelte" '<script lang="ts">
  import "../app.css";
  import type { Snippet } from "svelte";

  let { children }: { children: Snippet } = $props();
</script>

<div class="min-h-screen bg-gray-50">
  <header class="bg-white shadow-sm">
    <nav class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
      <div class="flex h-16 items-center justify-between">
        <div class="text-xl font-bold text-gray-900">'"$PROJECT_NAME"'</div>
        <div class="flex gap-6">
          <a href="/" class="text-gray-600 hover:text-gray-900 transition-colors">Home</a>
          <a href="/about" class="text-gray-600 hover:text-gray-900 transition-colors">About</a>
        </div>
      </div>
    </nav>
  </header>
  <main class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
    {@render children()}
  </main>
</div>'

# --- src/routes/+page.svelte ---
write_file "src/routes/+page.svelte" '<script lang="ts">
  let count = $state(0);
</script>

<svelte:head>
  <title>Home</title>
  <meta name="description" content="SvelteKit app" />
</svelte:head>

<div class="text-center space-y-8">
  <h1 class="text-4xl font-bold text-gray-900 sm:text-5xl">
    Welcome to <span class="text-orange-600">SvelteKit</span>
  </h1>
  <p class="text-lg text-gray-600">
    SvelteKit 2 + Svelte 5 + TypeScript + Tailwind CSS
  </p>
  <div class="bg-white shadow rounded-xl p-8 max-w-md mx-auto space-y-4">
    <p class="text-gray-700">Count: <span class="font-bold text-2xl">{count}</span></p>
    <button
      onclick={() => count++}
      class="bg-orange-600 text-white px-6 py-3 rounded-lg font-medium hover:bg-orange-700 transition-colors cursor-pointer"
    >
      Increment
    </button>
  </div>
</div>'

# --- src/routes/about/+page.svelte ---
write_file "src/routes/about/+page.svelte" '<svelte:head>
  <title>About</title>
  <meta name="description" content="About this app" />
</svelte:head>

<div class="text-center space-y-4">
  <h1 class="text-4xl font-bold text-gray-900">About</h1>
  <p class="text-lg text-gray-600 max-w-md mx-auto">
    This project was scaffolded with monorepo-helper using SvelteKit 2, Svelte 5, and Tailwind CSS.
  </p>
</div>'

# --- static/ ---
mkdir -p static

init_git
write_gitignore
write_editorconfig
write_nvmrc

finish "npm install" "npm run dev"
