#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-packages" "$@"
header "Turborepo + TypeScript + tsup + Changesets + Vitest"

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
    "test": "turbo test",
    "lint": "turbo lint",
    "format": "prettier --write .",
    "changeset": "changeset",
    "version-packages": "changeset version",
    "release": "turbo build && changeset publish"
  },
  "devDependencies": {
    "@changesets/cli": "^2.29.0",
    "prettier": "^3.5.0",
    "turbo": "^2.5.0"
  },
  "packageManager": "pnpm@10.8.0"
}'

write_file_heredoc "pnpm-workspace.yaml" << 'EOF'
packages:
  - "packages/*"
EOF
success "Created pnpm-workspace.yaml"

write_file_heredoc "turbo.json" << 'EOF'
{
  "$schema": "https://turbo.build/schema.json",
  "tasks": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": ["dist/**"]
    },
    "dev": {
      "cache": false,
      "persistent": true
    },
    "test": {
      "dependsOn": ["build"],
      "cache": true
    },
    "lint": {
      "dependsOn": ["^build"],
      "cache": true
    }
  }
}
EOF
success "Created turbo.json"

# ── .changeset ────────────────────────────────────────────────
mkdir -p .changeset

write_file_heredoc ".changeset/config.json" << 'EOF'
{
  "$schema": "https://unpkg.com/@changesets/config@3.1.1/schema.json",
  "changelog": "@changesets/cli/changelog",
  "commit": false,
  "fixed": [],
  "linked": [],
  "access": "public",
  "baseBranch": "main",
  "updateInternalDependencies": "patch",
  "ignore": []
}
EOF
success "Created .changeset/config.json"

write_file ".changeset/README.md" 'This folder is used by [Changesets](https://github.com/changesets/changesets) to track package versions.'

# ── .prettierrc ───────────────────────────────────────────────
write_file_heredoc ".prettierrc" << 'EOF'
{
  "semi": true,
  "singleQuote": false,
  "tabWidth": 2,
  "trailingComma": "all",
  "printWidth": 100
}
EOF
success "Created .prettierrc"

# ── GitHub Actions ────────────────────────────────────────────
section "GitHub Actions"
mkdir -p .github/workflows

write_file_heredoc ".github/workflows/ci.yml" << 'EOF'
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: "pnpm"
      - run: pnpm install --frozen-lockfile
      - run: pnpm build
      - run: pnpm test
      - run: pnpm lint
EOF
success "Created .github/workflows/ci.yml"

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
      packages: write
      pull-requests: write
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: "pnpm"
          registry-url: "https://registry.npmjs.org"
      - run: pnpm install --frozen-lockfile
      - run: pnpm build

      - name: Create Release Pull Request or Publish
        id: changesets
        uses: changesets/action@v1
        with:
          publish: pnpm release
          version: pnpm version-packages
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
EOF
success "Created .github/workflows/release.yml"

# ══════════════════════════════════════════════════════════════
# Shared tsconfig
# ══════════════════════════════════════════════════════════════
write_file_heredoc "tsconfig.json" << 'EOF'
{
  "compilerOptions": {
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "moduleResolution": "bundler",
    "target": "ES2024",
    "module": "ESNext",
    "lib": ["ES2024"],
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true
  }
}
EOF

# ══════════════════════════════════════════════════════════════
# packages/core
# ══════════════════════════════════════════════════════════════
section "packages/core"
mkdir -p packages/core/src packages/core/test

write_file_heredoc "packages/core/package.json" << 'EOF'
{
  "name": "@repo/core",
  "version": "0.0.1",
  "type": "module",
  "main": "./dist/index.js",
  "module": "./dist/index.js",
  "types": "./dist/index.d.ts",
  "exports": {
    ".": {
      "import": "./dist/index.js",
      "types": "./dist/index.d.ts"
    }
  },
  "files": ["dist"],
  "scripts": {
    "dev": "tsup --watch",
    "build": "tsup",
    "test": "vitest run",
    "test:watch": "vitest",
    "lint": "eslint src/"
  },
  "devDependencies": {
    "@eslint/js": "^9.24.0",
    "eslint": "^9.24.0",
    "tsup": "^8.4.0",
    "typescript": "^5.8.3",
    "typescript-eslint": "^8.32.0",
    "vitest": "^3.2.0"
  }
}
EOF

write_file_heredoc "packages/core/tsconfig.json" << 'EOF'
{
  "extends": "../../tsconfig.json",
  "compilerOptions": {
    "outDir": "dist",
    "rootDir": "src"
  },
  "include": ["src"]
}
EOF

write_file_heredoc "packages/core/tsup.config.ts" << 'EOF'
import { defineConfig } from "tsup";

export default defineConfig({
  entry: ["src/index.ts"],
  format: ["esm"],
  dts: true,
  clean: true,
  sourcemap: true,
});
EOF

write_file_heredoc "packages/core/vitest.config.ts" << 'EOF'
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    globals: true,
    environment: "node",
  },
});
EOF

write_file_heredoc "packages/core/eslint.config.js" << 'EOF'
import js from "@eslint/js";
import tseslint from "typescript-eslint";

export default tseslint.config(
  js.configs.recommended,
  ...tseslint.configs.recommended,
  { ignores: ["dist/"] },
);
EOF

write_file_heredoc "packages/core/src/index.ts" << 'EOF'
export { Result, ok, err } from "./result.js";
export { pipe, compose } from "./functional.js";
EOF

write_file_heredoc "packages/core/src/result.ts" << 'EOF'
export type Result<T, E = Error> =
  | { ok: true; value: T }
  | { ok: false; error: E };

export function ok<T>(value: T): Result<T, never> {
  return { ok: true, value };
}

export function err<E>(error: E): Result<never, E> {
  return { ok: false, error };
}
EOF

write_file_heredoc "packages/core/src/functional.ts" << 'EOF'
type Fn<A, B> = (a: A) => B;

export function pipe<A, B>(a: A, ab: Fn<A, B>): B;
export function pipe<A, B, C>(a: A, ab: Fn<A, B>, bc: Fn<B, C>): C;
export function pipe<A, B, C, D>(a: A, ab: Fn<A, B>, bc: Fn<B, C>, cd: Fn<C, D>): D;
export function pipe(initial: unknown, ...fns: Fn<unknown, unknown>[]): unknown {
  return fns.reduce((acc, fn) => fn(acc), initial);
}

export function compose<A, B, C>(bc: Fn<B, C>, ab: Fn<A, B>): Fn<A, C>;
export function compose(...fns: Fn<unknown, unknown>[]): Fn<unknown, unknown> {
  return (initial) => fns.reduceRight((acc, fn) => fn(acc), initial);
}
EOF

write_file_heredoc "packages/core/test/result.test.ts" << 'EOF'
import { describe, it, expect } from "vitest";
import { ok, err } from "../src/result.js";

describe("Result", () => {
  it("creates an ok result", () => {
    const result = ok(42);
    expect(result.ok).toBe(true);
    if (result.ok) expect(result.value).toBe(42);
  });

  it("creates an err result", () => {
    const result = err(new Error("fail"));
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error.message).toBe("fail");
  });
});
EOF
success "Created packages/core"

# ══════════════════════════════════════════════════════════════
# packages/utils
# ══════════════════════════════════════════════════════════════
section "packages/utils"
mkdir -p packages/utils/src packages/utils/test

write_file_heredoc "packages/utils/package.json" << 'EOF'
{
  "name": "@repo/utils",
  "version": "0.0.1",
  "type": "module",
  "main": "./dist/index.js",
  "module": "./dist/index.js",
  "types": "./dist/index.d.ts",
  "exports": {
    ".": {
      "import": "./dist/index.js",
      "types": "./dist/index.d.ts"
    }
  },
  "files": ["dist"],
  "scripts": {
    "dev": "tsup --watch",
    "build": "tsup",
    "test": "vitest run",
    "test:watch": "vitest",
    "lint": "eslint src/"
  },
  "dependencies": {
    "@repo/core": "workspace:*"
  },
  "devDependencies": {
    "@eslint/js": "^9.24.0",
    "eslint": "^9.24.0",
    "tsup": "^8.4.0",
    "typescript": "^5.8.3",
    "typescript-eslint": "^8.32.0",
    "vitest": "^3.2.0"
  }
}
EOF

write_file_heredoc "packages/utils/tsconfig.json" << 'EOF'
{
  "extends": "../../tsconfig.json",
  "compilerOptions": {
    "outDir": "dist",
    "rootDir": "src"
  },
  "include": ["src"]
}
EOF

write_file_heredoc "packages/utils/tsup.config.ts" << 'EOF'
import { defineConfig } from "tsup";

export default defineConfig({
  entry: ["src/index.ts"],
  format: ["esm"],
  dts: true,
  clean: true,
  sourcemap: true,
});
EOF

write_file_heredoc "packages/utils/vitest.config.ts" << 'EOF'
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    globals: true,
    environment: "node",
  },
});
EOF

write_file_heredoc "packages/utils/eslint.config.js" << 'EOF'
import js from "@eslint/js";
import tseslint from "typescript-eslint";

export default tseslint.config(
  js.configs.recommended,
  ...tseslint.configs.recommended,
  { ignores: ["dist/"] },
);
EOF

write_file_heredoc "packages/utils/src/index.ts" << 'EOF'
export { slugify } from "./string.js";
export { deepMerge } from "./object.js";
export { sleep, retry } from "./async.js";
EOF

write_file_heredoc "packages/utils/src/string.ts" << 'EOF'
export function slugify(text: string): string {
  return text
    .toLowerCase()
    .trim()
    .replace(/[^\w\s-]/g, "")
    .replace(/[\s_]+/g, "-")
    .replace(/-+/g, "-");
}
EOF

write_file_heredoc "packages/utils/src/object.ts" << 'EOF'
type Obj = Record<string, unknown>;

export function deepMerge<T extends Obj>(target: T, ...sources: Partial<T>[]): T {
  const result = { ...target };
  for (const source of sources) {
    for (const key in source) {
      const sv = source[key];
      const tv = result[key];
      if (isObject(sv) && isObject(tv)) {
        (result as Obj)[key] = deepMerge(tv as Obj, sv as Obj);
      } else {
        (result as Obj)[key] = sv;
      }
    }
  }
  return result;
}

function isObject(val: unknown): val is Obj {
  return val !== null && typeof val === "object" && !Array.isArray(val);
}
EOF

write_file_heredoc "packages/utils/src/async.ts" << 'EOF'
export function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export async function retry<T>(
  fn: () => Promise<T>,
  options: { attempts?: number; delay?: number } = {},
): Promise<T> {
  const { attempts = 3, delay = 1000 } = options;
  let lastError: unknown;

  for (let i = 0; i < attempts; i++) {
    try {
      return await fn();
    } catch (error) {
      lastError = error;
      if (i < attempts - 1) await sleep(delay);
    }
  }

  throw lastError;
}
EOF

write_file_heredoc "packages/utils/test/string.test.ts" << 'EOF'
import { describe, it, expect } from "vitest";
import { slugify } from "../src/string.js";

describe("slugify", () => {
  it("converts text to slug", () => {
    expect(slugify("Hello World")).toBe("hello-world");
  });

  it("handles special characters", () => {
    expect(slugify("Hello, World! @2024")).toBe("hello-world-2024");
  });

  it("trims whitespace", () => {
    expect(slugify("  hello  ")).toBe("hello");
  });
});
EOF
success "Created packages/utils"

# ══════════════════════════════════════════════════════════════
# packages/cli
# ══════════════════════════════════════════════════════════════
section "packages/cli"
mkdir -p packages/cli/src packages/cli/test

write_file_heredoc "packages/cli/package.json" << 'EOF'
{
  "name": "@repo/cli",
  "version": "0.0.1",
  "type": "module",
  "bin": {
    "repo-cli": "./dist/index.js"
  },
  "files": ["dist"],
  "scripts": {
    "dev": "tsup --watch",
    "build": "tsup",
    "test": "vitest run",
    "test:watch": "vitest",
    "lint": "eslint src/"
  },
  "dependencies": {
    "@repo/core": "workspace:*",
    "@repo/utils": "workspace:*"
  },
  "devDependencies": {
    "@eslint/js": "^9.24.0",
    "eslint": "^9.24.0",
    "tsup": "^8.4.0",
    "typescript": "^5.8.3",
    "typescript-eslint": "^8.32.0",
    "vitest": "^3.2.0"
  }
}
EOF

write_file_heredoc "packages/cli/tsconfig.json" << 'EOF'
{
  "extends": "../../tsconfig.json",
  "compilerOptions": {
    "outDir": "dist",
    "rootDir": "src"
  },
  "include": ["src"]
}
EOF

write_file_heredoc "packages/cli/tsup.config.ts" << 'EOF'
import { defineConfig } from "tsup";

export default defineConfig({
  entry: ["src/index.ts"],
  format: ["esm"],
  dts: true,
  clean: true,
  sourcemap: true,
  banner: {
    js: "#!/usr/bin/env node",
  },
});
EOF

write_file_heredoc "packages/cli/vitest.config.ts" << 'EOF'
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    globals: true,
    environment: "node",
  },
});
EOF

write_file_heredoc "packages/cli/eslint.config.js" << 'EOF'
import js from "@eslint/js";
import tseslint from "typescript-eslint";

export default tseslint.config(
  js.configs.recommended,
  ...tseslint.configs.recommended,
  { ignores: ["dist/"] },
);
EOF

write_file_heredoc "packages/cli/src/index.ts" << 'EOF'
import { ok, err, type Result } from "@repo/core";
import { slugify } from "@repo/utils";

interface Command {
  name: string;
  description: string;
  run: (args: string[]) => Result<string>;
}

const commands: Command[] = [
  {
    name: "slugify",
    description: "Convert text to a URL slug",
    run: (args) => {
      const text = args.join(" ");
      if (!text) return err(new Error("No text provided"));
      return ok(slugify(text));
    },
  },
  {
    name: "help",
    description: "Show available commands",
    run: () => {
      const lines = commands.map((cmd) => `  ${cmd.name.padEnd(12)} ${cmd.description}`);
      return ok(`Available commands:\n${lines.join("\n")}`);
    },
  },
];

function main() {
  const args = process.argv.slice(2);
  const commandName = args[0] ?? "help";
  const command = commands.find((c) => c.name === commandName);

  if (!command) {
    console.error(`Unknown command: ${commandName}`);
    process.exit(1);
  }

  const result = command.run(args.slice(1));
  if (result.ok) {
    console.log(result.value);
  } else {
    console.error(`Error: ${result.error.message}`);
    process.exit(1);
  }
}

main();
EOF

write_file_heredoc "packages/cli/test/cli.test.ts" << 'EOF'
import { describe, it, expect } from "vitest";
import { slugify } from "@repo/utils";

describe("CLI commands", () => {
  it("slugifies text", () => {
    expect(slugify("Hello World")).toBe("hello-world");
  });
});
EOF
success "Created packages/cli"

# ── Finalize ──────────────────────────────────────────────────
section "Finalizing"
init_git
write_gitignore
write_editorconfig
write_nvmrc

write_readme "$PROJECT_NAME" \
  "Turborepo monorepo for publishing TypeScript packages with tsup, Changesets, and Vitest." \
  "pnpm install" \
  "pnpm dev"

finish "pnpm install" "pnpm dev"
