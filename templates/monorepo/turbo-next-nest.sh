#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-turbo-app" "$@"
header "Turborepo + Next.js 15 + NestJS 11 + Prisma 6 + Tailwind CSS 4"

create_project_dir

# ══════════════════════════════════════════════════════════════
# Root configuration
# ══════════════════════════════════════════════════════════════
section "Root configuration"

write_package_json '{
  "name": "'"$PROJECT_NAME"'",
  "private": true,
  "scripts": {
    "dev": "turbo dev",
    "build": "turbo build",
    "lint": "turbo lint",
    "db:generate": "turbo db:generate",
    "db:push": "turbo db:push"
  },
  "devDependencies": {
    "turbo": "^2.5.0"
  },
  "packageManager": "pnpm@10.8.0"
}'

write_file_heredoc "pnpm-workspace.yaml" << 'EOF'
packages:
  - "apps/*"
  - "packages/*"
EOF
success "Created pnpm-workspace.yaml"

write_file_heredoc "turbo.json" << 'EOF'
{
  "$schema": "https://turbo.build/schema.json",
  "tasks": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": [".next/**", "!.next/cache/**", "dist/**"]
    },
    "lint": {
      "dependsOn": ["^build"]
    },
    "dev": {
      "cache": false,
      "persistent": true
    },
    "db:generate": {
      "cache": false
    },
    "db:push": {
      "cache": false
    }
  }
}
EOF
success "Created turbo.json"

# ── docker-compose.yml ───────────────────────────────────────
write_file_heredoc "docker-compose.yml" << 'EOF'
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

# ══════════════════════════════════════════════════════════════
# packages/tsconfig
# ══════════════════════════════════════════════════════════════
section "packages/tsconfig"

mkdir -p packages/tsconfig

write_file_heredoc "packages/tsconfig/package.json" << 'EOF'
{
  "name": "@repo/tsconfig",
  "version": "0.0.0",
  "private": true,
  "files": ["*.json"]
}
EOF

write_file_heredoc "packages/tsconfig/base.json" << 'EOF'
{
  "compilerOptions": {
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "declaration": true,
    "declarationMap": true
  }
}
EOF

write_file_heredoc "packages/tsconfig/nextjs.json" << 'EOF'
{
  "extends": "./base.json",
  "compilerOptions": {
    "target": "ES2017",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "noEmit": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "jsx": "preserve",
    "incremental": true,
    "plugins": [{ "name": "next" }]
  }
}
EOF

write_file_heredoc "packages/tsconfig/node.json" << 'EOF'
{
  "extends": "./base.json",
  "compilerOptions": {
    "target": "ES2024",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "lib": ["ES2024"],
    "outDir": "dist",
    "sourceMap": true,
    "emitDecoratorMetadata": true,
    "experimentalDecorators": true
  }
}
EOF
success "Created packages/tsconfig"

# ══════════════════════════════════════════════════════════════
# packages/eslint-config
# ══════════════════════════════════════════════════════════════
section "packages/eslint-config"

mkdir -p packages/eslint-config

write_file_heredoc "packages/eslint-config/package.json" << 'EOF'
{
  "name": "@repo/eslint-config",
  "version": "0.0.0",
  "private": true,
  "type": "module",
  "dependencies": {
    "@eslint/js": "^9.24.0",
    "typescript-eslint": "^8.32.0"
  }
}
EOF

write_file_heredoc "packages/eslint-config/base.js" << 'EOF'
import js from "@eslint/js";
import tseslint from "typescript-eslint";

export default tseslint.config(
  js.configs.recommended,
  ...tseslint.configs.recommended,
  { ignores: ["dist/", "node_modules/", ".next/"] },
);
EOF
success "Created packages/eslint-config"

# ══════════════════════════════════════════════════════════════
# packages/shared
# ══════════════════════════════════════════════════════════════
section "packages/shared"

mkdir -p packages/shared/src

write_file_heredoc "packages/shared/package.json" << 'EOF'
{
  "name": "@repo/shared",
  "version": "0.0.0",
  "private": true,
  "type": "module",
  "main": "./src/index.ts",
  "types": "./src/index.ts",
  "scripts": {
    "lint": "eslint ."
  },
  "devDependencies": {
    "@repo/tsconfig": "workspace:*"
  }
}
EOF

write_file_heredoc "packages/shared/tsconfig.json" << 'EOF'
{
  "extends": "@repo/tsconfig/base.json",
  "compilerOptions": {
    "target": "ES2024",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "outDir": "dist",
    "rootDir": "src"
  },
  "include": ["src"]
}
EOF

write_file_heredoc "packages/shared/src/index.ts" << 'EOF'
export * from "./types.js";
EOF

write_file_heredoc "packages/shared/src/types.ts" << 'EOF'
export interface User {
  id: string;
  email: string;
  name: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface ApiResponse<T> {
  data: T;
  message?: string;
}

export interface PaginatedResponse<T> {
  data: T[];
  total: number;
  page: number;
  limit: number;
}
EOF
success "Created packages/shared"

# ══════════════════════════════════════════════════════════════
# packages/database (Prisma)
# ══════════════════════════════════════════════════════════════
section "packages/database"

mkdir -p packages/database/prisma packages/database/src

write_file_heredoc "packages/database/package.json" << 'EOF'
{
  "name": "@repo/database",
  "version": "0.0.0",
  "private": true,
  "type": "module",
  "main": "./src/index.ts",
  "types": "./src/index.ts",
  "scripts": {
    "db:generate": "prisma generate",
    "db:push": "prisma db push",
    "db:migrate": "prisma migrate dev",
    "db:studio": "prisma studio"
  },
  "dependencies": {
    "@prisma/client": "^6.5.0"
  },
  "devDependencies": {
    "@repo/tsconfig": "workspace:*",
    "prisma": "^6.5.0"
  }
}
EOF

write_file_heredoc "packages/database/tsconfig.json" << 'EOF'
{
  "extends": "@repo/tsconfig/base.json",
  "compilerOptions": {
    "target": "ES2024",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "outDir": "dist",
    "rootDir": "src"
  },
  "include": ["src"]
}
EOF

write_file_heredoc "packages/database/prisma/schema.prisma" << 'EOF'
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

write_file_heredoc "packages/database/src/index.ts" << 'EOF'
import { PrismaClient } from "@prisma/client";

const globalForPrisma = globalThis as unknown as {
  prisma: PrismaClient | undefined;
};

export const prisma =
  globalForPrisma.prisma ??
  new PrismaClient({
    log: process.env.NODE_ENV === "development" ? ["query", "error", "warn"] : ["error"],
  });

if (process.env.NODE_ENV !== "production") globalForPrisma.prisma = prisma;

export { PrismaClient };
export * from "@prisma/client";
EOF
success "Created packages/database"

# ══════════════════════════════════════════════════════════════
# apps/web (Next.js 15)
# ══════════════════════════════════════════════════════════════
section "apps/web (Next.js 15)"

mkdir -p apps/web/src/app apps/web/public

write_file_heredoc "apps/web/package.json" << 'EOF'
{
  "name": "@repo/web",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "next dev --turbopack --port 3000",
    "build": "next build",
    "start": "next start",
    "lint": "next lint"
  },
  "dependencies": {
    "@repo/shared": "workspace:*",
    "next": "^15.3.0",
    "react": "^19.1.0",
    "react-dom": "^19.1.0"
  },
  "devDependencies": {
    "@repo/tsconfig": "workspace:*",
    "@tailwindcss/postcss": "^4.1.3",
    "@types/node": "^22.14.0",
    "@types/react": "^19.1.0",
    "@types/react-dom": "^19.1.0",
    "eslint": "^9.24.0",
    "eslint-config-next": "^15.3.0",
    "tailwindcss": "^4.1.3",
    "typescript": "^5.8.3"
  }
}
EOF

write_file_heredoc "apps/web/tsconfig.json" << 'EOF'
{
  "extends": "@repo/tsconfig/nextjs.json",
  "compilerOptions": {
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
EOF

write_file "apps/web/next.config.ts" 'import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  transpilePackages: ["@repo/shared"],
};

export default nextConfig;'

write_file "apps/web/postcss.config.mjs" 'const config = {
  plugins: {
    "@tailwindcss/postcss": {},
  },
};

export default config;'

write_file "apps/web/src/app/globals.css" '@import "tailwindcss";'

write_file_heredoc "apps/web/src/app/layout.tsx" << 'EOF'
import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Web App",
  description: "Next.js web application",
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body className="antialiased">{children}</body>
    </html>
  );
}
EOF

write_file_heredoc "apps/web/src/app/page.tsx" << 'EOF'
export default function Home() {
  return (
    <div className="grid min-h-screen items-center justify-items-center p-8 sm:p-20">
      <main className="flex flex-col items-center gap-8">
        <h1 className="text-4xl font-bold tracking-tight sm:text-6xl">
          Turbo <span className="text-blue-600">Monorepo</span>
        </h1>
        <p className="text-lg text-gray-600 max-w-md text-center">
          Next.js + NestJS + Prisma + Tailwind CSS
        </p>
        <div className="flex gap-4">
          <a
            href="http://localhost:4000/api"
            className="rounded-full bg-blue-600 text-white px-6 py-3 text-sm font-medium hover:bg-blue-700 transition-colors"
          >
            API Docs
          </a>
        </div>
      </main>
    </div>
  );
}
EOF

write_file "apps/web/next-env.d.ts" '/// <reference types="next" />
/// <reference types="next/image-types/global" />'

success "Created apps/web"

# ══════════════════════════════════════════════════════════════
# apps/api (NestJS 11)
# ══════════════════════════════════════════════════════════════
section "apps/api (NestJS 11)"

mkdir -p apps/api/src/users

write_file_heredoc "apps/api/package.json" << 'EOF'
{
  "name": "@repo/api",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "nest start --watch",
    "build": "nest build",
    "start": "node dist/main.js",
    "lint": "eslint ."
  },
  "dependencies": {
    "@nestjs/common": "^11.1.0",
    "@nestjs/core": "^11.1.0",
    "@nestjs/platform-express": "^11.1.0",
    "@nestjs/swagger": "^11.1.0",
    "@repo/database": "workspace:*",
    "@repo/shared": "workspace:*",
    "class-transformer": "^0.5.1",
    "class-validator": "^0.14.1",
    "reflect-metadata": "^0.2.2",
    "rxjs": "^7.8.1"
  },
  "devDependencies": {
    "@nestjs/cli": "^11.0.0",
    "@repo/tsconfig": "workspace:*",
    "@types/node": "^22.14.0",
    "typescript": "^5.8.3"
  }
}
EOF

write_file_heredoc "apps/api/tsconfig.json" << 'EOF'
{
  "extends": "@repo/tsconfig/node.json",
  "compilerOptions": {
    "rootDir": "src",
    "outDir": "dist"
  },
  "include": ["src"]
}
EOF

write_file_heredoc "apps/api/nest-cli.json" << 'EOF'
{
  "$schema": "https://json.schemastore.org/nest-cli",
  "collection": "@nestjs/schematics",
  "sourceRoot": "src",
  "compilerOptions": {
    "deleteOutDir": true
  }
}
EOF

write_file_heredoc "apps/api/src/main.ts" << 'EOF'
import { NestFactory } from "@nestjs/core";
import { ValidationPipe } from "@nestjs/common";
import { SwaggerModule, DocumentBuilder } from "@nestjs/swagger";
import { AppModule } from "./app.module.js";

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.enableCors();
  app.setGlobalPrefix("api");
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));

  const config = new DocumentBuilder()
    .setTitle("API")
    .setDescription("REST API documentation")
    .setVersion("1.0")
    .build();
  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup("api", app, document);

  await app.listen(4000);
  console.log("API running on http://localhost:4000");
}

bootstrap();
EOF

write_file_heredoc "apps/api/src/app.module.ts" << 'EOF'
import { Module } from "@nestjs/common";
import { UsersModule } from "./users/users.module.js";

@Module({
  imports: [UsersModule],
})
export class AppModule {}
EOF

write_file_heredoc "apps/api/src/users/users.module.ts" << 'EOF'
import { Module } from "@nestjs/common";
import { UsersController } from "./users.controller.js";
import { UsersService } from "./users.service.js";

@Module({
  controllers: [UsersController],
  providers: [UsersService],
  exports: [UsersService],
})
export class UsersModule {}
EOF

write_file_heredoc "apps/api/src/users/users.service.ts" << 'EOF'
import { Injectable } from "@nestjs/common";
import { prisma } from "@repo/database";

@Injectable()
export class UsersService {
  async findAll() {
    return prisma.user.findMany({ include: { posts: true } });
  }

  async findOne(id: string) {
    return prisma.user.findUnique({ where: { id }, include: { posts: true } });
  }

  async create(data: { email: string; name?: string }) {
    return prisma.user.create({ data });
  }

  async delete(id: string) {
    return prisma.user.delete({ where: { id } });
  }
}
EOF

write_file_heredoc "apps/api/src/users/users.controller.ts" << 'EOF'
import { Controller, Get, Post, Delete, Param, Body, NotFoundException } from "@nestjs/common";
import { ApiTags, ApiOperation } from "@nestjs/swagger";
import { UsersService } from "./users.service.js";
import { CreateUserDto } from "./dto/create-user.dto.js";

@ApiTags("users")
@Controller("users")
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get()
  @ApiOperation({ summary: "List all users" })
  findAll() {
    return this.usersService.findAll();
  }

  @Get(":id")
  @ApiOperation({ summary: "Get a user by ID" })
  async findOne(@Param("id") id: string) {
    const user = await this.usersService.findOne(id);
    if (!user) throw new NotFoundException("User not found");
    return user;
  }

  @Post()
  @ApiOperation({ summary: "Create a new user" })
  create(@Body() dto: CreateUserDto) {
    return this.usersService.create(dto);
  }

  @Delete(":id")
  @ApiOperation({ summary: "Delete a user" })
  delete(@Param("id") id: string) {
    return this.usersService.delete(id);
  }
}
EOF

mkdir -p apps/api/src/users/dto

write_file_heredoc "apps/api/src/users/dto/create-user.dto.ts" << 'EOF'
import { IsEmail, IsOptional, IsString } from "class-validator";
import { ApiProperty } from "@nestjs/swagger";

export class CreateUserDto {
  @ApiProperty({ example: "user@example.com" })
  @IsEmail()
  email!: string;

  @ApiProperty({ example: "John Doe", required: false })
  @IsOptional()
  @IsString()
  name?: string;
}
EOF
success "Created apps/api"

# ── .env.example ──────────────────────────────────────────────
write_file_heredoc ".env.example" << 'EOF'
DATABASE_URL="postgresql://postgres:postgres@localhost:5432/app?schema=public"
EOF
success "Created .env.example"

# ── Finalize ──────────────────────────────────────────────────
section "Finalizing"
init_git
write_gitignore ".env" "prisma/*.db"
write_editorconfig
write_nvmrc

write_readme "$PROJECT_NAME" \
  "Turborepo monorepo with Next.js 15, NestJS 11, Prisma 6, and Tailwind CSS 4." \
  "pnpm install" \
  "pnpm dev"

finish "pnpm install" "docker compose up -d && pnpm dev"
