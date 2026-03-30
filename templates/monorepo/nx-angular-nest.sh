#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-nx-app" "$@"
header "Nx + Angular 19 + NestJS 11 + Prisma 6 + Tailwind CSS 4"

create_project_dir

# ══════════════════════════════════════════════════════════════
# Root configuration
# ══════════════════════════════════════════════════════════════
section "Root configuration"

write_package_json '{
  "name": "'"$PROJECT_NAME"'",
  "private": true,
  "scripts": {
    "dev": "npx nx run-many --target=serve --all",
    "dev:web": "npx nx serve web",
    "dev:api": "npx nx serve api",
    "build": "npx nx run-many --target=build --all",
    "lint": "npx nx run-many --target=lint --all",
    "test": "npx nx run-many --target=test --all",
    "db:generate": "npx prisma generate --schema=libs/shared/prisma/schema.prisma",
    "db:push": "npx prisma db push --schema=libs/shared/prisma/schema.prisma",
    "db:migrate": "npx prisma migrate dev --schema=libs/shared/prisma/schema.prisma"
  },
  "dependencies": {
    "@angular/animations": "^19.2.0",
    "@angular/common": "^19.2.0",
    "@angular/compiler": "^19.2.0",
    "@angular/core": "^19.2.0",
    "@angular/forms": "^19.2.0",
    "@angular/platform-browser": "^19.2.0",
    "@angular/platform-browser-dynamic": "^19.2.0",
    "@angular/router": "^19.2.0",
    "@nestjs/common": "^11.1.0",
    "@nestjs/core": "^11.1.0",
    "@nestjs/platform-express": "^11.1.0",
    "@nestjs/swagger": "^11.1.0",
    "@prisma/client": "^6.5.0",
    "class-transformer": "^0.5.1",
    "class-validator": "^0.14.1",
    "reflect-metadata": "^0.2.2",
    "rxjs": "^7.8.1",
    "tslib": "^2.8.0",
    "zone.js": "^0.15.0"
  },
  "devDependencies": {
    "@angular/build": "^19.2.0",
    "@angular/cli": "^19.2.0",
    "@angular/compiler-cli": "^19.2.0",
    "@nx/angular": "^21.1.0",
    "@nx/js": "^21.1.0",
    "@nx/nest": "^21.1.0",
    "@nx/node": "^21.1.0",
    "@tailwindcss/postcss": "^4.1.3",
    "@types/node": "^22.14.0",
    "nx": "^21.1.0",
    "prisma": "^6.5.0",
    "tailwindcss": "^4.1.3",
    "typescript": "^5.8.3"
  }
}'

write_file_heredoc "nx.json" << 'EOF'
{
  "$schema": "./node_modules/nx/schemas/nx-schema.json",
  "namedInputs": {
    "default": ["{projectRoot}/**/*", "sharedGlobals"],
    "sharedGlobals": [],
    "production": ["default", "!{projectRoot}/**/*.spec.ts"]
  },
  "targetDefaults": {
    "build": {
      "dependsOn": ["^build"],
      "cache": true
    },
    "lint": {
      "cache": true
    },
    "test": {
      "cache": true
    }
  },
  "defaultBase": "main"
}
EOF
success "Created nx.json"

write_file_heredoc "tsconfig.base.json" << 'EOF'
{
  "compilerOptions": {
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "moduleResolution": "bundler",
    "target": "ES2022",
    "module": "ES2022",
    "lib": ["ES2022"],
    "declaration": true,
    "declarationMap": true,
    "paths": {
      "@repo/shared": ["libs/shared/src/index.ts"]
    }
  }
}
EOF
success "Created tsconfig.base.json"

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

write_file_heredoc ".env.example" << 'EOF'
DATABASE_URL="postgresql://postgres:postgres@localhost:5432/app?schema=public"
EOF
success "Created .env.example"

# ══════════════════════════════════════════════════════════════
# libs/shared
# ══════════════════════════════════════════════════════════════
section "libs/shared"
mkdir -p libs/shared/src libs/shared/prisma

write_file_heredoc "libs/shared/project.json" << 'EOF'
{
  "name": "shared",
  "$schema": "../../node_modules/nx/schemas/project-schema.json",
  "sourceRoot": "libs/shared/src",
  "projectType": "library",
  "tags": ["scope:shared"]
}
EOF

write_file_heredoc "libs/shared/tsconfig.json" << 'EOF'
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": {
    "outDir": "../../dist/libs/shared",
    "declaration": true,
    "declarationMap": true,
    "target": "ES2022",
    "module": "ES2022"
  },
  "include": ["src/**/*.ts"]
}
EOF

write_file_heredoc "libs/shared/src/index.ts" << 'EOF'
export * from "./types.js";
export * from "./database.js";
EOF

write_file_heredoc "libs/shared/src/types.ts" << 'EOF'
export interface User {
  id: string;
  email: string;
  name: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface Post {
  id: string;
  title: string;
  content: string | null;
  published: boolean;
  authorId: string;
  createdAt: Date;
  updatedAt: Date;
}

export interface ApiResponse<T> {
  data: T;
  message?: string;
}
EOF

write_file_heredoc "libs/shared/src/database.ts" << 'EOF'
import { PrismaClient } from "@prisma/client";

const globalForPrisma = globalThis as unknown as {
  prisma: PrismaClient | undefined;
};

export const prisma =
  globalForPrisma.prisma ??
  new PrismaClient({
    log: process.env["NODE_ENV"] === "development" ? ["query", "error", "warn"] : ["error"],
  });

if (process.env["NODE_ENV"] !== "production") globalForPrisma.prisma = prisma;

export { PrismaClient };
EOF

write_file_heredoc "libs/shared/prisma/schema.prisma" << 'EOF'
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
success "Created libs/shared"

# ══════════════════════════════════════════════════════════════
# apps/web (Angular 19)
# ══════════════════════════════════════════════════════════════
section "apps/web (Angular 19)"
mkdir -p apps/web/src/app/components apps/web/public

write_file_heredoc "apps/web/project.json" << 'EOF'
{
  "name": "web",
  "$schema": "../../node_modules/nx/schemas/project-schema.json",
  "projectType": "application",
  "sourceRoot": "apps/web/src",
  "prefix": "app",
  "targets": {
    "build": {
      "executor": "@angular/build:application",
      "outputs": ["{options.outputPath}"],
      "options": {
        "outputPath": "dist/apps/web",
        "index": "apps/web/src/index.html",
        "browser": "apps/web/src/main.ts",
        "tsConfig": "apps/web/tsconfig.app.json",
        "styles": ["apps/web/src/styles.css"],
        "scripts": []
      },
      "configurations": {
        "production": {
          "budgets": [
            { "type": "initial", "maximumWarning": "500kB", "maximumError": "1MB" }
          ],
          "outputHashing": "all"
        },
        "development": {
          "optimization": false,
          "extractLicenses": false,
          "sourceMap": true
        }
      },
      "defaultConfiguration": "production"
    },
    "serve": {
      "executor": "@angular/build:dev-server",
      "configurations": {
        "production": { "buildTarget": "web:build:production" },
        "development": { "buildTarget": "web:build:development" }
      },
      "defaultConfiguration": "development",
      "options": {
        "port": 4200,
        "proxyConfig": "apps/web/proxy.conf.json"
      }
    },
    "lint": {
      "executor": "@nx/js:tsc",
      "options": {
        "tsConfig": "apps/web/tsconfig.app.json"
      }
    }
  },
  "tags": ["scope:web"]
}
EOF

write_file_heredoc "apps/web/tsconfig.json" << 'EOF'
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": {
    "target": "ES2022",
    "module": "ES2022",
    "lib": ["ES2022", "dom"],
    "outDir": "../../dist/out-tsc"
  },
  "references": [
    { "path": "./tsconfig.app.json" }
  ]
}
EOF

write_file_heredoc "apps/web/tsconfig.app.json" << 'EOF'
{
  "extends": "./tsconfig.json",
  "compilerOptions": {
    "outDir": "../../dist/out-tsc",
    "types": []
  },
  "files": ["src/main.ts"],
  "include": ["src/**/*.d.ts", "src/**/*.ts"]
}
EOF

write_file_heredoc "apps/web/proxy.conf.json" << 'EOF'
{
  "/api": {
    "target": "http://localhost:4000",
    "secure": false
  }
}
EOF

write_file "apps/web/postcss.config.mjs" 'const config = {
  plugins: {
    "@tailwindcss/postcss": {},
  },
};

export default config;'

write_file "apps/web/src/styles.css" '@import "tailwindcss";'

write_file_heredoc "apps/web/src/index.html" << 'EOF'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Web App</title>
  <base href="/">
  <meta name="viewport" content="width=device-width, initial-scale=1">
</head>
<body class="antialiased bg-gray-50">
  <app-root></app-root>
</body>
</html>
EOF

write_file_heredoc "apps/web/src/main.ts" << 'EOF'
import { bootstrapApplication } from "@angular/platform-browser";
import { provideRouter } from "@angular/router";
import { provideHttpClient } from "@angular/common/http";
import { AppComponent } from "./app/app.component.js";
import { routes } from "./app/app.routes.js";

bootstrapApplication(AppComponent, {
  providers: [
    provideRouter(routes),
    provideHttpClient(),
  ],
}).catch((err) => console.error(err));
EOF

write_file_heredoc "apps/web/src/app/app.component.ts" << 'EOF'
import { Component } from "@angular/core";
import { RouterOutlet } from "@angular/router";

@Component({
  selector: "app-root",
  standalone: true,
  imports: [RouterOutlet],
  template: `
    <div class="min-h-screen">
      <router-outlet />
    </div>
  `,
})
export class AppComponent {
  title = "Web App";
}
EOF

write_file_heredoc "apps/web/src/app/app.routes.ts" << 'EOF'
import { Routes } from "@angular/router";
import { HomeComponent } from "./components/home.component.js";

export const routes: Routes = [
  { path: "", component: HomeComponent },
];
EOF

write_file_heredoc "apps/web/src/app/components/home.component.ts" << 'EOF'
import { Component, inject, OnInit, signal } from "@angular/core";
import { HttpClient } from "@angular/common/http";

@Component({
  selector: "app-home",
  standalone: true,
  template: `
    <div class="grid min-h-screen items-center justify-items-center p-8 sm:p-20">
      <main class="flex flex-col items-center gap-8">
        <h1 class="text-4xl font-bold tracking-tight sm:text-6xl">
          Nx <span class="text-purple-600">Monorepo</span>
        </h1>
        <p class="text-lg text-gray-600 max-w-md text-center">
          Angular + NestJS + Prisma + Tailwind CSS
        </p>
        <div class="rounded-lg border border-gray-200 bg-white px-6 py-4 shadow-sm">
          <p class="text-sm text-gray-600">API Status:</p>
          <p class="text-lg font-semibold">{{ status() }}</p>
        </div>
        <a
          href="http://localhost:4000/api"
          class="rounded-full bg-purple-600 text-white px-6 py-3 text-sm font-medium hover:bg-purple-700 transition-colors"
        >
          API Docs
        </a>
      </main>
    </div>
  `,
})
export class HomeComponent implements OnInit {
  private http = inject(HttpClient);
  status = signal("Checking...");

  ngOnInit() {
    this.http.get<{ status: string }>("/api/health").subscribe({
      next: (res) => this.status.set(res.status),
      error: () => this.status.set("Offline"),
    });
  }
}
EOF
success "Created apps/web"

# ══════════════════════════════════════════════════════════════
# apps/api (NestJS 11)
# ══════════════════════════════════════════════════════════════
section "apps/api (NestJS 11)"
mkdir -p apps/api/src/users/dto

write_file_heredoc "apps/api/project.json" << 'EOF'
{
  "name": "api",
  "$schema": "../../node_modules/nx/schemas/project-schema.json",
  "sourceRoot": "apps/api/src",
  "projectType": "application",
  "targets": {
    "build": {
      "executor": "@nx/node:build",
      "outputs": ["{options.outputPath}"],
      "options": {
        "outputPath": "dist/apps/api",
        "main": "apps/api/src/main.ts",
        "tsConfig": "apps/api/tsconfig.app.json"
      }
    },
    "serve": {
      "executor": "@nx/node:execute",
      "options": {
        "buildTarget": "api:build",
        "port": 4000
      }
    },
    "lint": {
      "executor": "@nx/js:tsc",
      "options": {
        "tsConfig": "apps/api/tsconfig.app.json"
      }
    }
  },
  "tags": ["scope:api"]
}
EOF

write_file_heredoc "apps/api/tsconfig.json" << 'EOF'
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": {
    "target": "ES2024",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "emitDecoratorMetadata": true,
    "experimentalDecorators": true
  },
  "references": [
    { "path": "./tsconfig.app.json" }
  ]
}
EOF

write_file_heredoc "apps/api/tsconfig.app.json" << 'EOF'
{
  "extends": "./tsconfig.json",
  "compilerOptions": {
    "outDir": "../../dist/out-tsc",
    "declaration": false,
    "types": ["node"]
  },
  "include": ["src/**/*.ts"],
  "exclude": ["src/**/*.spec.ts"]
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
  controllers: [],
  providers: [],
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
import { prisma } from "@repo/shared";

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

# ── Finalize ──────────────────────────────────────────────────
section "Finalizing"
init_git
write_gitignore ".env" ".angular/"
write_editorconfig
write_nvmrc

write_readme "$PROJECT_NAME" \
  "Nx monorepo with Angular 19, NestJS 11, Prisma 6, and Tailwind CSS 4." \
  "npm install" \
  "npm run dev"

finish "npm install && npx prisma generate --schema=libs/shared/prisma/schema.prisma" "docker compose up -d && npm run dev"
