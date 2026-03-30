#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-strapi-app" "$@"
create_project_dir

# --- package.json ---
write_package_json '{
  "name": "'"$PROJECT_NAME"'",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "strapi develop",
    "start": "strapi start",
    "build": "strapi build",
    "strapi": "strapi",
    "deploy": "strapi deploy"
  },
  "dependencies": {
    "@strapi/strapi": "^5.12.0",
    "@strapi/plugin-cloud": "^5.12.0",
    "@strapi/plugin-users-permissions": "^5.12.0",
    "@strapi/plugin-i18n": "^5.12.0"
  },
  "devDependencies": {
    "@types/node": "^22.14.0",
    "typescript": "^5.8.3"
  },
  "engines": {
    "node": ">=18.0.0 <=22.x.x",
    "npm": ">=6.0.0"
  }
}'

# --- tsconfig.json ---
write_tsconfig '{
  "compilerOptions": {
    "target": "ES2021",
    "lib": ["ES2021"],
    "module": "commonjs",
    "moduleResolution": "node",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "declaration": true,
    "declarationMap": true,
    "outDir": "dist",
    "rootDir": "."
  },
  "include": ["src/**/*.ts", "config/**/*.ts"],
  "exclude": ["node_modules", "dist", ".cache", ".tmp"]
}'

# --- config/server.ts ---
write_file "config/server.ts" 'export default ({ env }: { env: (key: string, defaultValue?: string) => string }) => ({
  host: env("HOST", "0.0.0.0"),
  port: env.int("PORT", 1337),
  app: {
    keys: env.array("APP_KEYS", ["key1", "key2"]),
  },
  webhooks: {
    populateRelations: env.bool("WEBHOOKS_POPULATE_RELATIONS", false),
  },
});'

# --- config/database.ts ---
write_file "config/database.ts" 'import path from "path";

export default ({ env }: { env: (key: string, defaultValue?: string) => string }) => {
  const client = env("DATABASE_CLIENT", "postgres");

  const connections: Record<string, object> = {
    postgres: {
      connection: {
        host: env("DATABASE_HOST", "127.0.0.1"),
        port: env.int("DATABASE_PORT", 5432),
        database: env("DATABASE_NAME", "strapi"),
        user: env("DATABASE_USERNAME", "strapi"),
        password: env("DATABASE_PASSWORD", "strapi"),
        ssl: env.bool("DATABASE_SSL", false) && {
          rejectUnauthorized: env.bool("DATABASE_SSL_SELF", false),
        },
        schema: env("DATABASE_SCHEMA", "public"),
      },
      pool: {
        min: env.int("DATABASE_POOL_MIN", 2),
        max: env.int("DATABASE_POOL_MAX", 10),
      },
    },
    sqlite: {
      connection: {
        filename: path.join(
          __dirname,
          "..",
          "..",
          env("DATABASE_FILENAME", ".tmp/data.db")
        ),
      },
      useNullAsDefault: true,
    },
  };

  return {
    connection: {
      client,
      ...connections[client],
      acquireConnectionTimeout: env.int("DATABASE_CONNECTION_TIMEOUT", 60000),
    },
  };
};'

# --- config/admin.ts ---
write_file "config/admin.ts" 'export default ({ env }: { env: (key: string, defaultValue?: string) => string }) => ({
  auth: {
    secret: env("ADMIN_JWT_SECRET", "change-me-admin-jwt-secret"),
  },
  apiToken: {
    salt: env("API_TOKEN_SALT", "change-me-api-token-salt"),
  },
  transfer: {
    token: {
      salt: env("TRANSFER_TOKEN_SALT", "change-me-transfer-token-salt"),
    },
  },
  flags: {
    nps: env.bool("FLAG_NPS", true),
    promoteEE: env.bool("FLAG_PROMOTE_EE", true),
  },
});'

# --- config/plugins.ts ---
write_file "config/plugins.ts" 'export default ({ env }: { env: (key: string, defaultValue?: string) => string }) => ({
  "users-permissions": {
    config: {
      jwtSecret: env("JWT_SECRET", "change-me-jwt-secret"),
    },
  },
  i18n: {
    enabled: true,
    config: {
      defaultLocale: "en",
      locales: ["en"],
    },
  },
});'

# --- config/middlewares.ts ---
write_file "config/middlewares.ts" 'export default [
  "strapi::logger",
  "strapi::errors",
  "strapi::security",
  "strapi::cors",
  "strapi::poweredBy",
  "strapi::query",
  "strapi::body",
  "strapi::session",
  "strapi::favicon",
  "strapi::public",
];'

# --- src/index.ts ---
write_file "src/index.ts" '// Application lifecycle hooks
// See: https://docs.strapi.io/dev-docs/configurations/functions

export default {
  /**
   * An asynchronous register function that runs before
   * your application is initialized.
   */
  register(/* { strapi } */): void {
    // ...
  },

  /**
   * An asynchronous bootstrap function that runs before
   * your application gets started.
   */
  bootstrap(/* { strapi } */): void {
    // ...
  },
};'

# --- src/admin/app.tsx ---
write_file "src/admin/app.tsx" 'export default {
  config: {
    locales: ["en"],
    tutorials: false,
    notifications: {
      releases: false,
    },
  },
  bootstrap() {
    // Custom admin bootstrap logic
  },
};'

# --- src/api/article/content-types/article/schema.json ---
write_file "src/api/article/content-types/article/schema.json" '{
  "kind": "collectionType",
  "collectionName": "articles",
  "info": {
    "singularName": "article",
    "pluralName": "articles",
    "displayName": "Article",
    "description": "Blog articles"
  },
  "options": {
    "draftAndPublish": true
  },
  "pluginOptions": {},
  "attributes": {
    "title": {
      "type": "string",
      "required": true,
      "maxLength": 255
    },
    "slug": {
      "type": "uid",
      "targetField": "title",
      "required": true
    },
    "content": {
      "type": "richtext"
    },
    "excerpt": {
      "type": "text",
      "maxLength": 500
    },
    "cover": {
      "type": "media",
      "multiple": false,
      "allowedTypes": ["images"]
    },
    "category": {
      "type": "enumeration",
      "enum": ["news", "tutorial", "opinion", "review"],
      "default": "news"
    },
    "author": {
      "type": "relation",
      "relation": "manyToOne",
      "target": "plugin::users-permissions.user",
      "inversedBy": "articles"
    }
  }
}'

# --- src/api/article/controllers/article.ts ---
write_file "src/api/article/controllers/article.ts" '/**
 * article controller
 */

import { factories } from "@strapi/strapi";

export default factories.createCoreController("api::article.article");'

# --- src/api/article/services/article.ts ---
write_file "src/api/article/services/article.ts" '/**
 * article service
 */

import { factories } from "@strapi/strapi";

export default factories.createCoreService("api::article.article");'

# --- src/api/article/routes/article.ts ---
write_file "src/api/article/routes/article.ts" '/**
 * article router
 */

import { factories } from "@strapi/strapi";

export default factories.createCoreRouter("api::article.article");'

# --- docker-compose.yml ---
write_file "docker-compose.yml" 'services:
  postgres:
    image: postgres:17-alpine
    restart: unless-stopped
    ports:
      - "5432:5432"
    environment:
      POSTGRES_USER: strapi
      POSTGRES_PASSWORD: strapi
      POSTGRES_DB: strapi
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:'

# --- .env.example ---
write_file ".env.example" '# Server
HOST=0.0.0.0
PORT=1337

# Secrets
APP_KEYS=key1,key2,key3,key4
API_TOKEN_SALT=change-me-api-token-salt
ADMIN_JWT_SECRET=change-me-admin-jwt-secret
TRANSFER_TOKEN_SALT=change-me-transfer-token-salt
JWT_SECRET=change-me-jwt-secret

# Database
DATABASE_CLIENT=postgres
DATABASE_HOST=127.0.0.1
DATABASE_PORT=5432
DATABASE_NAME=strapi
DATABASE_USERNAME=strapi
DATABASE_PASSWORD=strapi
DATABASE_SSL=false'

mkdir -p public/uploads

init_git
write_gitignore ".tmp/" ".cache/" "build/" "public/uploads/"
write_editorconfig
write_nvmrc

finish "npm install" "npm run dev"
