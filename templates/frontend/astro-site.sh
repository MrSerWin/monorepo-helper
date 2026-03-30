#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-astro-site" "$@"
create_project_dir

# --- package.json ---
write_package_json '{
  "name": "'"$PROJECT_NAME"'",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "astro dev",
    "build": "astro build",
    "preview": "astro preview",
    "astro": "astro"
  },
  "dependencies": {
    "astro": "^5.6.0",
    "@astrojs/tailwind": "^6.0.2",
    "tailwindcss": "^4.1.3"
  },
  "devDependencies": {
    "@types/node": "^22.14.0",
    "typescript": "^5.8.3"
  }
}'

# --- astro.config.mjs ---
write_file "astro.config.mjs" 'import { defineConfig } from "astro/config";
import tailwindcss from "@astrojs/tailwind";

export default defineConfig({
  integrations: [tailwindcss()],
});'

# --- tsconfig.json ---
write_tsconfig '{
  "extends": "astro/tsconfigs/strict",
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@/*": ["src/*"]
    }
  }
}'

# --- src/pages/index.astro ---
write_file "src/pages/index.astro" '---
import Layout from "../layouts/Layout.astro";
import Card from "../components/Card.astro";
---

<Layout title="Welcome">
  <main class="mx-auto max-w-4xl px-4 py-16">
    <div class="text-center space-y-6">
      <h1 class="text-5xl font-bold text-gray-900">
        Welcome to <span class="text-purple-600">Astro</span>
      </h1>
      <p class="text-lg text-gray-600">
        Build fast websites, faster.
      </p>
    </div>
    <div class="mt-12 grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
      <Card
        title="Documentation"
        description="Learn how Astro works and explore the official docs."
        href="https://docs.astro.build/"
      />
      <Card
        title="Integrations"
        description="Supercharge your project with frameworks, CMS, and more."
        href="https://astro.build/integrations/"
      />
      <Card
        title="Themes"
        description="Explore a galaxy of community-built starter themes."
        href="https://astro.build/themes/"
      />
    </div>
  </main>
</Layout>'

# --- src/layouts/Layout.astro ---
write_file "src/layouts/Layout.astro" '---
interface Props {
  title: string;
}

const { title } = Astro.props;
---

<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <meta name="generator" content={Astro.generator} />
    <link rel="icon" type="image/svg+xml" href="/favicon.svg" />
    <title>{title}</title>
  </head>
  <body class="min-h-screen bg-gray-50 antialiased">
    <slot />
  </body>
</html>'

# --- src/components/Card.astro ---
write_file "src/components/Card.astro" '---
interface Props {
  title: string;
  description: string;
  href: string;
}

const { title, description, href } = Astro.props;
---

<a
  href={href}
  target="_blank"
  rel="noopener noreferrer"
  class="block bg-white shadow rounded-xl p-6 hover:shadow-md transition-shadow group"
>
  <h2 class="text-xl font-semibold text-gray-900 group-hover:text-purple-600 transition-colors">
    {title}
    <span class="inline-block ml-1 transition-transform group-hover:translate-x-1">&rarr;</span>
  </h2>
  <p class="mt-2 text-gray-600">{description}</p>
</a>'

# --- src/styles/global.css ---
write_file "src/styles/global.css" '@import "tailwindcss";'

# --- public/ ---
mkdir -p public

init_git
write_gitignore
write_editorconfig
write_nvmrc

finish "npm install" "npm run dev"
