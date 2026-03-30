#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-payload-app" "$@"
create_project_dir

# --- package.json ---
write_package_json '{
  "name": "'"$PROJECT_NAME"'",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "cross-env NODE_OPTIONS=--no-deprecation next dev --turbopack",
    "build": "cross-env NODE_OPTIONS=--no-deprecation next build",
    "start": "cross-env NODE_OPTIONS=--no-deprecation next start",
    "generate:types": "payload generate:types",
    "generate:schema": "payload-graphql generate:schema",
    "lint": "next lint"
  },
  "dependencies": {
    "@payloadcms/db-postgres": "^3.14.0",
    "@payloadcms/next": "^3.14.0",
    "@payloadcms/richtext-lexical": "^3.14.0",
    "@payloadcms/storage-local": "^3.14.0",
    "cross-env": "^7.0.3",
    "next": "^15.3.0",
    "payload": "^3.14.0",
    "react": "^19.1.0",
    "react-dom": "^19.1.0",
    "sharp": "^0.33.3"
  },
  "devDependencies": {
    "@types/node": "^22.14.0",
    "@types/react": "^19.1.0",
    "@types/react-dom": "^19.1.0",
    "eslint": "^9.24.0",
    "eslint-config-next": "^15.3.0",
    "typescript": "^5.8.3"
  }
}'

# --- next.config.mjs ---
write_file "next.config.mjs" 'import { withPayload } from "@payloadcms/next/withPayload";

/** @type {import("next").NextConfig} */
const nextConfig = {};

export default withPayload(nextConfig);'

# --- tsconfig.json ---
write_tsconfig '{
  "compilerOptions": {
    "target": "ES2017",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [
      { "name": "next" }
    ],
    "paths": {
      "@/*": ["./src/*"],
      "@payload-config": ["./src/payload.config.ts"]
    }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}'

# --- src/payload.config.ts ---
write_file "src/payload.config.ts" 'import path from "path";
import { fileURLToPath } from "url";
import { buildConfig } from "payload";
import { postgresAdapter } from "@payloadcms/db-postgres";
import { lexicalEditor } from "@payloadcms/richtext-lexical";
import { localStorageAdapter } from "@payloadcms/storage-local";
import { Users } from "./collections/Users";
import { Posts } from "./collections/Posts";
import { Media } from "./collections/Media";

const filename = fileURLToPath(import.meta.url);
const dirname = path.dirname(filename);

export default buildConfig({
  admin: {
    user: Users.slug,
    importMap: {
      baseDir: path.resolve(dirname),
    },
  },
  collections: [Users, Posts, Media],
  editor: lexicalEditor(),
  secret: process.env.PAYLOAD_SECRET || "CHANGE-ME-IN-PRODUCTION",
  typescript: {
    outputFile: path.resolve(dirname, "payload-types.ts"),
  },
  db: postgresAdapter({
    pool: {
      connectionString: process.env.DATABASE_URI || "",
    },
  }),
  plugins: [
    localStorageAdapter({
      collections: {
        media: true,
      },
      generateFileURL: ({ filename }) => {
        return `/media/${filename}`;
      },
    }),
  ],
});'

# --- src/collections/Users.ts ---
write_file "src/collections/Users.ts" 'import type { CollectionConfig } from "payload";

export const Users: CollectionConfig = {
  slug: "users",
  admin: {
    useAsTitle: "email",
  },
  auth: true,
  fields: [
    {
      name: "name",
      type: "text",
    },
    {
      name: "role",
      type: "select",
      options: [
        { label: "Admin", value: "admin" },
        { label: "Editor", value: "editor" },
        { label: "User", value: "user" },
      ],
      defaultValue: "user",
      required: true,
    },
  ],
};'

# --- src/collections/Posts.ts ---
write_file "src/collections/Posts.ts" 'import type { CollectionConfig } from "payload";

export const Posts: CollectionConfig = {
  slug: "posts",
  admin: {
    useAsTitle: "title",
  },
  access: {
    read: () => true,
  },
  fields: [
    {
      name: "title",
      type: "text",
      required: true,
    },
    {
      name: "slug",
      type: "text",
      required: true,
      unique: true,
      admin: {
        position: "sidebar",
      },
    },
    {
      name: "content",
      type: "richText",
    },
    {
      name: "featuredImage",
      type: "upload",
      relationTo: "media",
    },
    {
      name: "status",
      type: "select",
      options: [
        { label: "Draft", value: "draft" },
        { label: "Published", value: "published" },
      ],
      defaultValue: "draft",
      admin: {
        position: "sidebar",
      },
    },
    {
      name: "author",
      type: "relationship",
      relationTo: "users",
      admin: {
        position: "sidebar",
      },
    },
    {
      name: "publishedAt",
      type: "date",
      admin: {
        position: "sidebar",
      },
    },
  ],
};'

# --- src/collections/Media.ts ---
write_file "src/collections/Media.ts" 'import type { CollectionConfig } from "payload";

export const Media: CollectionConfig = {
  slug: "media",
  access: {
    read: () => true,
  },
  upload: {
    staticDir: "media",
    mimeTypes: ["image/*", "application/pdf"],
    imageSizes: [
      {
        name: "thumbnail",
        width: 300,
        height: 300,
        position: "centre",
      },
      {
        name: "card",
        width: 768,
        height: 1024,
        position: "centre",
      },
    ],
  },
  fields: [
    {
      name: "alt",
      type: "text",
      required: true,
    },
  ],
};'

# --- src/app/(frontend)/layout.tsx ---
write_file "src/app/(frontend)/layout.tsx" 'import type { Metadata } from "next";
import "../globals.css";

export const metadata: Metadata = {
  title: "'"$PROJECT_NAME"'",
  description: "Payload CMS + Next.js Application",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}'

# --- src/app/(frontend)/page.tsx ---
write_file "src/app/(frontend)/page.tsx" 'import { getPayload } from "payload";
import configPromise from "@payload-config";
import Link from "next/link";

export default async function Home() {
  const payload = await getPayload({ config: configPromise });
  const posts = await payload.find({
    collection: "posts",
    where: { status: { equals: "published" } },
    sort: "-publishedAt",
    limit: 10,
  });

  return (
    <main style={{ maxWidth: 800, margin: "0 auto", padding: "2rem" }}>
      <h1>'"$PROJECT_NAME"'</h1>
      <p>Powered by Payload CMS + Next.js</p>
      <h2>Latest Posts</h2>
      {posts.docs.length === 0 ? (
        <p>No published posts yet. <a href="/admin">Create one in the admin panel</a>.</p>
      ) : (
        <ul>
          {posts.docs.map((post) => (
            <li key={post.id}>
              <Link href={`/posts/${post.slug}`}>{post.title}</Link>
            </li>
          ))}
        </ul>
      )}
    </main>
  );
}'

# --- src/app/globals.css ---
write_file "src/app/globals.css" '*, *::before, *::after {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
}

body {
  font-family: system-ui, -apple-system, sans-serif;
  line-height: 1.6;
  color: #1a1a1a;
}'

# --- src/app/(payload)/admin/[[...segments]]/page.tsx ---
write_file "src/app/(payload)/admin/[[...segments]]/page.tsx" '/* THIS FILE WAS GENERATED AUTOMATICALLY BY PAYLOAD. */
/* DO NOT MODIFY IT BECAUSE IT COULD BE REWRITTEN AT ANY TIME. */
import type { AdminViewProps } from "payload";
import { DefaultTemplate } from "@payloadcms/next/templates";
import { importMap } from "../importMap";
import { RootPage, generatePageMetadata } from "@payloadcms/next/views";

type Args = {
  params: Promise<{ segments: string[] }>;
  searchParams: Promise<Record<string, string | string[]>>;
};

export const generateMetadata = ({ params, searchParams }: Args) =>
  generatePageMetadata({ config: configPromise, params, searchParams });

import configPromise from "@payload-config";

const Page = ({ params, searchParams }: Args) =>
  RootPage({ config: configPromise, params, searchParams, importMap });

export default Page;'

# --- src/app/(payload)/admin/importMap.js ---
write_file "src/app/(payload)/admin/importMap.js" '// This file is auto-generated by Payload
export const importMap = {};'

# --- src/app/(payload)/layout.tsx ---
write_file "src/app/(payload)/layout.tsx" 'import type { ServerComponentProps } from "payload";
import "@payloadcms/next/css";

export default function PayloadLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}'

# --- src/app/(payload)/api/[...slug]/route.ts ---
write_file "src/app/(payload)/api/[...slug]/route.ts" '/* THIS FILE WAS GENERATED AUTOMATICALLY BY PAYLOAD. */
/* DO NOT MODIFY IT BECAUSE IT COULD BE REWRITTEN AT ANY TIME. */
import configPromise from "@payload-config";
import "@payloadcms/next/css";
import {
  REST_DELETE,
  REST_GET,
  REST_OPTIONS,
  REST_PATCH,
  REST_POST,
  REST_PUT,
} from "@payloadcms/next/routes";

export const GET = REST_GET(configPromise);
export const POST = REST_POST(configPromise);
export const DELETE = REST_DELETE(configPromise);
export const PATCH = REST_PATCH(configPromise);
export const PUT = REST_PUT(configPromise);
export const OPTIONS = REST_OPTIONS(configPromise);'

# --- docker-compose.yml ---
write_file "docker-compose.yml" 'services:
  postgres:
    image: postgres:17-alpine
    restart: unless-stopped
    ports:
      - "5432:5432"
    environment:
      POSTGRES_USER: payload
      POSTGRES_PASSWORD: payload
      POSTGRES_DB: payload
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:'

# --- .env.example ---
write_file ".env.example" '# Database
DATABASE_URI=postgresql://payload:payload@localhost:5432/payload

# Payload
PAYLOAD_SECRET=your-secret-key-change-in-production

# Next.js
NEXT_PUBLIC_SERVER_URL=http://localhost:3000'

# --- next-env.d.ts ---
write_file "next-env.d.ts" '/// <reference types="next" />
/// <reference types="next/image-types/global" />

// NOTE: This file should not be edited
// see https://nextjs.org/docs/app/api-reference/config/typescript for more information.'

mkdir -p public media

init_git
write_gitignore "media/" "*.tsbuildinfo"
write_editorconfig
write_nvmrc

finish "npm install" "npm run dev"
