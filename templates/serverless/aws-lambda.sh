#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-lambda-app" "$@"
header "AWS SAM + Node.js 22 + TypeScript + DynamoDB"

create_project_dir

# ── package.json ─────────────────────────────────────────────
section "Package configuration"
write_package_json '{
  "name": "'"$PROJECT_NAME"'",
  "version": "0.0.1",
  "private": true,
  "type": "module",
  "scripts": {
    "build": "node esbuild.config.js",
    "build:watch": "node esbuild.config.js --watch",
    "test": "vitest run",
    "test:watch": "vitest",
    "lint": "eslint src/",
    "local": "sam local start-api --warm-containers EAGER",
    "invoke": "sam local invoke",
    "deploy": "sam build && sam deploy",
    "deploy:guided": "sam build && sam deploy --guided",
    "logs": "sam logs --tail"
  },
  "dependencies": {
    "@aws-sdk/client-dynamodb": "^3.800.0",
    "@aws-sdk/lib-dynamodb": "^3.800.0"
  },
  "devDependencies": {
    "typescript": "^5.8.0",
    "@types/node": "^22.15.0",
    "@types/aws-lambda": "^8.10.147",
    "esbuild": "^0.25.0",
    "vitest": "^3.2.0",
    "eslint": "^9.27.0",
    "@eslint/js": "^9.27.0",
    "typescript-eslint": "^8.32.0"
  }
}'

# ── TypeScript ───────────────────────────────────────────────
section "TypeScript configuration"
write_tsconfig '{
  "compilerOptions": {
    "target": "ES2024",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "lib": ["ES2024"],
    "outDir": ".aws-sam/build",
    "rootDir": "src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "declaration": true,
    "sourceMap": true,
    "noEmit": true
  },
  "include": ["src"],
  "exclude": ["node_modules", ".aws-sam"]
}'

# ── SAM Template ─────────────────────────────────────────────
section "SAM template"
write_file_heredoc template.yaml << EOF
AWSTemplateFormatVersion: "2010-09-09"
Transform: AWS::Serverless-2016-10-31
Description: $PROJECT_NAME - Serverless API with DynamoDB

Globals:
  Function:
    Runtime: nodejs22.x
    Timeout: 30
    MemorySize: 256
    Architectures:
      - arm64
    Environment:
      Variables:
        TABLE_NAME: !Ref ItemsTable
        NODE_OPTIONS: "--enable-source-maps"

Resources:
  ApiGateway:
    Type: AWS::Serverless::Api
    Properties:
      StageName: prod
      Cors:
        AllowOrigin: "'*'"
        AllowHeaders: "'Content-Type,Authorization'"
        AllowMethods: "'GET,POST,PUT,DELETE,OPTIONS'"

  GetItemsFunction:
    Type: AWS::Serverless::Function
    Properties:
      Handler: index.handler
      CodeUri: dist/handlers/get-items/
      Description: Get all items
      Events:
        Api:
          Type: Api
          Properties:
            RestApiId: !Ref ApiGateway
            Path: /items
            Method: GET
      Policies:
        - DynamoDBReadPolicy:
            TableName: !Ref ItemsTable

  GetItemFunction:
    Type: AWS::Serverless::Function
    Properties:
      Handler: index.handler
      CodeUri: dist/handlers/get-item/
      Description: Get item by ID
      Events:
        Api:
          Type: Api
          Properties:
            RestApiId: !Ref ApiGateway
            Path: /items/{id}
            Method: GET
      Policies:
        - DynamoDBReadPolicy:
            TableName: !Ref ItemsTable

  CreateItemFunction:
    Type: AWS::Serverless::Function
    Properties:
      Handler: index.handler
      CodeUri: dist/handlers/create-item/
      Description: Create a new item
      Events:
        Api:
          Type: Api
          Properties:
            RestApiId: !Ref ApiGateway
            Path: /items
            Method: POST
      Policies:
        - DynamoDBCrudPolicy:
            TableName: !Ref ItemsTable

  DeleteItemFunction:
    Type: AWS::Serverless::Function
    Properties:
      Handler: index.handler
      CodeUri: dist/handlers/delete-item/
      Description: Delete an item
      Events:
        Api:
          Type: Api
          Properties:
            RestApiId: !Ref ApiGateway
            Path: /items/{id}
            Method: DELETE
      Policies:
        - DynamoDBCrudPolicy:
            TableName: !Ref ItemsTable

  ItemsTable:
    Type: AWS::DynamoDB::Table
    Properties:
      TableName: !Sub "\${AWS::StackName}-items"
      BillingMode: PAY_PER_REQUEST
      AttributeDefinitions:
        - AttributeName: id
          AttributeType: S
      KeySchema:
        - AttributeName: id
          KeyType: HASH
      Tags:
        - Key: Project
          Value: $PROJECT_NAME

Outputs:
  ApiEndpoint:
    Description: API Gateway endpoint URL
    Value: !Sub "https://\${ApiGateway}.execute-api.\${AWS::Region}.amazonaws.com/prod/"
  ItemsTableName:
    Description: DynamoDB table name
    Value: !Ref ItemsTable
  ItemsTableArn:
    Description: DynamoDB table ARN
    Value: !GetAtt ItemsTable.Arn
EOF
success "Created template.yaml"

# ── SAM Config ───────────────────────────────────────────────
write_file_heredoc samconfig.toml << EOF
version = 0.1

[default.deploy.parameters]
stack_name = "$PROJECT_NAME"
resolve_s3 = true
s3_prefix = "$PROJECT_NAME"
region = "us-east-1"
capabilities = "CAPABILITY_IAM"
confirm_changeset = true

[default.build.parameters]
cached = true
parallel = true
EOF
success "Created samconfig.toml"

# ── esbuild config ──────────────────────────────────────────
section "Build configuration"
write_file_heredoc esbuild.config.js << 'EOF'
import { build } from "esbuild";
import { readdirSync } from "fs";
import { join } from "path";

const isWatch = process.argv.includes("--watch");
const handlersDir = "src/handlers";

// Discover all handler entry points
const handlers = readdirSync(handlersDir).filter((name) => {
  return !name.includes(".");
});

const entryPoints = handlers.map((handler) => ({
  in: join(handlersDir, handler, "index.ts"),
  out: join("handlers", handler, "index"),
}));

/** @type {import('esbuild').BuildOptions} */
const config = {
  entryPoints: entryPoints.map((ep) => ep.in),
  outdir: "dist",
  outbase: "src",
  bundle: true,
  minify: !isWatch,
  sourcemap: true,
  platform: "node",
  target: "node22",
  format: "esm",
  external: ["@aws-sdk/*"],
  banner: {
    js: 'import { createRequire } from "module"; const require = createRequire(import.meta.url);',
  },
};

if (isWatch) {
  const ctx = await (await import("esbuild")).context(config);
  await ctx.watch();
  console.log("Watching for changes...");
} else {
  await build(config);
  console.log("Build complete");
}
EOF
success "Created esbuild.config.js"

# ── ESLint ───────────────────────────────────────────────────
section "ESLint configuration"
write_file_heredoc eslint.config.js << 'EOF'
import js from "@eslint/js";
import tseslint from "typescript-eslint";

export default tseslint.config(
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    ignores: ["dist/", "node_modules/", ".aws-sam/"],
  },
);
EOF
success "Created eslint.config.js"

# ── Vitest ───────────────────────────────────────────────────
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

# ── Source files ─────────────────────────────────────────────
section "Application source files"
mkdir -p src/handlers/get-items src/handlers/get-item src/handlers/create-item src/handlers/delete-item src/lib

# src/lib/dynamo.ts
write_file_heredoc src/lib/dynamo.ts << 'EOF'
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import {
  DynamoDBDocumentClient,
  GetCommand,
  PutCommand,
  ScanCommand,
  DeleteCommand,
} from "@aws-sdk/lib-dynamodb";

const client = new DynamoDBClient({});
export const docClient = DynamoDBDocumentClient.from(client, {
  marshallOptions: { removeUndefinedValues: true },
});

const TABLE_NAME = process.env.TABLE_NAME!;

export interface Item {
  id: string;
  name: string;
  description?: string;
  createdAt: string;
  updatedAt: string;
}

export async function getAllItems(): Promise<Item[]> {
  const result = await docClient.send(new ScanCommand({ TableName: TABLE_NAME }));
  return (result.Items as Item[]) ?? [];
}

export async function getItemById(id: string): Promise<Item | undefined> {
  const result = await docClient.send(
    new GetCommand({ TableName: TABLE_NAME, Key: { id } })
  );
  return result.Item as Item | undefined;
}

export async function createItem(item: Item): Promise<Item> {
  await docClient.send(
    new PutCommand({ TableName: TABLE_NAME, Item: item })
  );
  return item;
}

export async function deleteItem(id: string): Promise<void> {
  await docClient.send(
    new DeleteCommand({ TableName: TABLE_NAME, Key: { id } })
  );
}
EOF
success "Created src/lib/dynamo.ts"

# src/lib/response.ts
write_file_heredoc src/lib/response.ts << 'EOF'
import type { APIGatewayProxyResult } from "aws-lambda";

const headers = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "Content-Type,Authorization",
};

export function success(body: unknown, statusCode = 200): APIGatewayProxyResult {
  return {
    statusCode,
    headers,
    body: JSON.stringify(body),
  };
}

export function error(message: string, statusCode = 500): APIGatewayProxyResult {
  return {
    statusCode,
    headers,
    body: JSON.stringify({ error: message }),
  };
}
EOF
success "Created src/lib/response.ts"

# Handler: get-items
write_file_heredoc src/handlers/get-items/index.ts << 'EOF'
import type { APIGatewayProxyEvent, APIGatewayProxyResult } from "aws-lambda";
import { getAllItems } from "../../lib/dynamo.js";
import { success, error } from "../../lib/response.js";

export async function handler(_event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
  try {
    const items = await getAllItems();
    return success({ items });
  } catch (err) {
    console.error("Error fetching items:", err);
    return error("Failed to fetch items");
  }
}
EOF
success "Created src/handlers/get-items/index.ts"

# Handler: get-item
write_file_heredoc src/handlers/get-item/index.ts << 'EOF'
import type { APIGatewayProxyEvent, APIGatewayProxyResult } from "aws-lambda";
import { getItemById } from "../../lib/dynamo.js";
import { success, error } from "../../lib/response.js";

export async function handler(event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
  try {
    const id = event.pathParameters?.id;
    if (!id) {
      return error("Missing item ID", 400);
    }

    const item = await getItemById(id);
    if (!item) {
      return error("Item not found", 404);
    }

    return success({ item });
  } catch (err) {
    console.error("Error fetching item:", err);
    return error("Failed to fetch item");
  }
}
EOF
success "Created src/handlers/get-item/index.ts"

# Handler: create-item
write_file_heredoc src/handlers/create-item/index.ts << 'EOF'
import type { APIGatewayProxyEvent, APIGatewayProxyResult } from "aws-lambda";
import { createItem, type Item } from "../../lib/dynamo.js";
import { success, error } from "../../lib/response.js";
import { randomUUID } from "crypto";

export async function handler(event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
  try {
    if (!event.body) {
      return error("Request body is required", 400);
    }

    const body = JSON.parse(event.body);

    if (!body.name) {
      return error("Name is required", 400);
    }

    const now = new Date().toISOString();
    const item: Item = {
      id: randomUUID(),
      name: body.name,
      description: body.description,
      createdAt: now,
      updatedAt: now,
    };

    const created = await createItem(item);
    return success({ item: created }, 201);
  } catch (err) {
    console.error("Error creating item:", err);
    return error("Failed to create item");
  }
}
EOF
success "Created src/handlers/create-item/index.ts"

# Handler: delete-item
write_file_heredoc src/handlers/delete-item/index.ts << 'EOF'
import type { APIGatewayProxyEvent, APIGatewayProxyResult } from "aws-lambda";
import { deleteItem } from "../../lib/dynamo.js";
import { success, error } from "../../lib/response.js";

export async function handler(event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
  try {
    const id = event.pathParameters?.id;
    if (!id) {
      return error("Missing item ID", 400);
    }

    await deleteItem(id);
    return success({ message: "Item deleted" }, 204);
  } catch (err) {
    console.error("Error deleting item:", err);
    return error("Failed to delete item");
  }
}
EOF
success "Created src/handlers/delete-item/index.ts"

# ── Test events ──────────────────────────────────────────────
section "Test event files"
mkdir -p events

write_file_heredoc events/get-items.json << 'EOF'
{
  "httpMethod": "GET",
  "path": "/items",
  "pathParameters": null,
  "queryStringParameters": null,
  "headers": {
    "Content-Type": "application/json"
  },
  "body": null,
  "isBase64Encoded": false
}
EOF
success "Created events/get-items.json"

write_file_heredoc events/get-item.json << 'EOF'
{
  "httpMethod": "GET",
  "path": "/items/123",
  "pathParameters": {
    "id": "123"
  },
  "queryStringParameters": null,
  "headers": {
    "Content-Type": "application/json"
  },
  "body": null,
  "isBase64Encoded": false
}
EOF
success "Created events/get-item.json"

write_file_heredoc events/create-item.json << 'EOF'
{
  "httpMethod": "POST",
  "path": "/items",
  "pathParameters": null,
  "queryStringParameters": null,
  "headers": {
    "Content-Type": "application/json"
  },
  "body": "{\"name\": \"Test Item\", \"description\": \"A test item\"}",
  "isBase64Encoded": false
}
EOF
success "Created events/create-item.json"

write_file_heredoc events/delete-item.json << 'EOF'
{
  "httpMethod": "DELETE",
  "path": "/items/123",
  "pathParameters": {
    "id": "123"
  },
  "queryStringParameters": null,
  "headers": {
    "Content-Type": "application/json"
  },
  "body": null,
  "isBase64Encoded": false
}
EOF
success "Created events/delete-item.json"

# ── Tests ────────────────────────────────────────────────────
section "Tests"
write_file_heredoc src/lib/response.test.ts << 'EOF'
import { describe, it, expect } from "vitest";
import { success, error } from "./response.js";

describe("response helpers", () => {
  it("should return success response", () => {
    const res = success({ message: "ok" });
    expect(res.statusCode).toBe(200);
    expect(JSON.parse(res.body)).toEqual({ message: "ok" });
  });

  it("should return success with custom status", () => {
    const res = success({ id: "123" }, 201);
    expect(res.statusCode).toBe(201);
  });

  it("should return error response", () => {
    const res = error("Something failed", 400);
    expect(res.statusCode).toBe(400);
    expect(JSON.parse(res.body)).toEqual({ error: "Something failed" });
  });
});
EOF
success "Created src/lib/response.test.ts"

# ── .nvmrc ───────────────────────────────────────────────────
write_nvmrc "22"

# ── Finalize ─────────────────────────────────────────────────
section "Finalizing"
write_gitignore ".env" ".aws-sam/" "dist/" "samconfig.toml"
write_editorconfig
init_git

write_readme "$PROJECT_NAME" \
  "AWS SAM serverless API with TypeScript, Lambda, and DynamoDB." \
  "npm install" \
  "npm run build && sam local start-api" \
  "Run \`sam deploy --guided\` for first-time deployment."

finish "npm install && npm run build" "sam local start-api"
