#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-nuxt-app" "$@"
create_project_dir

# --- package.json ---
write_package_json '{
  "name": "'"$PROJECT_NAME"'",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "nuxt dev",
    "build": "nuxt build",
    "generate": "nuxt generate",
    "preview": "nuxt preview",
    "postinstall": "nuxt prepare"
  },
  "dependencies": {
    "nuxt": "^4.1.0",
    "vue": "^3.5.13",
    "vue-router": "^4.5.0"
  },
  "devDependencies": {
    "@nuxtjs/tailwindcss": "^6.13.2",
    "typescript": "^5.8.3"
  }
}'

# --- nuxt.config.ts ---
write_file "nuxt.config.ts" 'export default defineNuxtConfig({
  compatibilityDate: "2025-03-30",
  devtools: { enabled: true },
  modules: ["@nuxtjs/tailwindcss"],
  typescript: {
    strict: true,
  },
});'

# --- tsconfig.json ---
write_tsconfig '{
  "extends": "./.nuxt/tsconfig.json"
}'

# --- app/app.vue ---
write_file "app/app.vue" '<template>
  <div>
    <NuxtLayout>
      <NuxtPage />
    </NuxtLayout>
  </div>
</template>'

# --- app/layouts/default.vue ---
write_file "app/layouts/default.vue" '<template>
  <div class="min-h-screen bg-gray-50">
    <header class="bg-white shadow-sm">
      <nav class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div class="flex h-16 items-center justify-between">
          <div class="text-xl font-bold text-gray-900">'"$PROJECT_NAME"'</div>
          <div class="flex gap-6">
            <NuxtLink
              to="/"
              class="text-gray-600 hover:text-gray-900 transition-colors"
            >
              Home
            </NuxtLink>
            <NuxtLink
              to="/about"
              class="text-gray-600 hover:text-gray-900 transition-colors"
            >
              About
            </NuxtLink>
          </div>
        </div>
      </nav>
    </header>
    <main class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
      <slot />
    </main>
  </div>
</template>'

# --- app/pages/index.vue ---
write_file "app/pages/index.vue" '<script setup lang="ts">
const { data: greeting } = await useFetch("/api/hello");
</script>

<template>
  <div class="text-center space-y-8">
    <h1 class="text-4xl font-bold text-gray-900 sm:text-5xl">
      Welcome to <span class="text-green-600">Nuxt</span>
    </h1>
    <p class="text-lg text-gray-600">
      Nuxt 4 + Vue 3 + TypeScript + Tailwind CSS
    </p>
    <div class="bg-white shadow rounded-xl p-8 max-w-md mx-auto">
      <p class="text-gray-700">
        API says: <span class="font-bold text-green-600">{{ greeting }}</span>
      </p>
    </div>
    <p class="text-gray-400 text-sm">
      Edit <code class="bg-gray-100 px-2 py-1 rounded font-mono text-xs">app/pages/index.vue</code> to get started
    </p>
  </div>
</template>'

# --- app/pages/about.vue ---
write_file "app/pages/about.vue" '<template>
  <div class="text-center space-y-4">
    <h1 class="text-4xl font-bold text-gray-900">About</h1>
    <p class="text-lg text-gray-600 max-w-md mx-auto">
      This project was scaffolded with monorepo-helper using Nuxt 4, Vue 3, and Tailwind CSS.
    </p>
  </div>
</template>'

# --- app/assets/css/tailwind.css ---
write_file "app/assets/css/tailwind.css" '@import "tailwindcss";'

# --- app/composables/useAppConfig.ts ---
write_file "app/composables/useAppConfig.ts" 'export const useAppSettings = () => {
  const appName = "'"$PROJECT_NAME"'";

  return {
    appName,
  };
};'

# --- server/api/hello.get.ts ---
write_file "server/api/hello.get.ts" 'export default defineEventHandler(() => {
  return "Hello from Nuxt server!";
});'

# --- server/tsconfig.json ---
write_file "server/tsconfig.json" '{
  "extends": "../.nuxt/tsconfig.server.json"
}'

# --- public/ ---
mkdir -p public

init_git
write_gitignore
write_editorconfig
write_nvmrc

finish "npm install" "npm run dev"
