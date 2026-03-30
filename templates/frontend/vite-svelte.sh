#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-svelte-app" "$@"
create_project_dir

# --- package.json ---
write_package_json '{
  "name": "'"$PROJECT_NAME"'",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview",
    "check": "svelte-check --tsconfig ./tsconfig.json"
  },
  "dependencies": {
    "svelte": "^5.25.0"
  },
  "devDependencies": {
    "@sveltejs/vite-plugin-svelte": "^5.0.3",
    "@tailwindcss/vite": "^4.1.3",
    "@tsconfig/svelte": "^5.0.4",
    "svelte-check": "^4.1.6",
    "tailwindcss": "^4.1.3",
    "typescript": "^5.8.3",
    "vite": "^6.3.0"
  }
}'

# --- vite.config.ts ---
write_file "vite.config.ts" 'import { defineConfig } from "vite";
import { svelte } from "@sveltejs/vite-plugin-svelte";
import tailwindcss from "@tailwindcss/vite";

export default defineConfig({
  plugins: [
    svelte(),
    tailwindcss(),
  ],
});'

# --- svelte.config.js ---
write_file "svelte.config.js" 'import { vitePreprocess } from "@sveltejs/vite-plugin-svelte";

export default {
  preprocess: vitePreprocess(),
};'

# --- tsconfig.json ---
write_tsconfig '{
  "extends": "@tsconfig/svelte/tsconfig.json",
  "compilerOptions": {
    "target": "ESNext",
    "useDefineForClassFields": true,
    "module": "ESNext",
    "resolveJsonModule": true,
    "allowJs": true,
    "checkJs": true,
    "isolatedModules": true,
    "moduleDetection": "force",
    "strict": true
  },
  "include": ["src/**/*.ts", "src/**/*.svelte"]
}'

# --- index.html ---
write_file "index.html" '<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <link rel="icon" type="image/svg+xml" href="/vite.svg" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>'"$PROJECT_NAME"'</title>
  </head>
  <body>
    <div id="app"></div>
    <script type="module" src="/src/main.ts"></script>
  </body>
</html>'

# --- src/main.ts ---
write_file "src/main.ts" 'import "./app.css";
import App from "./App.svelte";
import { mount } from "svelte";

const app = mount(App, {
  target: document.getElementById("app")!,
});

export default app;'

# --- src/app.css ---
write_file "src/app.css" '@import "tailwindcss";'

# --- src/App.svelte ---
write_file "src/App.svelte" '<script lang="ts">
  let count = $state(0);

  function increment() {
    count++;
  }
</script>

<div class="min-h-screen flex flex-col items-center justify-center bg-gray-50">
  <div class="text-center space-y-6">
    <h1 class="text-5xl font-bold text-gray-900">
      Vite + Svelte
    </h1>
    <div class="bg-white shadow rounded-xl p-8 space-y-4">
      <button
        onclick={increment}
        class="bg-orange-600 text-white px-6 py-3 rounded-lg font-medium hover:bg-orange-700 transition-colors cursor-pointer"
      >
        Count is {count}
      </button>
      <p class="text-gray-500 text-sm">
        Edit <code class="bg-gray-100 px-2 py-1 rounded font-mono text-xs">src/App.svelte</code> and save to test HMR
      </p>
    </div>
  </div>
</div>'

# --- src/vite-env.d.ts ---
write_file "src/vite-env.d.ts" '/// <reference types="svelte" />
/// <reference types="vite/client" />'

# --- public/ ---
mkdir -p public

init_git
write_gitignore
write_editorconfig
write_nvmrc

finish "npm install" "npm run dev"
