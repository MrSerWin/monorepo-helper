#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-vitepress-docs" "$@"
create_project_dir

# --- package.json ---
write_package_json '{
  "name": "'"$PROJECT_NAME"'",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vitepress dev docs",
    "build": "vitepress build docs",
    "preview": "vitepress preview docs"
  },
  "devDependencies": {
    "vitepress": "^2.0.0",
    "vue": "^3.5.0",
    "typescript": "^5.8.3"
  }
}'

# --- docs/.vitepress/config.ts ---
write_file "docs/.vitepress/config.ts" 'import { defineConfig } from "vitepress";

export default defineConfig({
  title: "'"$PROJECT_NAME"'",
  description: "Documentation powered by VitePress",
  themeConfig: {
    nav: [
      { text: "Home", link: "/" },
      { text: "Guide", link: "/guide/getting-started" },
      { text: "API", link: "/api/" },
    ],
    sidebar: {
      "/guide/": [
        {
          text: "Introduction",
          items: [
            { text: "Getting Started", link: "/guide/getting-started" },
          ],
        },
      ],
      "/api/": [
        {
          text: "API Reference",
          items: [{ text: "Overview", link: "/api/" }],
        },
      ],
    },
    socialLinks: [
      { icon: "github", link: "https://github.com/your-org/your-repo" },
    ],
    search: {
      provider: "local",
    },
  },
});'

# --- docs/index.md ---
write_file "docs/index.md" '---
layout: home
hero:
  name: "'"$PROJECT_NAME"'"
  text: "Documentation Site"
  tagline: Built with VitePress 2 + Vue 3 + TypeScript
  actions:
    - theme: brand
      text: Get Started
      link: /guide/getting-started
    - theme: alt
      text: API Reference
      link: /api/
features:
  - title: Fast
    details: Built on Vite for instant HMR and lightning-fast builds.
  - title: Markdown-Centered
    details: Write content in Markdown with Vue components when needed.
  - title: Customizable
    details: Fully customizable theme with Vue 3 components.
---'

# --- docs/guide/getting-started.md ---
write_file "docs/guide/getting-started.md" '# Getting Started

## Installation

```bash
npm install
```

## Development

Start the development server:

```bash
npm run dev
```

The site will be available at `http://localhost:5173`.

## Building for Production

```bash
npm run build
```

## Project Structure

```
docs/
├── .vitepress/
│   └── config.ts          # VitePress configuration
├── guide/
│   └── getting-started.md # This page
├── api/
│   └── index.md           # API reference
└── index.md               # Home page
```'

# --- docs/api/index.md ---
write_file "docs/api/index.md" '# API Reference

## Overview

This section contains the API documentation for the project.

## Example Function

### `greet(name: string): string`

Returns a greeting message.

**Parameters:**

| Name   | Type     | Description          |
| ------ | -------- | -------------------- |
| `name` | `string` | The name to greet    |

**Returns:** `string` - A greeting message.

**Example:**

```ts
import { greet } from "./utils";

const message = greet("World");
console.log(message); // "Hello, World!"
```'

# --- tsconfig.json ---
write_tsconfig '{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "jsx": "preserve"
  },
  "include": ["docs/.vitepress/**/*.ts", "docs/.vitepress/**/*.vue"]
}'

init_git
write_gitignore "docs/.vitepress/cache/" "docs/.vitepress/dist/"
write_editorconfig
write_nvmrc

finish "npm install" "npm run dev"
