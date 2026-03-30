# monorepo-helper (mh)

A CLI tool that generates **fully working boilerplate projects** for standalone apps and monorepos. Save hours of setup time and thousands of AI agent tokens.

**80 templates** across **19 categories** covering frontend, backend, fullstack, mobile, desktop, AI/ML, monorepo, serverless, and more.

## Quick Start

**macOS / Linux:**
```bash
git clone https://github.com/MrSerWin/monorepo-helper.git
cd monorepo-helper
export PATH="$PWD/bin:$PATH"

mh generate next-app my-website
mh generate node-express --name my-api
mh generate turbo-saas
```

**Windows (PowerShell):**
```powershell
# One-line install (PowerShell as Administrator)
irm https://raw.githubusercontent.com/MrSerWin/monorepo-helper/main/install.ps1 | iex

# Then in a new terminal:
mh generate next-app my-website
```

## Installation

### macOS / Linux

#### Option 1: Clone & Symlink

```bash
git clone https://github.com/MrSerWin/monorepo-helper.git ~/.monorepo-helper

# Option A: symlink to /usr/local/bin (requires sudo)
sudo ln -s ~/.monorepo-helper/bin/mh /usr/local/bin/mh

# Option B: symlink to ~/.local/bin (no sudo needed)
mkdir -p ~/.local/bin
ln -s ~/.monorepo-helper/bin/mh ~/.local/bin/mh
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc  # or ~/.bashrc
```

#### Option 2: Direct Download

```bash
curl -fsSL https://raw.githubusercontent.com/MrSerWin/monorepo-helper/main/install.sh | bash
```

### Windows

#### Option 1: PowerShell Installer (recommended)

```powershell
irm https://raw.githubusercontent.com/MrSerWin/monorepo-helper/main/install.ps1 | iex
```

The installer will:
- Optionally install Git for Windows via `winget` if not present
- Clone the repository to `$HOME\.monorepo-helper`
- Add `bin\` to your user `PATH`
- Add an `mh` function to your PowerShell profile

#### Option 2: Manual setup

```powershell
git clone https://github.com/MrSerWin/monorepo-helper.git $HOME\.monorepo-helper
$env:PATH += ";$HOME\.monorepo-helper\bin"

# Permanent PATH (run once):
[Environment]::SetEnvironmentVariable(
  "PATH",
  [Environment]::GetEnvironmentVariable("PATH","User") + ";$HOME\.monorepo-helper\bin",
  "User"
)

# Use via PowerShell:
mh.ps1 generate next-app my-website
# Or via CMD:
mh.bat generate next-app my-website
```

#### Windows Requirements

mh requires a bash environment. The launcher (`mh.bat` / `mh.ps1`) auto-detects in this order:

| Option | Install | Notes |
|--------|---------|-------|
| **Git for Windows** | `winget install Git.Git` | Recommended, ~50 MB |
| **WSL** | `wsl --install` | Full Linux on Windows |
| **Cygwin** | [cygwin.com](https://cygwin.com) | Alternative |

## Usage

```
mh <command> [options]

COMMANDS
  generate <template> [name]  Generate a new project from template
  list [category]             List available templates
  search <query>              Search templates by keyword
  info <template>             Show template details
  version                     Show version
  help                        Show help

OPTIONS
  --name, -n <name>           Project name (default: template-specific)

EXAMPLES
  mh generate next-app my-website
  mh generate node-express --name my-api
  mh list frontend
  mh search react
  mh info turbo-saas
```

## Templates

### 1. Frontend (8 templates)

| Template | Stack | Description |
|----------|-------|-------------|
| `next-app` | Next.js 15 + React 19 + TypeScript + Tailwind CSS 4 + ESLint 9 | Fullstack React framework (App Router) |
| `vite-react` | Vite 6 + React 19 + TypeScript + Tailwind CSS 4 + ESLint 9 | React SPA |
| `vite-vue` | Vite 6 + Vue 3.5 + TypeScript + Tailwind CSS 4 + Pinia + Vue Router | Vue SPA |
| `nuxt-app` | Nuxt 4 + Vue 3.5 + TypeScript + Tailwind CSS 4 | Fullstack Vue framework |
| `vite-svelte` | Vite 6 + Svelte 5 + TypeScript + Tailwind CSS 4 | Svelte SPA |
| `sveltekit-app` | SvelteKit 2 + Svelte 5 + TypeScript + Tailwind CSS 4 | Fullstack Svelte framework |
| `astro-site` | Astro 5 + TypeScript + Tailwind CSS 4 | Content / static site |
| `remix-app` | React Router 7 (Remix) + React 19 + TypeScript + Tailwind CSS 4 | Fullstack React with nested routes |

### 2. Backend (10 templates)

| Template | Stack | Description |
|----------|-------|-------------|
| `node-express` | Node.js 22 + Express 5 + TypeScript + Prisma 6 + PostgreSQL | REST API |
| `node-fastify` | Node.js 22 + Fastify 5 + TypeScript + Prisma 6 + PostgreSQL + Swagger | High-performance REST API |
| `node-hono` | Node.js 22 + Hono 4 + TypeScript + Drizzle ORM + PostgreSQL | Lightweight edge-ready API |
| `node-nestjs` | NestJS 11 + TypeScript + Prisma 6 + PostgreSQL + Swagger + JWT Auth | Enterprise-grade API |
| `node-graphql` | Node.js 22 + Apollo Server 4 + TypeScript + Pothos + Prisma 6 | GraphQL API |
| `bun-elysia` | Bun 1.2 + Elysia 1.2 + TypeScript + Drizzle ORM + PostgreSQL | Bun-native ultra-fast API |
| `go-chi` | Go 1.23 + Chi router + sqlc + PostgreSQL + Docker | Go REST API |
| `go-fiber` | Go 1.23 + Fiber v3 + GORM + PostgreSQL + Docker | High-performance Go API |
| `python-fastapi` | Python 3.13 + FastAPI + SQLAlchemy 2 + Alembic + PostgreSQL | Python REST API |
| `python-django` | Python 3.13 + Django 5 + DRF + PostgreSQL + Docker | Python fullstack / API |

### 3. Fullstack (5 templates)

| Template | Stack | Description |
|----------|-------|-------------|
| `t3-app` | Next.js 15 + tRPC 11 + Prisma 6 + NextAuth 5 + Tailwind CSS 4 | Type-safe fullstack |
| `next-supabase` | Next.js 15 + Supabase + Tailwind CSS 4 + TypeScript | Fullstack with BaaS |
| `next-drizzle` | Next.js 15 + Drizzle ORM + PostgreSQL + NextAuth 5 + Tailwind CSS 4 | Fullstack with SQL-first ORM |
| `sveltekit-prisma` | SvelteKit 2 + Prisma 6 + PostgreSQL + Lucia Auth + Tailwind CSS 4 | Svelte fullstack |
| `nuxt-supabase` | Nuxt 4 + Supabase + Tailwind CSS 4 + TypeScript | Vue fullstack with BaaS |

### 4. Mobile (16 templates)

| Template | Stack | Description |
|----------|-------|-------------|
| `expo-app` | Expo 52 + React Native + TypeScript + NativeWind + Expo Router | Cross-platform (managed) |
| `rn-bare` | React Native 0.77 + TypeScript + React Navigation + NativeWind | Cross-platform (bare) |
| `expo-supabase` | Expo 52 + Supabase + TypeScript + NativeWind + Expo Router | Mobile with BaaS |
| `expo-firebase` | Expo 52 + Firebase + TypeScript + NativeWind + Expo Router | Mobile with Firebase |
| `flutter-app` | Flutter 3.27 + Dart 3.6 + Material 3 + Riverpod | Cross-platform Flutter |
| `flutter-firebase` | Flutter 3.27 + Firebase + Riverpod + GoRouter | Flutter with Firebase |
| `flutter-supabase` | Flutter 3.27 + Supabase + Riverpod + GoRouter | Flutter with BaaS |
| `kotlin-compose` | Kotlin + Jetpack Compose + Material 3 + Hilt + Room + Ktor | Android native |
| `swift-app` | Swift 6 + SwiftUI + SwiftData + Observation | iOS native |
| `kmp-app` | Kotlin Multiplatform + Compose Multiplatform + Koin + Ktor | KMP cross-platform |
| `ionic-angular` | Ionic 8 + Angular 19 + Capacitor 6 + TypeScript | Hybrid (Angular) |
| `ionic-react` | Ionic 8 + React 19 + Capacitor 6 + TypeScript | Hybrid (React) |
| `maui-app` | .NET 9 + MAUI + C# + CommunityToolkit + MVVM | .NET cross-platform |
| `maui-blazor` | .NET 9 + MAUI + Blazor Hybrid + C# + MudBlazor | .NET hybrid |
| `expo-trpc` | Expo 52 + tRPC 11 + Tanstack Query + TypeScript + NativeWind | Type-safe mobile client |
| `expo-trpc-monorepo` | Turborepo + Expo 52 + Next.js 15 + tRPC 11 + Prisma 6 | Fullstack web + mobile monorepo |

### 5. Desktop (3 templates)

| Template | Stack | Description |
|----------|-------|-------------|
| `electron-react` | Electron 34 + React 19 + Vite 6 + TypeScript + Tailwind CSS 4 | Electron desktop app |
| `tauri-react` | Tauri 2 + React 19 + Vite 6 + TypeScript + Tailwind CSS 4 | Lightweight desktop app |
| `tauri-svelte` | Tauri 2 + Svelte 5 + Vite 6 + TypeScript + Tailwind CSS 4 | Tauri + Svelte desktop |

### 6. CLI / Library / Tooling (4 templates)

| Template | Stack | Description |
|----------|-------|-------------|
| `node-cli` | Node.js 22 + TypeScript + Commander.js + tsup + Vitest | CLI utility |
| `npm-package` | TypeScript + tsup + Vitest + Changesets + GitHub Actions | NPM package / library |
| `go-cli` | Go 1.23 + Cobra + Viper | Go CLI tool |
| `chrome-ext` | Vite 6 + React 19 + TypeScript + CRXJS + Tailwind CSS 4 | Chrome Extension (MV3) |

### 7. AI / ML (3 templates)

| Template | Stack | Description |
|----------|-------|-------------|
| `ai-chatbot` | Next.js 15 + Vercel AI SDK 4 + TypeScript + Tailwind CSS 4 | AI chatbot interface |
| `mcp-server` | Node.js 22 + TypeScript + @modelcontextprotocol/sdk | MCP server for AI agents |
| `python-ml` | Python 3.13 + PyTorch + FastAPI + Docker | ML service with API |

### 8. Monorepo (6 templates)

| Template | Stack | Description |
|----------|-------|-------------|
| `turbo-next-nest` | Turborepo + Next.js 15 + NestJS 11 + Prisma 6 + TypeScript + Tailwind CSS 4 | Web + API monorepo |
| `turbo-next-hono` | Turborepo + Next.js 15 + Hono 4 + Drizzle + TypeScript + Tailwind CSS 4 | Lightweight fullstack monorepo |
| `turbo-next-expo` | Turborepo + Next.js 15 + Expo 52 + shared UI + TypeScript + Tailwind CSS 4 | Web + Mobile monorepo |
| `nx-angular-nest` | Nx + Angular 19 + NestJS 11 + Prisma 6 + TypeScript + Tailwind CSS 4 | Enterprise monorepo |
| `turbo-packages` | Turborepo + TypeScript + tsup + Changesets + Vitest | Package publishing monorepo |
| `turbo-saas` | Turborepo + Next.js 15 + Hono 4 + Drizzle + Stripe + NextAuth 5 + Tailwind CSS 4 | SaaS starter monorepo |

### 9. Infrastructure / DevOps (2 templates)

| Template | Stack | Description |
|----------|-------|-------------|
| `docker-compose` | Docker Compose + Nginx + PostgreSQL + Redis | Container infrastructure |
| `github-actions` | GitHub Actions CI/CD pipelines (lint, test, build, deploy) | CI/CD templates |

### 10. Serverless / Edge (3 templates)

| Template | Stack | Description |
|----------|-------|-------------|
| `cf-worker` | Cloudflare Workers + Hono 4 + TypeScript + D1/KV | Edge functions |
| `aws-lambda` | AWS SAM + Node.js 22 + TypeScript + DynamoDB | Serverless API |
| `vercel-functions` | Vercel Functions + TypeScript + Vercel KV/Postgres | Serverless on Vercel |

### 11. CMS / Admin (3 templates)

| Template | Stack | Description |
|----------|-------|-------------|
| `payload-cms` | Payload 3 + Next.js 15 + TypeScript + PostgreSQL | Headless CMS (self-hosted) |
| `strapi-app` | Strapi 5 + TypeScript + PostgreSQL | Headless CMS |
| `admin-refine` | Refine 4 + React 19 + Vite 6 + Ant Design + TypeScript | Admin panel |

### 12. E-commerce (2 templates)

| Template | Stack | Description |
|----------|-------|-------------|
| `medusa-store` | Medusa 2 + Next.js 15 Storefront + TypeScript + PostgreSQL | Open-source e-commerce |
| `shopify-hydrogen` | Hydrogen 2 + Remix + TypeScript + Tailwind CSS 4 | Shopify headless storefront |

### 13. Real-time / Bots (3 templates)

| Template | Stack | Description |
|----------|-------|-------------|
| `socket-chat` | Node.js 22 + Socket.io 4 + React 19 + TypeScript | Real-time chat |
| `discord-bot` | Discord.js 14 + TypeScript + Node.js 22 | Discord bot |
| `telegram-bot` | grammY + TypeScript + Node.js 22 | Telegram bot |

### 14. Documentation / Content (3 templates)

| Template | Stack | Description |
|----------|-------|-------------|
| `vitepress-docs` | VitePress 2 + Vue 3 + TypeScript | Documentation site |
| `docusaurus-docs` | Docusaurus 3 + React + TypeScript + MDX | Documentation site |
| `astro-blog` | Astro 5 + MDX + Tailwind CSS 4 + RSS + Sitemap | Blog / content site |

### 15. Email (1 template)

| Template | Stack | Description |
|----------|-------|-------------|
| `react-email` | React Email + TypeScript + Resend | Email templates |

### 16. Microservices (2 templates)

| Template | Stack | Description |
|----------|-------|-------------|
| `node-kafka` | Node.js 22 + KafkaJS + TypeScript + Docker Compose | Event-driven microservice |
| `node-grpc` | Node.js 22 + gRPC + TypeScript + Protobuf | gRPC service |

### 17. Web3 / Blockchain (2 templates)

| Template | Stack | Description |
|----------|-------|-------------|
| `web3-dapp` | Next.js 15 + wagmi 2 + viem + RainbowKit + TypeScript | dApp (EVM) |
| `hardhat-contracts` | Hardhat 2 + Solidity + TypeScript + Ethers.js v6 | Smart contracts |

### 18. Landing / Marketing (2 templates)

| Template | Stack | Description |
|----------|-------|-------------|
| `landing-page` | Next.js 15 + Tailwind CSS 4 + Framer Motion + TypeScript | Landing page with animations |
| `saas-landing` | Astro 5 + Tailwind CSS 4 + Stripe + TypeScript | SaaS marketing site |

### 19. Testing / QA (2 templates)

| Template | Stack | Description |
|----------|-------|-------------|
| `playwright-e2e` | Playwright + TypeScript + GitHub Actions | E2E testing |
| `storybook-ui` | Storybook 8 + React 19 + TypeScript + Tailwind CSS 4 | UI components + visual testing |

## What Each Template Includes

Every generated project comes with:

- Complete, working source code with example pages/routes/endpoints
- Properly configured `package.json` / `go.mod` / `pubspec.yaml` / `.csproj` etc.
- TypeScript / type safety where applicable
- `tsconfig.json` / `eslint.config.mjs` / `vitest.config.ts` where applicable
- `.gitignore` with comprehensive patterns
- `.editorconfig` for consistent formatting
- `.nvmrc` (Node.js projects)
- `docker-compose.yml` for database dependencies (where applicable)
- `.env.example` for projects requiring environment variables
- Initialized git repository

## Project Structure

```
monorepo-helper/
├── bin/
│   └── mh                          # CLI entry point
├── lib/
│   ├── colors.sh                   # Color/formatting utilities
│   └── utils.sh                    # Shared template utilities
├── templates/
│   ├── frontend/                   # 8 templates
│   │   ├── next-app.sh
│   │   ├── vite-react.sh
│   │   ├── vite-vue.sh
│   │   ├── nuxt-app.sh
│   │   ├── vite-svelte.sh
│   │   ├── sveltekit-app.sh
│   │   ├── astro-site.sh
│   │   └── remix-app.sh
│   ├── backend/                    # 10 templates
│   │   ├── node-express.sh
│   │   ├── node-fastify.sh
│   │   ├── node-hono.sh
│   │   ├── node-nestjs.sh
│   │   ├── node-graphql.sh
│   │   ├── bun-elysia.sh
│   │   ├── go-chi.sh
│   │   ├── go-fiber.sh
│   │   ├── python-fastapi.sh
│   │   └── python-django.sh
│   ├── fullstack/                  # 5 templates
│   ├── mobile/                     # 16 templates
│   ├── desktop/                    # 3 templates
│   ├── cli-library/                # 4 templates
│   ├── ai-ml/                      # 3 templates
│   ├── monorepo/                   # 6 templates
│   ├── infrastructure/             # 2 templates
│   ├── serverless/                 # 3 templates
│   ├── cms-admin/                  # 3 templates
│   ├── ecommerce/                  # 2 templates
│   ├── realtime/                   # 3 templates
│   ├── documentation/              # 3 templates
│   ├── email/                      # 1 template
│   ├── microservices/              # 2 templates
│   ├── web3/                       # 2 templates
│   ├── landing/                    # 2 templates
│   └── testing/                    # 2 templates
├── LICENSE
└── README.md
```

## How It Works

Each template is a self-contained bash script that:

1. Parses the project name argument (or uses a default)
2. Creates the project directory
3. Generates all necessary files with correct content
4. Initializes a git repository
5. Shows next steps (install & run commands)

No dependencies are installed automatically -- you control when to install.

## Prerequisites

- **Bash** 4.0+ (macOS ships with 3.x, install via `brew install bash`)
- **Git** for repository initialization
- Runtime-specific tools depending on the template:
  - **Node.js 22+** for JavaScript/TypeScript templates
  - **Bun 1.2+** for Bun templates
  - **Go 1.23+** for Go templates
  - **Python 3.13+** for Python templates
  - **Flutter 3.27+** for Flutter templates
  - **Rust** (via rustup) for Tauri templates
  - **.NET 9 SDK** for MAUI templates
  - **Xcode 16+** for Swift templates

## Examples

### Create a Next.js app

```bash
mh generate next-app my-saas
cd my-saas
npm install
npm run dev
```

### Create a fullstack monorepo

```bash
mh generate turbo-saas my-startup
cd my-startup
pnpm install
pnpm dev
```

### Create a REST API

```bash
mh generate node-hono my-api
cd my-api
npm install
docker-compose up -d  # start PostgreSQL
npm run dev
```

### Create a mobile app

```bash
mh generate expo-app my-mobile-app
cd my-mobile-app
npm install
npx expo start
```

### Create a Flutter app

```bash
mh generate flutter-app my-flutter-app
cd my-flutter-app
flutter pub get
flutter run
```

### Search for templates

```bash
$ mh search react

  vite-react [Frontend]
  Vite 6 + React 19 + TypeScript + Tailwind CSS 4

  remix-app [Frontend]
  React Router 7 (Remix) + React 19 + TypeScript + Tailwind CSS 4

  electron-react [Desktop]
  Electron 34 + React 19 + Vite 6 + TypeScript + Tailwind CSS 4
  ...

  Found: 12 template(s)
```

## Contributing

1. Fork the repo
2. Create a new template script in the appropriate `templates/<category>/` directory
3. Follow the existing script structure (source utils, parse_args, create_project_dir, etc.)
4. Register the template in `bin/mh` TEMPLATES array
5. Test: `mh generate your-template test-project && cd test-project && <install> && <dev>`
6. Submit a PR

### Template Script Structure

```bash
#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-default-name" "$@"
create_project_dir

# Generate files...
write_file "src/index.ts" 'console.log("hello")'

write_package_json '{
  "name": "'"$PROJECT_NAME"'",
  "version": "0.1.0",
  "scripts": { "dev": "..." }
}'

init_git
write_gitignore
write_editorconfig
write_nvmrc

finish "npm install" "npm run dev"
```

## License

MIT
