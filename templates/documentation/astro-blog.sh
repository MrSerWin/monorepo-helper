#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-astro-blog" "$@"
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
    "check": "astro check"
  },
  "dependencies": {
    "astro": "^5.7.0",
    "@astrojs/mdx": "^4.2.0",
    "@astrojs/rss": "^4.0.0",
    "@astrojs/sitemap": "^3.3.0",
    "@astrojs/tailwind": "^6.0.0",
    "tailwindcss": "^4.1.3",
    "@tailwindcss/vite": "^4.1.3"
  },
  "devDependencies": {
    "@types/node": "^22.14.0",
    "typescript": "^5.8.3"
  }
}'

# --- astro.config.mjs ---
write_file "astro.config.mjs" 'import { defineConfig } from "astro/config";
import mdx from "@astrojs/mdx";
import sitemap from "@astrojs/sitemap";
import tailwindcss from "@tailwindcss/vite";

export default defineConfig({
  site: "https://your-site.com",
  integrations: [mdx(), sitemap()],
  vite: {
    plugins: [tailwindcss()],
  },
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

# --- src/styles/global.css ---
write_file "src/styles/global.css" '@import "tailwindcss";

@theme {
  --color-primary: #3b82f6;
  --color-primary-dark: #2563eb;
}

:root {
  --font-sans: "Inter", system-ui, -apple-system, sans-serif;
}

body {
  font-family: var(--font-sans);
}'

# --- src/content.config.ts ---
write_file "src/content.config.ts" 'import { defineCollection, z } from "astro:content";
import { glob } from "astro/loaders";

const blog = defineCollection({
  loader: glob({ pattern: "**/*.{md,mdx}", base: "./src/content/blog" }),
  schema: z.object({
    title: z.string(),
    description: z.string(),
    pubDate: z.coerce.date(),
    updatedDate: z.coerce.date().optional(),
    heroImage: z.string().optional(),
    tags: z.array(z.string()).default([]),
  }),
});

export const collections = { blog };'

# --- src/content/blog/first-post.mdx ---
write_file "src/content/blog/first-post.mdx" '---
title: "Getting Started with Astro"
description: "Learn how to build a blazing fast blog with Astro and MDX."
pubDate: 2025-01-15
tags: ["astro", "tutorial"]
---

# Getting Started with Astro

Welcome to your new **Astro** blog! This post is written in MDX, so you can use
React-like components right inside your Markdown.

## Why Astro?

- **Zero JS by default** - Ship only the JavaScript you need
- **Content Collections** - Type-safe content management
- **MDX Support** - Use components in your Markdown
- **Fast builds** - Built on Vite for speed

## Code Example

```typescript
const greeting: string = "Hello, Astro!";
console.log(greeting);
```

## What'\''s Next?

Check out the [Astro documentation](https://docs.astro.build) to learn more.
'

# --- src/content/blog/second-post.mdx ---
write_file "src/content/blog/second-post.mdx" '---
title: "Styling with Tailwind CSS"
description: "How to use Tailwind CSS 4 with your Astro blog."
pubDate: 2025-02-01
tags: ["tailwind", "css"]
---

# Styling with Tailwind CSS

Tailwind CSS 4 brings a new CSS-first configuration approach.

## Key Features

- **CSS-first config** - Configure directly in CSS
- **Lightning CSS** - Faster builds with the new engine
- **Simplified setup** - Less boilerplate needed

## Example

```html
<div class="flex items-center gap-4 rounded-lg bg-white p-6 shadow-lg">
  <h2 class="text-xl font-bold">Card Title</h2>
  <p class="text-gray-600">Card description goes here.</p>
</div>
```
'

# --- src/layouts/BlogPost.astro ---
write_file "src/layouts/BlogPost.astro" '---
import BaseLayout from "./BaseLayout.astro";

interface Props {
  title: string;
  description: string;
  pubDate: Date;
  updatedDate?: Date;
  heroImage?: string;
}

const { title, description, pubDate, updatedDate, heroImage } = Astro.props;
---

<BaseLayout title={title} description={description}>
  <article class="mx-auto max-w-3xl px-4 py-12">
    <header class="mb-8">
      {heroImage && <img src={heroImage} alt={title} class="mb-6 w-full rounded-lg" />}
      <h1 class="text-4xl font-bold tracking-tight">{title}</h1>
      <div class="mt-2 flex items-center gap-2 text-gray-500">
        <time datetime={pubDate.toISOString()}>
          {pubDate.toLocaleDateString("en-us", { year: "numeric", month: "long", day: "numeric" })}
        </time>
        {updatedDate && (
          <span>
            (Updated: <time datetime={updatedDate.toISOString()}>
              {updatedDate.toLocaleDateString("en-us", { year: "numeric", month: "long", day: "numeric" })}
            </time>)
          </span>
        )}
      </div>
    </header>
    <div class="prose prose-lg max-w-none">
      <slot />
    </div>
  </article>
</BaseLayout>'

# --- src/layouts/BaseLayout.astro ---
write_file "src/layouts/BaseLayout.astro" '---
import "../styles/global.css";
import Header from "../components/Header.astro";
import Footer from "../components/Footer.astro";

interface Props {
  title: string;
  description?: string;
}

const { title, description = "An Astro blog" } = Astro.props;
---

<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <meta name="description" content={description} />
    <link rel="icon" type="image/svg+xml" href="/favicon.svg" />
    <title>{title}</title>
  </head>
  <body class="min-h-screen bg-white text-gray-900">
    <Header />
    <main>
      <slot />
    </main>
    <Footer />
  </body>
</html>'

# --- src/components/Header.astro ---
write_file "src/components/Header.astro" '---
const navItems = [
  { label: "Home", href: "/" },
  { label: "Blog", href: "/blog" },
];
---

<header class="border-b border-gray-200 bg-white">
  <nav class="mx-auto flex max-w-4xl items-center justify-between px-4 py-4">
    <a href="/" class="text-xl font-bold">'"$PROJECT_NAME"'</a>
    <ul class="flex gap-6">
      {navItems.map((item) => (
        <li>
          <a href={item.href} class="text-gray-600 transition-colors hover:text-gray-900">
            {item.label}
          </a>
        </li>
      ))}
    </ul>
  </nav>
</header>'

# --- src/components/Footer.astro ---
write_file "src/components/Footer.astro" '<footer class="mt-16 border-t border-gray-200 py-8">
  <div class="mx-auto max-w-4xl px-4 text-center text-gray-500">
    <p>&copy; {new Date().getFullYear()} '"$PROJECT_NAME"'. Built with Astro.</p>
  </div>
</footer>'

# --- src/components/BlogCard.astro ---
write_file "src/components/BlogCard.astro" '---
interface Props {
  title: string;
  description: string;
  pubDate: Date;
  slug: string;
}

const { title, description, pubDate, slug } = Astro.props;
---

<article class="rounded-lg border border-gray-200 p-6 transition-shadow hover:shadow-md">
  <a href={`/blog/${slug}`} class="block">
    <h2 class="text-xl font-semibold">{title}</h2>
    <p class="mt-2 text-gray-600">{description}</p>
    <time datetime={pubDate.toISOString()} class="mt-3 block text-sm text-gray-400">
      {pubDate.toLocaleDateString("en-us", { year: "numeric", month: "long", day: "numeric" })}
    </time>
  </a>
</article>'

# --- src/pages/index.astro ---
write_file "src/pages/index.astro" '---
import BaseLayout from "../layouts/BaseLayout.astro";
import BlogCard from "../components/BlogCard.astro";
import { getCollection } from "astro:content";

const posts = (await getCollection("blog")).sort(
  (a, b) => b.data.pubDate.valueOf() - a.data.pubDate.valueOf()
);
---

<BaseLayout title="'"$PROJECT_NAME"'">
  <section class="mx-auto max-w-4xl px-4 py-16">
    <h1 class="text-5xl font-bold tracking-tight">Welcome</h1>
    <p class="mt-4 text-xl text-gray-600">
      A blog built with Astro, MDX, and Tailwind CSS.
    </p>
  </section>
  <section class="mx-auto max-w-4xl px-4 pb-16">
    <h2 class="mb-8 text-2xl font-bold">Latest Posts</h2>
    <div class="grid gap-6 sm:grid-cols-2">
      {posts.map((post) => (
        <BlogCard
          title={post.data.title}
          description={post.data.description}
          pubDate={post.data.pubDate}
          slug={post.id}
        />
      ))}
    </div>
  </section>
</BaseLayout>'

# --- src/pages/blog/[...slug].astro ---
write_file "src/pages/blog/[...slug].astro" '---
import { getCollection, render } from "astro:content";
import BlogPost from "../../layouts/BlogPost.astro";

export async function getStaticPaths() {
  const posts = await getCollection("blog");
  return posts.map((post) => ({
    params: { slug: post.id },
    props: post,
  }));
}

const post = Astro.props;
const { Content } = await render(post);
---

<BlogPost {...post.data}>
  <Content />
</BlogPost>'

# --- src/pages/rss.xml.ts ---
write_file "src/pages/rss.xml.ts" 'import rss from "@astrojs/rss";
import { getCollection } from "astro:content";
import type { APIContext } from "astro";

export async function GET(context: APIContext) {
  const posts = await getCollection("blog");
  return rss({
    title: "'"$PROJECT_NAME"'",
    description: "A blog built with Astro",
    site: context.site!,
    items: posts.map((post) => ({
      title: post.data.title,
      pubDate: post.data.pubDate,
      description: post.data.description,
      link: `/blog/${post.id}/`,
    })),
  });
}'

# --- public/ ---
write_file "public/favicon.svg" '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 128 128"><path fill="#3b82f6" d="M64 0C28.7 0 0 28.7 0 64s28.7 64 64 64 64-28.7 64-64S99.3 0 64 0zm0 110c-25.4 0-46-20.6-46-46S38.6 18 64 18s46 20.6 46 46-20.6 46-46 46z"/></svg>'

init_git
write_gitignore ".astro/"
write_editorconfig
write_nvmrc

finish "npm install" "npm run dev"
