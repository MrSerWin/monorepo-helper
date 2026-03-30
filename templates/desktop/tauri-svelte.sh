#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-tauri-svelte-app" "$@"
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
    "check": "svelte-check --tsconfig ./tsconfig.json",
    "tauri": "tauri"
  },
  "dependencies": {
    "@tauri-apps/api": "^2.3.0",
    "@tauri-apps/plugin-opener": "^2.2.6"
  },
  "devDependencies": {
    "@sveltejs/vite-plugin-svelte": "^5.0.3",
    "@tailwindcss/vite": "^4.1.3",
    "@tauri-apps/cli": "^2.3.0",
    "@tsconfig/svelte": "^5.0.4",
    "svelte": "^5.25.0",
    "svelte-check": "^4.1.5",
    "tailwindcss": "^4.1.3",
    "typescript": "^5.8.3",
    "vite": "^6.3.0"
  }
}'

# --- vite.config.ts ---
write_file "vite.config.ts" 'import { defineConfig } from "vite";
import { svelte } from "@sveltejs/vite-plugin-svelte";
import tailwindcss from "@tailwindcss/vite";

const host = process.env.TAURI_DEV_HOST;

export default defineConfig({
  plugins: [svelte(), tailwindcss()],
  clearScreen: false,
  server: {
    port: 1420,
    strictPort: true,
    host: host || false,
    hmr: host
      ? {
          protocol: "ws",
          host,
          port: 1421,
        }
      : undefined,
    watch: {
      ignored: ["**/src-tauri/**"],
    },
  },
});'

# --- tsconfig.json ---
write_tsconfig '{
  "extends": "@tsconfig/svelte/tsconfig.json",
  "compilerOptions": {
    "target": "ES2020",
    "useDefineForClassFields": true,
    "module": "ESNext",
    "resolveJsonModule": true,
    "allowImportingTsExtensions": true,
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "isolatedModules": true,
    "moduleDetection": "force",
    "noEmit": true,
    "strict": true
  },
  "include": ["src/**/*.ts", "src/**/*.svelte"]
}'

# --- svelte.config.js ---
write_file "svelte.config.js" 'import { vitePreprocess } from "@sveltejs/vite-plugin-svelte";

export default {
  preprocess: vitePreprocess(),
};'

# --- index.html ---
write_file "index.html" '<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>'"$PROJECT_NAME"'</title>
  </head>
  <body>
    <div id="app"></div>
    <script type="module" src="/src/main.ts"></script>
  </body>
</html>'

# --- src/main.ts ---
write_file "src/main.ts" 'import "./index.css";
import App from "./App.svelte";
import { mount } from "svelte";

const app = mount(App, {
  target: document.getElementById("app")!,
});

export default app;'

# --- src/index.css ---
write_file "src/index.css" '@import "tailwindcss";'

# --- src/App.svelte ---
write_file "src/App.svelte" '<script lang="ts">
  import { invoke } from "@tauri-apps/api/core";

  let name = $state("");
  let greeting = $state("");

  async function greet() {
    greeting = await invoke<string>("greet", { name });
  }
</script>

<div class="min-h-screen flex flex-col items-center justify-center bg-gray-50">
  <div class="text-center space-y-6">
    <h1 class="text-5xl font-bold text-gray-900">
      Tauri + Svelte
    </h1>
    <div class="bg-white shadow rounded-xl p-8 space-y-4">
      <div class="flex gap-2">
        <input
          bind:value={name}
          placeholder="Enter a name..."
          class="border border-gray-300 rounded-lg px-4 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
        <button
          onclick={greet}
          class="bg-blue-600 text-white px-6 py-2 rounded-lg font-medium hover:bg-blue-700 transition-colors cursor-pointer"
        >
          Greet
        </button>
      </div>
      {#if greeting}
        <p class="text-lg text-gray-700">{greeting}</p>
      {/if}
      <p class="text-gray-500 text-sm">
        Edit <code class="bg-gray-100 px-2 py-1 rounded font-mono text-xs">src/App.svelte</code> or
        <code class="bg-gray-100 px-2 py-1 rounded font-mono text-xs">src-tauri/src/lib.rs</code> to get started
      </p>
    </div>
  </div>
</div>'

# --- src/vite-env.d.ts ---
write_file "src/vite-env.d.ts" '/// <reference types="svelte" />
/// <reference types="vite/client" />'

# --- src-tauri/Cargo.toml ---
write_file "src-tauri/Cargo.toml" '[package]
name = "'"$PROJECT_NAME"'"
version = "0.1.0"
edition = "2021"

[lib]
name = "'"${PROJECT_NAME//-/_}"'_lib"
crate-type = ["lib", "cdylib", "staticlib"]

[build-dependencies]
tauri-build = { version = "2", features = [] }

[dependencies]
tauri = { version = "2", features = [] }
tauri-plugin-opener = "2"
serde = { version = "1", features = ["derive"] }
serde_json = "1"'

# --- src-tauri/build.rs ---
write_file "src-tauri/build.rs" 'fn main() {
    tauri_build::build()
}'

# --- src-tauri/src/main.rs ---
write_file "src-tauri/src/main.rs" '#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

fn main() {
    '"${PROJECT_NAME//-/_}"'_lib::run()
}'

# --- src-tauri/src/lib.rs ---
write_file "src-tauri/src/lib.rs" '#[tauri::command]
fn greet(name: &str) -> String {
    format!("Hello, {}! You have been greeted from Rust!", name)
}

pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![greet])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}'

# --- src-tauri/tauri.conf.json ---
write_file "src-tauri/tauri.conf.json" '{
  "$schema": "https://raw.githubusercontent.com/tauri-apps/tauri/dev/crates/tauri-config-schema/schema.json",
  "productName": "'"$PROJECT_NAME"'",
  "version": "0.1.0",
  "identifier": "com.tauri.'"$PROJECT_NAME"'",
  "build": {
    "beforeDevCommand": "npm run dev",
    "devUrl": "http://localhost:1420",
    "beforeBuildCommand": "npm run build",
    "frontendDist": "../dist"
  },
  "app": {
    "title": "'"$PROJECT_NAME"'",
    "windows": [
      {
        "title": "'"$PROJECT_NAME"'",
        "width": 1024,
        "height": 768
      }
    ],
    "security": {
      "csp": null
    }
  },
  "bundle": {
    "active": true,
    "targets": "all",
    "icon": [
      "icons/32x32.png",
      "icons/128x128.png",
      "icons/128x128@2x.png",
      "icons/icon.icns",
      "icons/icon.ico"
    ]
  }
}'

# --- src-tauri/capabilities/default.json ---
write_file "src-tauri/capabilities/default.json" '{
  "$schema": "../gen/schemas/desktop-schema.json",
  "identifier": "default",
  "description": "Capability for the main window",
  "windows": ["main"],
  "permissions": [
    "core:default",
    "opener:default"
  ]
}'

mkdir -p public

init_git
write_gitignore "src-tauri/target/"
write_editorconfig
write_nvmrc

finish "npm install" "npm run tauri dev"
