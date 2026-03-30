#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-docusaurus-docs" "$@"
create_project_dir

# --- package.json ---
write_package_json '{
  "name": "'"$PROJECT_NAME"'",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "docusaurus start",
    "build": "docusaurus build",
    "serve": "docusaurus serve",
    "clear": "docusaurus clear",
    "typecheck": "tsc --noEmit"
  },
  "dependencies": {
    "@docusaurus/core": "^3.7.0",
    "@docusaurus/preset-classic": "^3.7.0",
    "@mdx-js/react": "^3.1.0",
    "clsx": "^2.1.1",
    "prism-react-renderer": "^2.4.1",
    "react": "^19.1.0",
    "react-dom": "^19.1.0"
  },
  "devDependencies": {
    "@docusaurus/module-type-aliases": "^3.7.0",
    "@docusaurus/tsconfig": "^3.7.0",
    "@docusaurus/types": "^3.7.0",
    "typescript": "^5.8.3"
  },
  "browserslist": {
    "production": [">0.5%", "not dead", "not op_mini all"],
    "development": ["last 3 chrome version", "last 3 firefox version", "last 5 safari version"]
  }
}'

# --- docusaurus.config.ts ---
write_file "docusaurus.config.ts" 'import { themes as prismThemes } from "prism-react-renderer";
import type { Config } from "@docusaurus/types";
import type * as Preset from "@docusaurus/preset-classic";

const config: Config = {
  title: "'"$PROJECT_NAME"'",
  tagline: "Documentation powered by Docusaurus",
  favicon: "img/favicon.ico",
  url: "https://your-site.com",
  baseUrl: "/",
  organizationName: "your-org",
  projectName: "'"$PROJECT_NAME"'",
  onBrokenLinks: "throw",
  onBrokenMarkdownLinks: "warn",
  i18n: {
    defaultLocale: "en",
    locales: ["en"],
  },
  presets: [
    [
      "classic",
      {
        docs: {
          sidebarPath: "./sidebars.ts",
          editUrl: "https://github.com/your-org/your-repo/tree/main/",
        },
        blog: {
          showReadingTime: true,
          editUrl: "https://github.com/your-org/your-repo/tree/main/",
        },
        theme: {
          customCss: "./src/css/custom.css",
        },
      } satisfies Preset.Options,
    ],
  ],
  themeConfig: {
    navbar: {
      title: "'"$PROJECT_NAME"'",
      items: [
        { type: "docSidebar", sidebarId: "docsSidebar", position: "left", label: "Docs" },
        { to: "/blog", label: "Blog", position: "left" },
        { href: "https://github.com/your-org/your-repo", label: "GitHub", position: "right" },
      ],
    },
    footer: {
      style: "dark",
      links: [
        {
          title: "Docs",
          items: [{ label: "Introduction", to: "/docs/intro" }],
        },
        {
          title: "Community",
          items: [{ label: "GitHub", href: "https://github.com/your-org/your-repo" }],
        },
      ],
      copyright: `Copyright \u00a9 ${new Date().getFullYear()} Your Organization.`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
    },
  } satisfies Preset.ThemeConfig,
};

export default config;'

# --- sidebars.ts ---
write_file "sidebars.ts" 'import type { SidebarsConfig } from "@docusaurus/plugin-content-docs";

const sidebars: SidebarsConfig = {
  docsSidebar: [
    "intro",
    "getting-started",
  ],
};

export default sidebars;'

# --- tsconfig.json ---
write_tsconfig '{
  "extends": "@docusaurus/tsconfig",
  "compilerOptions": {
    "baseUrl": ".",
    "jsx": "react-jsx"
  }
}'

# --- docs/intro.md ---
write_file "docs/intro.md" '---
sidebar_position: 1
---

# Introduction

Welcome to the **'"$PROJECT_NAME"'** documentation.

## What You'\''ll Find Here

- **Getting Started** - Set up and run the project
- **API Reference** - Detailed API documentation
- **Blog** - Latest updates and tutorials

## Quick Links

- [Getting Started](./getting-started)
'

# --- docs/getting-started.md ---
write_file "docs/getting-started.md" '---
sidebar_position: 2
---

# Getting Started

## Prerequisites

- Node.js 22 or later
- npm, yarn, or pnpm

## Installation

```bash
npm install
```

## Development

```bash
npm run dev
```

Visit `http://localhost:3000` to see the site.

## Building

```bash
npm run build
```

## Project Structure

```
├── docs/              # Markdown documentation
├── blog/              # Blog posts
├── src/
│   ├── components/    # React components
│   ├── css/           # Custom styles
│   └── pages/         # Custom pages
├── static/            # Static assets
├── docusaurus.config.ts
└── sidebars.ts
```
'

# --- blog/2025-01-01-welcome.md ---
write_file "blog/2025-01-01-welcome.md" '---
slug: welcome
title: Welcome to the Blog
authors:
  - name: Author
    title: Developer
tags: [welcome, introduction]
---

Welcome to the blog! This is your first blog post.

<!-- truncate -->

## Getting Started with the Blog

You can write blog posts in Markdown. Each post supports:

- **Front matter** for metadata
- **Tags** for categorization
- **Authors** information
- **Reading time** estimation

Check the [Docusaurus blog documentation](https://docusaurus.io/docs/blog) for more details.
'

# --- src/pages/index.tsx ---
write_file "src/pages/index.tsx" 'import clsx from "clsx";
import Link from "@docusaurus/Link";
import useDocusaurusContext from "@docusaurus/useDocusaurusContext";
import Layout from "@theme/Layout";
import styles from "./index.module.css";

function HomepageHeader() {
  const { siteConfig } = useDocusaurusContext();
  return (
    <header className={clsx("hero hero--primary", styles.heroBanner)}>
      <div className="container">
        <h1 className="hero__title">{siteConfig.title}</h1>
        <p className="hero__subtitle">{siteConfig.tagline}</p>
        <div className={styles.buttons}>
          <Link className="button button--secondary button--lg" to="/docs/intro">
            Get Started
          </Link>
        </div>
      </div>
    </header>
  );
}

export default function Home(): JSX.Element {
  const { siteConfig } = useDocusaurusContext();
  return (
    <Layout title="Home" description={siteConfig.tagline}>
      <HomepageHeader />
      <main>
        <section className={styles.features}>
          <div className="container">
            <div className="row">
              <div className="col col--4">
                <div className="text--center padding-horiz--md">
                  <h3>Easy to Use</h3>
                  <p>Get started quickly with minimal configuration.</p>
                </div>
              </div>
              <div className="col col--4">
                <div className="text--center padding-horiz--md">
                  <h3>MDX Support</h3>
                  <p>Write docs in Markdown with React components.</p>
                </div>
              </div>
              <div className="col col--4">
                <div className="text--center padding-horiz--md">
                  <h3>TypeScript</h3>
                  <p>Full TypeScript support out of the box.</p>
                </div>
              </div>
            </div>
          </div>
        </section>
      </main>
    </Layout>
  );
}'

# --- src/pages/index.module.css ---
write_file "src/pages/index.module.css" '.heroBanner {
  padding: 4rem 0;
  text-align: center;
  position: relative;
  overflow: hidden;
}

.buttons {
  display: flex;
  align-items: center;
  justify-content: center;
}

.features {
  display: flex;
  align-items: center;
  padding: 2rem 0;
  width: 100%;
}'

# --- src/css/custom.css ---
write_file "src/css/custom.css" ':root {
  --ifm-color-primary: #2e8555;
  --ifm-color-primary-dark: #29784c;
  --ifm-color-primary-darker: #277148;
  --ifm-color-primary-darkest: #205d3b;
  --ifm-color-primary-light: #33925d;
  --ifm-color-primary-lighter: #359962;
  --ifm-color-primary-lightest: #3cad6e;
  --ifm-code-font-size: 95%;
  --docusaurus-highlighted-code-line-bg: rgba(0, 0, 0, 0.1);
}

[data-theme="dark"] {
  --ifm-color-primary: #25c2a0;
  --ifm-color-primary-dark: #21af90;
  --ifm-color-primary-darker: #1fa588;
  --ifm-color-primary-darkest: #1a8870;
  --ifm-color-primary-light: #29d5b0;
  --ifm-color-primary-lighter: #32d8b4;
  --ifm-color-primary-lightest: #4fddbf;
  --docusaurus-highlighted-code-line-bg: rgba(0, 0, 0, 0.3);
}'

# --- src/components/.gitkeep ---
write_file "src/components/.gitkeep" ""

# --- static/.gitkeep ---
write_file "static/.gitkeep" ""

init_git
write_gitignore ".docusaurus/" "build/"
write_editorconfig
write_nvmrc

finish "npm install" "npm run dev"
