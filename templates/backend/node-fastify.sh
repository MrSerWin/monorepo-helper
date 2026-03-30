#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-fastify-app" "$@"
header "Node.js + Fastify 5 + TypeScript + Prisma + PostgreSQL + Swagger"

create_project_dir

# ── package.json ──────────────────────────────────────────────
section "Package configuration"
write_package_json '{
  "name": "'"$PROJECT_NAME"'",
  "version": "0.0.1",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "tsx watch src/server.ts",
    "build": "tsc",
    "start": "node dist/server.js",
    "lint": "eslint .",
    "test": "vitest run",
    "db:generate": "prisma generate",
    "db:migrate": "prisma migrate dev",
    "db:push": "prisma db push",
    "db:studio": "prisma studio"
  },
  "dependencies": {
    "fastify": "^5.3.0",
    "@fastify/cors": "^11.0.0",
    "@fastify/helmet": "^13.0.0",
    "@fastify/swagger": "^9.6.0",
    "@fastify/swagger-ui": "^5.3.0",
    "@fastify/type-provider-zod": "^4.1.0",
    "@prisma/client": "^6.9.0",
    "zod": "^3.24.0",
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
PORT=3000
NODE_ENV=development
EOF
success "Created .env.example"
cp .env.example .env

# ── Source files ──────────────────────────────────────────────
section "Application source files"

mkdir -p src/routes src/plugins

# src/server.ts
write_file_heredoc src/server.ts << 'EOF'
import "dotenv/config";
import Fastify from "fastify";
import cors from "@fastify/cors";
import helmet from "@fastify/helmet";
import { swaggerPlugin } from "./plugins/swagger.js";
import { prismaPlugin } from "./plugins/prisma.js";
import { userRoutes } from "./routes/user.js";

const app = Fastify({ logger: true });

async function main() {
  await app.register(cors);
  await app.register(helmet);
  await app.register(swaggerPlugin);
  await app.register(prismaPlugin);
  await app.register(userRoutes, { prefix: "/api/users" });

  app.get("/health", async () => {
    return { status: "ok", timestamp: new Date().toISOString() };
  });

  const port = Number(process.env.PORT) || 3000;
  await app.listen({ port, host: "0.0.0.0" });
}

main().catch((err) => {
  app.log.error(err);
  process.exit(1);
});
EOF
success "Created src/server.ts"

# src/plugins/swagger.ts
write_file_heredoc src/plugins/swagger.ts << 'EOF'
import fp from "fastify-plugin";
import swagger from "@fastify/swagger";
import swaggerUi from "@fastify/swagger-ui";
import type { FastifyInstance } from "fastify";

async function swaggerPluginFn(app: FastifyInstance) {
  await app.register(swagger, {
    openapi: {
      info: {
        title: "API",
        description: "API documentation",
        version: "0.1.0",
      },
    },
  });
  await app.register(swaggerUi, {
    routePrefix: "/docs",
  });
}

export const swaggerPlugin = fp(swaggerPluginFn, { name: "swagger" });
EOF
success "Created src/plugins/swagger.ts"

# src/plugins/prisma.ts
write_file_heredoc src/plugins/prisma.ts << 'EOF'
import fp from "fastify-plugin";
import { PrismaClient } from "@prisma/client";
import type { FastifyInstance } from "fastify";

declare module "fastify" {
  interface FastifyInstance {
    prisma: PrismaClient;
  }
}

async function prismaPluginFn(app: FastifyInstance) {
  const prisma = new PrismaClient();
  await prisma.$connect();

  app.decorate("prisma", prisma);

  app.addHook("onClose", async () => {
    await prisma.$disconnect();
  });
}

export const prismaPlugin = fp(prismaPluginFn, { name: "prisma" });
EOF
success "Created src/plugins/prisma.ts"

# src/routes/user.ts
write_file_heredoc src/routes/user.ts << 'EOF'
import type { FastifyInstance } from "fastify";

export async function userRoutes(app: FastifyInstance) {
  app.get("/", async () => {
    return app.prisma.user.findMany({ include: { posts: true } });
  });

  app.get<{ Params: { id: string } }>("/:id", async (request, reply) => {
    const user = await app.prisma.user.findUnique({
      where: { id: request.params.id },
      include: { posts: true },
    });
    if (!user) {
      return reply.status(404).send({ error: "User not found" });
    }
    return user;
  });

  app.post<{ Body: { email: string; name?: string } }>("/", async (request, reply) => {
    const user = await app.prisma.user.create({ data: request.body });
    return reply.status(201).send(user);
  });

  app.delete<{ Params: { id: string } }>("/:id", async (request, reply) => {
    await app.prisma.user.delete({ where: { id: request.params.id } });
    return reply.status(204).send();
  });
}
EOF
success "Created src/routes/user.ts"

# ── .nvmrc ────────────────────────────────────────────────────
write_nvmrc "22"

# ── Finalize ──────────────────────────────────────────────────
section "Finalizing"
write_gitignore ".env"
write_editorconfig
init_git

write_readme "$PROJECT_NAME" \
  "Node.js + Fastify 5 + TypeScript + Prisma + PostgreSQL API with Swagger docs" \
  "npm install" \
  "npm run dev"

finish "npm install && npx prisma generate" "docker compose up -d && npm run dev"
