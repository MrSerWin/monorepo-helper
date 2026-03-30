#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-nestjs-app" "$@"
header "NestJS 11 + TypeScript + Prisma + PostgreSQL + Swagger + JWT Auth"

create_project_dir

# ── package.json ──────────────────────────────────────────────
section "Package configuration"
write_package_json '{
  "name": "'"$PROJECT_NAME"'",
  "version": "0.0.1",
  "private": true,
  "scripts": {
    "dev": "nest start --watch",
    "build": "nest build",
    "start": "node dist/main",
    "start:prod": "node dist/main",
    "lint": "eslint \"{src,test}/**/*.ts\"",
    "test": "jest",
    "test:e2e": "jest --config ./test/jest-e2e.json",
    "db:generate": "prisma generate",
    "db:migrate": "prisma migrate dev",
    "db:push": "prisma db push",
    "db:studio": "prisma studio"
  },
  "dependencies": {
    "@nestjs/common": "^11.1.0",
    "@nestjs/core": "^11.1.0",
    "@nestjs/platform-express": "^11.1.0",
    "@nestjs/swagger": "^11.1.0",
    "@nestjs/config": "^4.0.0",
    "@nestjs/jwt": "^11.0.0",
    "@nestjs/passport": "^11.0.0",
    "@prisma/client": "^6.9.0",
    "passport": "^0.7.0",
    "passport-jwt": "^4.0.1",
    "bcrypt": "^5.1.1",
    "class-transformer": "^0.5.1",
    "class-validator": "^0.14.1",
    "reflect-metadata": "^0.2.2",
    "rxjs": "^7.8.1"
  },
  "devDependencies": {
    "@nestjs/cli": "^11.0.0",
    "@nestjs/schematics": "^11.0.0",
    "@nestjs/testing": "^11.1.0",
    "@types/bcrypt": "^5.0.2",
    "@types/express": "^5.0.2",
    "@types/jest": "^29.5.14",
    "@types/node": "^22.15.0",
    "@types/passport-jwt": "^4.0.1",
    "typescript": "^5.8.0",
    "prisma": "^6.9.0",
    "eslint": "^9.27.0",
    "@eslint/js": "^9.27.0",
    "typescript-eslint": "^8.32.0",
    "jest": "^29.7.0",
    "ts-jest": "^29.3.0",
    "ts-loader": "^9.5.2",
    "source-map-support": "^0.5.21"
  },
  "jest": {
    "moduleFileExtensions": ["js", "json", "ts"],
    "rootDir": "src",
    "testRegex": ".*\\.spec\\.ts$",
    "transform": { "^.+\\.(t|j)s$": "ts-jest" },
    "collectCoverageFrom": ["**/*.(t|j)s"],
    "coverageDirectory": "../coverage",
    "testEnvironment": "node"
  }
}'

# ── TypeScript ────────────────────────────────────────────────
section "TypeScript configuration"
write_tsconfig '{
  "compilerOptions": {
    "module": "commonjs",
    "declaration": true,
    "removeComments": true,
    "emitDecoratorMetadata": true,
    "experimentalDecorators": true,
    "allowSyntheticDefaultImports": true,
    "target": "ES2024",
    "sourceMap": true,
    "outDir": "./dist",
    "rootDir": "./src",
    "baseUrl": "./",
    "incremental": true,
    "skipLibCheck": true,
    "strict": true,
    "forceConsistentCasingInFileNames": true,
    "noFallthroughCasesInSwitch": true
  },
  "include": ["src"],
  "exclude": ["node_modules", "dist"]
}'

# ── nest-cli.json ─────────────────────────────────────────────
write_file_heredoc nest-cli.json << 'EOF'
{
  "$schema": "https://json.schemastore.org/nest-cli",
  "collection": "@nestjs/schematics",
  "sourceRoot": "src",
  "compilerOptions": {
    "deleteOutDir": true
  }
}
EOF
success "Created nest-cli.json"

# ── ESLint 9 ──────────────────────────────────────────────────
section "ESLint configuration"
write_file_heredoc eslint.config.mjs << 'EOF'
import js from "@eslint/js";
import tseslint from "typescript-eslint";

export default tseslint.config(
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    ignores: ["dist/", "node_modules/"],
  },
  {
    rules: {
      "@typescript-eslint/no-explicit-any": "off",
    },
  },
);
EOF
success "Created eslint.config.mjs"

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
  password  String
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
JWT_SECRET="change-me-to-a-secure-random-string"
PORT=3000
EOF
success "Created .env.example"
cp .env.example .env

# ── Source files ──────────────────────────────────────────────
section "Application source files"

mkdir -p src/auth src/auth/dto src/auth/strategies src/users src/users/dto src/prisma

# src/main.ts
write_file_heredoc src/main.ts << 'EOF'
import { NestFactory } from "@nestjs/core";
import { ValidationPipe } from "@nestjs/common";
import { SwaggerModule, DocumentBuilder } from "@nestjs/swagger";
import { AppModule } from "./app.module";

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.enableCors();
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));

  const config = new DocumentBuilder()
    .setTitle("API")
    .setDescription("API documentation")
    .setVersion("0.1.0")
    .addBearerAuth()
    .build();
  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup("docs", app, document);

  const port = process.env.PORT || 3000;
  await app.listen(port);
  console.log(`Server running on http://localhost:${port}`);
}
bootstrap();
EOF
success "Created src/main.ts"

# src/app.module.ts
write_file_heredoc src/app.module.ts << 'EOF'
import { Module } from "@nestjs/common";
import { ConfigModule } from "@nestjs/config";
import { PrismaModule } from "./prisma/prisma.module";
import { AuthModule } from "./auth/auth.module";
import { UsersModule } from "./users/users.module";

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    AuthModule,
    UsersModule,
  ],
})
export class AppModule {}
EOF
success "Created src/app.module.ts"

# src/prisma/prisma.module.ts
write_file_heredoc src/prisma/prisma.module.ts << 'EOF'
import { Global, Module } from "@nestjs/common";
import { PrismaService } from "./prisma.service";

@Global()
@Module({
  providers: [PrismaService],
  exports: [PrismaService],
})
export class PrismaModule {}
EOF
success "Created src/prisma/prisma.module.ts"

# src/prisma/prisma.service.ts
write_file_heredoc src/prisma/prisma.service.ts << 'EOF'
import { Injectable, OnModuleInit, OnModuleDestroy } from "@nestjs/common";
import { PrismaClient } from "@prisma/client";

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  async onModuleInit() {
    await this.$connect();
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }
}
EOF
success "Created src/prisma/prisma.service.ts"

# src/auth/auth.module.ts
write_file_heredoc src/auth/auth.module.ts << 'EOF'
import { Module } from "@nestjs/common";
import { JwtModule } from "@nestjs/jwt";
import { ConfigModule, ConfigService } from "@nestjs/config";
import { PassportModule } from "@nestjs/passport";
import { AuthService } from "./auth.service";
import { AuthController } from "./auth.controller";
import { JwtStrategy } from "./strategies/jwt.strategy";

@Module({
  imports: [
    PassportModule.register({ defaultStrategy: "jwt" }),
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.get<string>("JWT_SECRET"),
        signOptions: { expiresIn: "1d" },
      }),
    }),
  ],
  controllers: [AuthController],
  providers: [AuthService, JwtStrategy],
  exports: [AuthService],
})
export class AuthModule {}
EOF
success "Created src/auth/auth.module.ts"

# src/auth/auth.service.ts
write_file_heredoc src/auth/auth.service.ts << 'EOF'
import { Injectable, UnauthorizedException } from "@nestjs/common";
import { JwtService } from "@nestjs/jwt";
import * as bcrypt from "bcrypt";
import { PrismaService } from "../prisma/prisma.service";
import { RegisterDto } from "./dto/register.dto";
import { LoginDto } from "./dto/login.dto";

@Injectable()
export class AuthService {
  constructor(
    private prisma: PrismaService,
    private jwt: JwtService,
  ) {}

  async register(dto: RegisterDto) {
    const hashedPassword = await bcrypt.hash(dto.password, 10);
    const user = await this.prisma.user.create({
      data: { email: dto.email, name: dto.name, password: hashedPassword },
    });
    return this.signToken(user.id, user.email);
  }

  async login(dto: LoginDto) {
    const user = await this.prisma.user.findUnique({ where: { email: dto.email } });
    if (!user) throw new UnauthorizedException("Invalid credentials");

    const valid = await bcrypt.compare(dto.password, user.password);
    if (!valid) throw new UnauthorizedException("Invalid credentials");

    return this.signToken(user.id, user.email);
  }

  private async signToken(userId: string, email: string) {
    const token = await this.jwt.signAsync({ sub: userId, email });
    return { access_token: token };
  }
}
EOF
success "Created src/auth/auth.service.ts"

# src/auth/auth.controller.ts
write_file_heredoc src/auth/auth.controller.ts << 'EOF'
import { Controller, Post, Body } from "@nestjs/common";
import { ApiTags } from "@nestjs/swagger";
import { AuthService } from "./auth.service";
import { RegisterDto } from "./dto/register.dto";
import { LoginDto } from "./dto/login.dto";

@ApiTags("auth")
@Controller("auth")
export class AuthController {
  constructor(private auth: AuthService) {}

  @Post("register")
  register(@Body() dto: RegisterDto) {
    return this.auth.register(dto);
  }

  @Post("login")
  login(@Body() dto: LoginDto) {
    return this.auth.login(dto);
  }
}
EOF
success "Created src/auth/auth.controller.ts"

# src/auth/dto/register.dto.ts
write_file_heredoc src/auth/dto/register.dto.ts << 'EOF'
import { IsEmail, IsString, MinLength, IsOptional } from "class-validator";
import { ApiProperty } from "@nestjs/swagger";

export class RegisterDto {
  @ApiProperty()
  @IsEmail()
  email: string;

  @ApiProperty()
  @IsString()
  @MinLength(6)
  password: string;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  name?: string;
}
EOF
success "Created src/auth/dto/register.dto.ts"

# src/auth/dto/login.dto.ts
write_file_heredoc src/auth/dto/login.dto.ts << 'EOF'
import { IsEmail, IsString } from "class-validator";
import { ApiProperty } from "@nestjs/swagger";

export class LoginDto {
  @ApiProperty()
  @IsEmail()
  email: string;

  @ApiProperty()
  @IsString()
  password: string;
}
EOF
success "Created src/auth/dto/login.dto.ts"

# src/auth/strategies/jwt.strategy.ts
write_file_heredoc src/auth/strategies/jwt.strategy.ts << 'EOF'
import { Injectable } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { PassportStrategy } from "@nestjs/passport";
import { ExtractJwt, Strategy } from "passport-jwt";

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(config: ConfigService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: config.get<string>("JWT_SECRET"),
    });
  }

  validate(payload: { sub: string; email: string }) {
    return { userId: payload.sub, email: payload.email };
  }
}
EOF
success "Created src/auth/strategies/jwt.strategy.ts"

# src/auth/guards/jwt-auth.guard.ts
mkdir -p src/auth/guards
write_file_heredoc src/auth/guards/jwt-auth.guard.ts << 'EOF'
import { Injectable } from "@nestjs/common";
import { AuthGuard } from "@nestjs/passport";

@Injectable()
export class JwtAuthGuard extends AuthGuard("jwt") {}
EOF
success "Created src/auth/guards/jwt-auth.guard.ts"

# src/users/users.module.ts
write_file_heredoc src/users/users.module.ts << 'EOF'
import { Module } from "@nestjs/common";
import { UsersService } from "./users.service";
import { UsersController } from "./users.controller";

@Module({
  controllers: [UsersController],
  providers: [UsersService],
  exports: [UsersService],
})
export class UsersModule {}
EOF
success "Created src/users/users.module.ts"

# src/users/users.service.ts
write_file_heredoc src/users/users.service.ts << 'EOF'
import { Injectable, NotFoundException } from "@nestjs/common";
import { PrismaService } from "../prisma/prisma.service";
import { UpdateUserDto } from "./dto/update-user.dto";

@Injectable()
export class UsersService {
  constructor(private prisma: PrismaService) {}

  async findAll() {
    return this.prisma.user.findMany({ select: { id: true, email: true, name: true, createdAt: true } });
  }

  async findOne(id: string) {
    const user = await this.prisma.user.findUnique({
      where: { id },
      select: { id: true, email: true, name: true, createdAt: true },
    });
    if (!user) throw new NotFoundException("User not found");
    return user;
  }

  async update(id: string, dto: UpdateUserDto) {
    await this.findOne(id);
    return this.prisma.user.update({
      where: { id },
      data: dto,
      select: { id: true, email: true, name: true, createdAt: true },
    });
  }

  async remove(id: string) {
    await this.findOne(id);
    return this.prisma.user.delete({ where: { id } });
  }
}
EOF
success "Created src/users/users.service.ts"

# src/users/users.controller.ts
write_file_heredoc src/users/users.controller.ts << 'EOF'
import { Controller, Get, Patch, Delete, Param, Body, UseGuards } from "@nestjs/common";
import { ApiBearerAuth, ApiTags } from "@nestjs/swagger";
import { UsersService } from "./users.service";
import { UpdateUserDto } from "./dto/update-user.dto";
import { JwtAuthGuard } from "../auth/guards/jwt-auth.guard";

@ApiTags("users")
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller("users")
export class UsersController {
  constructor(private users: UsersService) {}

  @Get()
  findAll() {
    return this.users.findAll();
  }

  @Get(":id")
  findOne(@Param("id") id: string) {
    return this.users.findOne(id);
  }

  @Patch(":id")
  update(@Param("id") id: string, @Body() dto: UpdateUserDto) {
    return this.users.update(id, dto);
  }

  @Delete(":id")
  remove(@Param("id") id: string) {
    return this.users.remove(id);
  }
}
EOF
success "Created src/users/users.controller.ts"

# src/users/dto/update-user.dto.ts
write_file_heredoc src/users/dto/update-user.dto.ts << 'EOF'
import { IsString, IsOptional } from "class-validator";
import { ApiProperty } from "@nestjs/swagger";

export class UpdateUserDto {
  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  name?: string;
}
EOF
success "Created src/users/dto/update-user.dto.ts"

# ── Test files ────────────────────────────────────────────────
mkdir -p test
write_file_heredoc test/jest-e2e.json << 'EOF'
{
  "moduleFileExtensions": ["js", "json", "ts"],
  "rootDir": ".",
  "testEnvironment": "node",
  "testRegex": ".e2e-spec.ts$",
  "transform": { "^.+\\.(t|j)s$": "ts-jest" }
}
EOF
success "Created test/jest-e2e.json"

# ── .nvmrc ────────────────────────────────────────────────────
write_nvmrc "22"

# ── Finalize ──────────────────────────────────────────────────
section "Finalizing"
write_gitignore ".env"
write_editorconfig
init_git

write_readme "$PROJECT_NAME" \
  "NestJS 11 + TypeScript + Prisma + PostgreSQL API with JWT Auth and Swagger docs" \
  "npm install" \
  "npm run dev"

finish "npm install && npx prisma generate" "docker compose up -d && npm run dev"
