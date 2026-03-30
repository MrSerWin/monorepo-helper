#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-npm-package" "$@"
create_project_dir

# --- package.json ---
write_package_json '{
  "name": "'"$PROJECT_NAME"'",
  "version": "0.0.1",
  "type": "module",
  "description": "A TypeScript library",
  "license": "MIT",
  "main": "./dist/index.cjs",
  "module": "./dist/index.js",
  "types": "./dist/index.d.ts",
  "exports": {
    ".": {
      "import": {
        "types": "./dist/index.d.ts",
        "default": "./dist/index.js"
      },
      "require": {
        "types": "./dist/index.d.cts",
        "default": "./dist/index.cjs"
      }
    }
  },
  "files": ["dist"],
  "scripts": {
    "dev": "tsup --watch",
    "build": "tsup",
    "test": "vitest",
    "test:run": "vitest run",
    "lint": "tsc --noEmit",
    "prepublishOnly": "npm run build",
    "changeset": "changeset",
    "version": "changeset version",
    "release": "npm run build && changeset publish"
  },
  "devDependencies": {
    "@changesets/cli": "^2.29.2",
    "tsup": "^8.4.0",
    "typescript": "^5.8.3",
    "vitest": "^3.1.1"
  }
}'

# --- tsconfig.json ---
write_tsconfig '{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "lib": ["ES2022"],
    "outDir": "dist",
    "rootDir": "src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "noEmit": true
  },
  "include": ["src"],
  "exclude": ["node_modules", "dist"]
}'

# --- tsup.config.ts ---
write_file "tsup.config.ts" 'import { defineConfig } from "tsup";

export default defineConfig({
  entry: ["src/index.ts"],
  format: ["esm", "cjs"],
  dts: true,
  clean: true,
  splitting: false,
  sourcemap: true,
});'

# --- vitest.config.ts ---
write_file "vitest.config.ts" 'import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    globals: true,
  },
});'

# --- src/index.ts ---
write_file "src/index.ts" '/**
 * Adds two numbers together.
 *
 * @param a - The first number
 * @param b - The second number
 * @returns The sum of a and b
 */
export function add(a: number, b: number): number {
  return a + b;
}

/**
 * Creates a greeting message.
 *
 * @param name - The name to greet
 * @returns A greeting string
 */
export function greet(name: string): string {
  return `Hello, ${name}!`;
}'

# --- src/__tests__/index.test.ts ---
write_file "src/__tests__/index.test.ts" 'import { describe, it, expect } from "vitest";
import { add, greet } from "../index.js";

describe("add", () => {
  it("should add two numbers", () => {
    expect(add(1, 2)).toBe(3);
  });

  it("should handle negative numbers", () => {
    expect(add(-1, -2)).toBe(-3);
  });

  it("should handle zero", () => {
    expect(add(0, 0)).toBe(0);
  });
});

describe("greet", () => {
  it("should return a greeting", () => {
    expect(greet("World")).toBe("Hello, World!");
  });
});'

# --- .changeset/config.json ---
write_file ".changeset/config.json" '{
  "$schema": "https://unpkg.com/@changesets/config@3.1.1/schema.json",
  "changelog": "@changesets/cli/changelog",
  "commit": false,
  "fixed": [],
  "linked": [],
  "access": "public",
  "baseBranch": "main",
  "updateInternalDependencies": "patch",
  "ignore": []
}'

# --- .github/workflows/ci.yml ---
write_file_heredoc ".github/workflows/ci.yml" << 'EOF'
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        node-version: [20, 22]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}
          cache: npm
      - run: npm ci
      - run: npm run lint
      - run: npm run build
      - run: npm run test:run
EOF

# --- .github/workflows/release.yml ---
write_file_heredoc ".github/workflows/release.yml" << 'EOF'
name: Release

on:
  push:
    branches: [main]

concurrency: ${{ github.workflow }}-${{ github.ref }}

jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
      id-token: write
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: npm
          registry-url: "https://registry.npmjs.org"
      - run: npm ci
      - run: npm run build
      - run: npm run test:run
      - name: Create Release Pull Request or Publish
        uses: changesets/action@v1
        with:
          publish: npm run release
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
EOF

init_git
write_gitignore
write_editorconfig
write_nvmrc

finish "npm install" "npm run build"
