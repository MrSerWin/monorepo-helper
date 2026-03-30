#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-graphql-app" "$@"
header "Node.js + Apollo Server 4 + TypeScript + Pothos + Prisma + PostgreSQL"

create_project_dir

# ── package.json ──────────────────────────────────────────────
section "Package configuration"
write_package_json '{
  "name": "'"$PROJECT_NAME"'",
  "version": "0.0.1",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "tsx watch src/index.ts",
    "build": "tsc",
    "start": "node dist/index.js",
    "lint": "eslint .",
    "test": "vitest run",
    "db:generate": "prisma generate",
    "db:migrate": "prisma migrate dev",
    "db:push": "prisma db push",
    "db:studio": "prisma studio"
  },
  "dependencies": {
    "@apollo/server": "^4.12.0",
    "@pothos/core": "^4.6.0",
    "@pothos/plugin-prisma": "^4.4.0",
    "@prisma/client": "^6.9.0",
    "graphql": "^16.10.0",
    "dotenv": "^16.5.0"
  },
  "devDependencies": {
    "typescript": "^5.8.0",
    "tsx": "^4.19.0",
    "@types/node": "^22.15.0",
    "prisma": "^6.9.0",
    "eslint": "^9.27.0",
    "@eslint/js": "^9.27.0",
    "typescript-eslint": "^8.32.0",
    "vitest": "^3.2.0"
  }
}'

# ── TypeScript ────────────────────────────────────────────────
section "TypeScript configuration"
write_tsconfig '{
  "compilerOptions": {
    "target": "ES2024",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "lib": ["ES2024"],
    "outDir": "dist",
    "rootDir": "src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "declaration": true,
    "sourceMap": true
  },
  "include": ["src"],
  "exclude": ["node_modules", "dist"]
}'

# ── ESLint 9 ──────────────────────────────────────────────────
section "ESLint configuration"
write_file_heredoc eslint.config.js << 'EOF'
import js from "@eslint/js";
import tseslint from "typescript-eslint";

export default tseslint.config(
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    ignores: ["dist/", "node_modules/"],
  },
);
EOF
success "Created eslint.config.js"

# ── Prisma ────────────────────────────────────────────────────
section "Prisma schema"
mkdir -p prisma
write_file_heredoc prisma/schema.prisma << 'EOF'
generator client {
  provider = "prisma-client-js"
}

generator pothos {
  provider = "prisma-pothos-types"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id        String   @id @default(cuid())
  email     String   @unique
  name      String?
  posts     Post[]
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}

model Post {
  id        String   @id @default(cuid())
  title     String
  content   String?
  published Boolean  @default(false)
  author    User     @relation(fields: [authorId], references: [id])
  authorId  String
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}
EOF
success "Created prisma/schema.prisma"

# ── Docker Compose ────────────────────────────────────────────
section "Docker Compose"
write_file_heredoc docker-compose.yml << 'EOF'
services:
  postgres:
    image: postgres:17-alpine
    restart: unless-stopped
    ports:
      - "5432:5432"
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: app
    volumes:
      - pgdata:/var/lib/postgresql/data

volumes:
  pgdata:
EOF
success "Created docker-compose.yml"

# ── .env ──────────────────────────────────────────────────────
write_file_heredoc .env.example << 'EOF'
DATABASE_URL="postgresql://postgres:postgres@localhost:5432/app?schema=public"
PORT=4000
NODE_ENV=development
EOF
success "Created .env.example"
cp .env.example .env

# ── Source files ──────────────────────────────────────────────
section "Application source files"

mkdir -p src/schema src/types

# src/index.ts
write_file_heredoc src/index.ts << 'EOF'
import "dotenv/config";
import { ApolloServer } from "@apollo/server";
import { startStandaloneServer } from "@apollo/server/standalone";
import { schema } from "./schema/index.js";
import { prisma } from "./schema/builder.js";

export interface Context {
  prisma: typeof prisma;
}

async function main() {
  const server = new ApolloServer<Context>({ schema });

  const port = Number(process.env.PORT) || 4000;
  const { url } = await startStandaloneServer(server, {
    listen: { port },
    context: async () => ({ prisma }),
  });

  console.log(`GraphQL server ready at ${url}`);
}

main().catch(console.error);
EOF
success "Created src/index.ts"

# src/schema/builder.ts
write_file_heredoc src/schema/builder.ts << 'EOF'
import SchemaBuilder from "@pothos/core";
import PrismaPlugin from "@pothos/plugin-prisma";
import { PrismaClient } from "@prisma/client";
import type PrismaTypes from "@pothos/plugin-prisma/generated";

export const prisma = new PrismaClient();

export const builder = new SchemaBuilder<{
  PrismaTypes: PrismaTypes;
  Context: { prisma: typeof prisma };
}>({
  plugins: [PrismaPlugin],
  prisma: {
    client: prisma,
  },
});

builder.queryType({});
builder.mutationType({});
EOF
success "Created src/schema/builder.ts"

# src/types/user.ts
write_file_heredoc src/types/user.ts << 'EOF'
import { builder, prisma } from "../schema/builder.js";

builder.prismaObject("User", {
  fields: (t) => ({
    id: t.exposeID("id"),
    email: t.exposeString("email"),
    name: t.exposeString("name", { nullable: true }),
    posts: t.relation("posts"),
    createdAt: t.expose("createdAt", { type: "String" }),
  }),
});

builder.queryField("users", (t) =>
  t.prismaField({
    type: ["User"],
    resolve: (query) => prisma.user.findMany({ ...query }),
  }),
);

builder.queryField("user", (t) =>
  t.prismaField({
    type: "User",
    nullable: true,
    args: { id: t.arg.string({ required: true }) },
    resolve: (query, _root, args) =>
      prisma.user.findUnique({ ...query, where: { id: args.id } }),
  }),
);

builder.mutationField("createUser", (t) =>
  t.prismaField({
    type: "User",
    args: {
      email: t.arg.string({ required: true }),
      name: t.arg.string(),
    },
    resolve: (query, _root, args) =>
      prisma.user.create({
        ...query,
        data: { email: args.email, name: args.name },
      }),
  }),
);

builder.mutationField("deleteUser", (t) =>
  t.prismaField({
    type: "User",
    args: { id: t.arg.string({ required: true }) },
    resolve: (query, _root, args) =>
      prisma.user.delete({ ...query, where: { id: args.id } }),
  }),
);
EOF
success "Created src/types/user.ts"

# src/types/post.ts
write_file_heredoc src/types/post.ts << 'EOF'
import { builder, prisma } from "../schema/builder.js";

builder.prismaObject("Post", {
  fields: (t) => ({
    id: t.exposeID("id"),
    title: t.exposeString("title"),
    content: t.exposeString("content", { nullable: true }),
    published: t.exposeBoolean("published"),
    author: t.relation("author"),
    createdAt: t.expose("createdAt", { type: "String" }),
  }),
});

builder.queryField("posts", (t) =>
  t.prismaField({
    type: ["Post"],
    args: { published: t.arg.boolean() },
    resolve: (query, _root, args) =>
      prisma.post.findMany({
        ...query,
        where: args.published != null ? { published: args.published } : {},
      }),
  }),
);

builder.mutationField("createPost", (t) =>
  t.prismaField({
    type: "Post",
    args: {
      title: t.arg.string({ required: true }),
      content: t.arg.string(),
      authorId: t.arg.string({ required: true }),
    },
    resolve: (query, _root, args) =>
      prisma.post.create({
        ...query,
        data: {
          title: args.title,
          content: args.content,
          authorId: args.authorId,
        },
      }),
  }),
);
EOF
success "Created src/types/post.ts"

# src/schema/index.ts
write_file_heredoc src/schema/index.ts << 'EOF'
import { builder } from "./builder.js";
import "../types/user.js";
import "../types/post.js";

export const schema = builder.toSchema();
EOF
success "Created src/schema/index.ts"

# ── .nvmrc ────────────────────────────────────────────────────
write_nvmrc "22"

# ── Finalize ──────────────────────────────────────────────────
section "Finalizing"
write_gitignore ".env"
write_editorconfig
init_git

write_readme "$PROJECT_NAME" \
  "Node.js + Apollo Server 4 + Pothos + Prisma + PostgreSQL GraphQL API" \
  "npm install" \
  "npm run dev"

finish "npm install && npx prisma generate" "docker compose up -d && npm run dev"
