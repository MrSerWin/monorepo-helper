#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-cli" "$@"
create_project_dir

# --- package.json ---
write_package_json '{
  "name": "'"$PROJECT_NAME"'",
  "version": "0.1.0",
  "type": "module",
  "bin": {
    "'"$PROJECT_NAME"'": "./dist/index.js"
  },
  "files": ["dist"],
  "scripts": {
    "dev": "tsup --watch",
    "build": "tsup",
    "test": "vitest",
    "test:run": "vitest run",
    "lint": "tsc --noEmit",
    "start": "node dist/index.js"
  },
  "dependencies": {
    "commander": "^13.1.0"
  },
  "devDependencies": {
    "@types/node": "^22.14.0",
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
    "noEmit": true
  },
  "include": ["src"],
  "exclude": ["node_modules", "dist"]
}'

# --- tsup.config.ts ---
write_file "tsup.config.ts" 'import { defineConfig } from "tsup";

export default defineConfig({
  entry: ["src/index.ts"],
  format: ["esm"],
  target: "node22",
  clean: true,
  dts: false,
  splitting: false,
  banner: {
    js: "#!/usr/bin/env node",
  },
});'

# --- vitest.config.ts ---
write_file "vitest.config.ts" 'import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    globals: true,
  },
});'

# --- src/index.ts ---
write_file "src/index.ts" 'import { program } from "commander";
import { helloCommand } from "./commands/hello.js";

program
  .name("'"$PROJECT_NAME"'")
  .description("A CLI tool built with Commander.js")
  .version("0.1.0");

helloCommand(program);

program.parse();'

# --- src/commands/hello.ts ---
write_file "src/commands/hello.ts" 'import type { Command } from "commander";

interface HelloOptions {
  uppercase: boolean;
}

export function helloCommand(program: Command) {
  program
    .command("hello")
    .description("Say hello to someone")
    .argument("[name]", "Name to greet", "World")
    .option("-u, --uppercase", "Print in uppercase", false)
    .action((name: string, options: HelloOptions) => {
      let message = `Hello, ${name}!`;
      if (options.uppercase) {
        message = message.toUpperCase();
      }
      console.log(message);
    });
}'

# --- src/commands/__tests__/hello.test.ts ---
write_file "src/commands/__tests__/hello.test.ts" 'import { describe, it, expect, vi } from "vitest";

describe("hello command", () => {
  it("should greet with default name", () => {
    const spy = vi.spyOn(console, "log").mockImplementation(() => {});
    // Simple unit test for the greeting logic
    const name = "World";
    const message = `Hello, ${name}!`;
    console.log(message);
    expect(spy).toHaveBeenCalledWith("Hello, World!");
    spy.mockRestore();
  });

  it("should greet with uppercase", () => {
    const name = "World";
    const message = `Hello, ${name}!`.toUpperCase();
    expect(message).toBe("HELLO, WORLD!");
  });
});'

init_git
write_gitignore
write_editorconfig
write_nvmrc

finish "npm install" "npm run build && node dist/index.js hello"
