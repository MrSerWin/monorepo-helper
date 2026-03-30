#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-vue-app" "$@"
create_project_dir

# --- package.json ---
write_package_json '{
  "name": "'"$PROJECT_NAME"'",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vue-tsc -b && vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "pinia": "^3.0.2",
    "vue": "^3.5.13",
    "vue-router": "^4.5.0"
  },
  "devDependencies": {
    "@tailwindcss/vite": "^4.1.3",
    "@tsconfig/node22": "^22.0.1",
    "@types/node": "^22.14.0",
    "@vitejs/plugin-vue": "^5.2.3",
    "@vue/tsconfig": "^0.7.0",
    "tailwindcss": "^4.1.3",
    "typescript": "^5.8.3",
    "vite": "^6.3.0",
    "vue-tsc": "^2.2.8"
  }
}'

# --- vite.config.ts ---
write_file "vite.config.ts" 'import { fileURLToPath, URL } from "node:url";
import { defineConfig } from "vite";
import vue from "@vitejs/plugin-vue";
import tailwindcss from "@tailwindcss/vite";

export default defineConfig({
  plugins: [
    vue(),
    tailwindcss(),
  ],
  resolve: {
    alias: {
      "@": fileURLToPath(new URL("./src", import.meta.url)),
    },
  },
});'

# --- tsconfig.json ---
write_tsconfig '{
  "compilerOptions": {
    "target": "ES2020",
    "module": "ESNext",
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "isolatedModules": true,
    "moduleDetection": "force",
    "noEmit": true,
    "jsx": "preserve",
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true,
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["src/**/*.ts", "src/**/*.tsx", "src/**/*.vue", "env.d.ts"]
}'

# --- env.d.ts ---
write_file "env.d.ts" '/// <reference types="vite/client" />

declare module "*.vue" {
  import type { DefineComponent } from "vue";
  const component: DefineComponent<{}, {}, any>;
  export default component;
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
write_file "src/main.ts" 'import { createApp } from "vue";
import { createPinia } from "pinia";
import App from "./App.vue";
import router from "./router";
import "./assets/main.css";

const app = createApp(App);

app.use(createPinia());
app.use(router);

app.mount("#app");'

# --- src/assets/main.css ---
write_file "src/assets/main.css" '@import "tailwindcss";'

# --- src/App.vue ---
write_file "src/App.vue" '<script setup lang="ts">
import { RouterLink, RouterView } from "vue-router";
</script>

<template>
  <div class="min-h-screen bg-gray-50">
    <header class="bg-white shadow-sm">
      <nav class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div class="flex h-16 items-center justify-between">
          <div class="text-xl font-bold text-gray-900">'"$PROJECT_NAME"'</div>
          <div class="flex gap-6">
            <RouterLink
              to="/"
              class="text-gray-600 hover:text-gray-900 transition-colors"
            >
              Home
            </RouterLink>
            <RouterLink
              to="/about"
              class="text-gray-600 hover:text-gray-900 transition-colors"
            >
              About
            </RouterLink>
          </div>
        </div>
      </nav>
    </header>
    <main class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
      <RouterView />
    </main>
  </div>
</template>'

# --- src/router/index.ts ---
write_file "src/router/index.ts" 'import { createRouter, createWebHistory } from "vue-router";
import HomeView from "../views/HomeView.vue";

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: "/",
      name: "home",
      component: HomeView,
    },
    {
      path: "/about",
      name: "about",
      component: () => import("../views/AboutView.vue"),
    },
  ],
});

export default router;'

# --- src/views/HomeView.vue ---
write_file "src/views/HomeView.vue" '<script setup lang="ts">
import { useCounterStore } from "../stores/counter";
import CounterButton from "../components/CounterButton.vue";

const counter = useCounterStore();
</script>

<template>
  <div class="space-y-8">
    <div class="text-center">
      <h1 class="text-4xl font-bold text-gray-900 sm:text-5xl">
        Welcome to Vue
      </h1>
      <p class="mt-4 text-lg text-gray-600">
        Vite + Vue 3 + TypeScript + Tailwind CSS + Pinia
      </p>
    </div>
    <div class="flex justify-center">
      <div class="bg-white shadow rounded-xl p-8 text-center space-y-4">
        <p class="text-gray-700">Count: <span class="font-bold text-2xl">{{ counter.count }}</span></p>
        <div class="flex gap-3">
          <CounterButton label="Increment" @click="counter.increment" />
          <CounterButton label="Reset" @click="counter.reset" />
        </div>
      </div>
    </div>
  </div>
</template>'

# --- src/views/AboutView.vue ---
write_file "src/views/AboutView.vue" '<template>
  <div class="text-center space-y-4">
    <h1 class="text-4xl font-bold text-gray-900">About</h1>
    <p class="text-lg text-gray-600 max-w-md mx-auto">
      This project was scaffolded with monorepo-helper using Vue 3, Vite, Pinia, Vue Router, and Tailwind CSS.
    </p>
  </div>
</template>'

# --- src/components/CounterButton.vue ---
write_file "src/components/CounterButton.vue" '<script setup lang="ts">
defineProps<{
  label: string;
}>();
</script>

<template>
  <button
    class="bg-emerald-600 text-white px-5 py-2.5 rounded-lg font-medium hover:bg-emerald-700 transition-colors cursor-pointer"
  >
    {{ label }}
  </button>
</template>'

# --- src/stores/counter.ts ---
write_file "src/stores/counter.ts" 'import { defineStore } from "pinia";
import { ref } from "vue";

export const useCounterStore = defineStore("counter", () => {
  const count = ref(0);

  function increment() {
    count.value++;
  }

  function reset() {
    count.value = 0;
  }

  return { count, increment, reset };
});'

# --- public/ ---
mkdir -p public

init_git
write_gitignore
write_editorconfig
write_nvmrc

finish "npm install" "npm run dev"
