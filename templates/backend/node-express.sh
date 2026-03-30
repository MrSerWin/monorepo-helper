#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-express-app" "$@"
header "Node.js + Express 5 + TypeScript + Prisma + PostgreSQL"

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
    "test:watch": "vitest",
    "db:generate": "prisma generate",
    "db:migrate": "prisma migrate dev",
    "db:push": "prisma db push",
    "db:studio": "prisma studio"
  },
  "dependencies": {
    "express": "^5.1.0",
    "cors": "^2.8.5",
    "helmet": "^8.1.0",
    "@prisma/client": "^6.9.0",
    "zod": "^3.24.0",
    "dotenv": "^16.5.0"
  },
  "devDependencies": {
    "typescript": "^5.8.0",
    "tsx": "^4.19.0",
    "@types/node": "^22.15.0",
    "@types/express": "^5.0.2",
    "@types/cors": "^2.8.17",
    "prisma": "^6.9.0",
    "eslint": "^9.27.0",
    "@eslint/js": "^9.27.0",
    "typescript-eslint": "^8.32.0",
    "vitest": "^3.2.0",
    "supertest": "^7.1.0",
    "@types/supertest": "^6.0.2"
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
    "declarationMap": true,
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

# ── Vitest ────────────────────────────────────────────────────
section "Vitest configuration"
write_file_heredoc vitest.config.ts << 'EOF'
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    globals: true,
    environment: "node",
    include: ["src/**/*.test.ts"],
  },
});
EOF
success "Created vitest.config.ts"

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

mkdir -p src/routes src/middleware src/controllers

# src/index.ts
write_file_heredoc src/index.ts << 'EOF'
import "dotenv/config";
import express from "express";
import cors from "cors";
import helmet from "helmet";
import { userRouter } from "./routes/user.js";
import { errorHandler } from "./middleware/error-handler.js";

const app = express();
const port = process.env.PORT || 3000;

app.use(helmet());
app.use(cors());
app.use(express.json());

app.get("/health", (_req, res) => {
  res.json({ status: "ok", timestamp: new Date().toISOString() });
});

app.use("/api/users", userRouter);

app.use(errorHandler);

app.listen(port, () => {
  console.log(`Server running on http://localhost:${port}`);
});

export default app;
EOF
success "Created src/index.ts"

# src/middleware/error-handler.ts
write_file_heredoc src/middleware/error-handler.ts << 'EOF'
import type { Request, Response, NextFunction } from "express";

export class AppError extends Error {
  constructor(
    public statusCode: number,
    message: string,
  ) {
    super(message);
    this.name = "AppError";
  }
}

export function errorHandler(
  err: Error,
  _req: Request,
  res: Response,
  _next: NextFunction,
): void {
  if (err instanceof AppError) {
    res.status(err.statusCode).json({ error: err.message });
    return;
  }

  console.error(err);
  res.status(500).json({ error: "Internal server error" });
}
EOF
success "Created src/middleware/error-handler.ts"

# src/controllers/user.controller.ts
write_file_heredoc src/controllers/user.controller.ts << 'EOF'
import type { Request, Response, NextFunction } from "express";
import { PrismaClient } from "@prisma/client";
import { z } from "zod";
import { AppError } from "../middleware/error-handler.js";

const prisma = new PrismaClient();

const CreateUserSchema = z.object({
  email: z.string().email(),
  name: z.string().optional(),
});

export async function listUsers(_req: Request, res: Response, next: NextFunction) {
  try {
    const users = await prisma.user.findMany({ include: { posts: true } });
    res.json(users);
  } catch (error) {
    next(error);
  }
}

export async function getUser(req: Request, res: Response, next: NextFunction) {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.params.id },
      include: { posts: true },
    });
    if (!user) throw new AppError(404, "User not found");
    res.json(user);
  } catch (error) {
    next(error);
  }
}

export async function createUser(req: Request, res: Response, next: NextFunction) {
  try {
    const data = CreateUserSchema.parse(req.body);
    const user = await prisma.user.create({ data });
    res.status(201).json(user);
  } catch (error) {
    next(error);
  }
}

export async function deleteUser(req: Request, res: Response, next: NextFunction) {
  try {
    await prisma.user.delete({ where: { id: req.params.id } });
    res.status(204).end();
  } catch (error) {
    next(error);
  }
}
EOF
success "Created src/controllers/user.controller.ts"

# src/routes/user.ts
write_file_heredoc src/routes/user.ts << 'EOF'
import { Router } from "express";
import { listUsers, getUser, createUser, deleteUser } from "../controllers/user.controller.js";

export const userRouter = Router();

userRouter.get("/", listUsers);
userRouter.get("/:id", getUser);
userRouter.post("/", createUser);
userRouter.delete("/:id", deleteUser);
EOF
success "Created src/routes/user.ts"

# src/routes/user.test.ts
write_file_heredoc src/routes/user.test.ts << 'EOF'
import { describe, it, expect } from "vitest";

describe("User routes", () => {
  it("should have a health check", async () => {
    // Integration tests require a running database.
    // This is a placeholder showing the test setup.
    expect(true).toBe(true);
  });
});
EOF
success "Created src/routes/user.test.ts"

# ── .nvmrc ────────────────────────────────────────────────────
write_nvmrc "22"

# ── Finalize ──────────────────────────────────────────────────
section "Finalizing"
write_gitignore ".env"
write_editorconfig
init_git

write_readme "$PROJECT_NAME" \
  "Node.js + Express 5 + TypeScript + Prisma + PostgreSQL API" \
  "npm install" \
  "npm run dev"

finish "npm install && npx prisma generate" "docker compose up -d && npm run dev"
