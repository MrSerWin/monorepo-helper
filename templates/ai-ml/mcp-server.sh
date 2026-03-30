#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-mcp-server" "$@"
header "Node.js 22 + TypeScript + MCP Server"

create_project_dir

# ── package.json ──────────────────────────────────────────────
section "Package configuration"
write_package_json '{
  "name": "'"$PROJECT_NAME"'",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "bin": {
    "'"$PROJECT_NAME"'": "dist/index.js"
  },
  "scripts": {
    "dev": "tsx watch src/index.ts",
    "build": "tsc",
    "start": "node dist/index.js",
    "lint": "eslint .",
    "inspect": "npx @modelcontextprotocol/inspector node dist/index.js"
  },
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.12.0",
    "zod": "^3.24.3"
  },
  "devDependencies": {
    "@eslint/js": "^9.24.0",
    "@types/node": "^22.14.0",
    "eslint": "^9.24.0",
    "tsx": "^4.19.0",
    "typescript": "^5.8.3",
    "typescript-eslint": "^8.32.0"
  }
}'

# ── tsconfig.json ─────────────────────────────────────────────
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

# ── eslint.config.js ─────────────────────────────────────────
write_file_heredoc "eslint.config.js" << 'EOF'
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

# ── src/index.ts ──────────────────────────────────────────────
section "Application source files"
write_file_heredoc "src/index.ts" << 'EOF'
#!/usr/bin/env node

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { registerTools } from "./tools/index.js";
import { registerResources } from "./resources/index.js";

const server = new McpServer({
  name: "my-mcp-server",
  version: "0.1.0",
});

// Register tools and resources
registerTools(server);
registerResources(server);

// Start the server with stdio transport
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("MCP server running on stdio");
}

main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
EOF
success "Created src/index.ts"

# ── src/tools/index.ts ───────────────────────────────────────
write_file_heredoc "src/tools/index.ts" << 'EOF'
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { registerGreetTool } from "./greet.js";
import { registerCalculateTool } from "./calculate.js";

export function registerTools(server: McpServer): void {
  registerGreetTool(server);
  registerCalculateTool(server);
}
EOF
success "Created src/tools/index.ts"

# ── src/tools/greet.ts ───────────────────────────────────────
write_file_heredoc "src/tools/greet.ts" << 'EOF'
import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";

export function registerGreetTool(server: McpServer): void {
  server.tool(
    "greet",
    "Generate a greeting message for a given name",
    {
      name: z.string().describe("The name to greet"),
      style: z
        .enum(["formal", "casual", "enthusiastic"])
        .optional()
        .default("casual")
        .describe("The greeting style"),
    },
    async ({ name, style }) => {
      let greeting: string;
      switch (style) {
        case "formal":
          greeting = `Good day, ${name}. It is a pleasure to make your acquaintance.`;
          break;
        case "enthusiastic":
          greeting = `Hey ${name}!! So awesome to meet you! This is going to be great!`;
          break;
        case "casual":
        default:
          greeting = `Hey ${name}, nice to meet you!`;
          break;
      }

      return {
        content: [{ type: "text", text: greeting }],
      };
    },
  );
}
EOF
success "Created src/tools/greet.ts"

# ── src/tools/calculate.ts ───────────────────────────────────
write_file_heredoc "src/tools/calculate.ts" << 'EOF'
import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";

export function registerCalculateTool(server: McpServer): void {
  server.tool(
    "calculate",
    "Perform a basic arithmetic calculation",
    {
      operation: z
        .enum(["add", "subtract", "multiply", "divide"])
        .describe("The arithmetic operation to perform"),
      a: z.number().describe("The first operand"),
      b: z.number().describe("The second operand"),
    },
    async ({ operation, a, b }) => {
      let result: number;
      switch (operation) {
        case "add":
          result = a + b;
          break;
        case "subtract":
          result = a - b;
          break;
        case "multiply":
          result = a * b;
          break;
        case "divide":
          if (b === 0) {
            return {
              content: [{ type: "text", text: "Error: Division by zero" }],
              isError: true,
            };
          }
          result = a / b;
          break;
      }

      return {
        content: [
          {
            type: "text",
            text: `${a} ${operation} ${b} = ${result}`,
          },
        ],
      };
    },
  );
}
EOF
success "Created src/tools/calculate.ts"

# ── src/resources/index.ts ───────────────────────────────────
write_file_heredoc "src/resources/index.ts" << 'EOF'
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { registerConfigResource } from "./config.js";

export function registerResources(server: McpServer): void {
  registerConfigResource(server);
}
EOF
success "Created src/resources/index.ts"

# ── src/resources/config.ts ──────────────────────────────────
write_file_heredoc "src/resources/config.ts" << 'EOF'
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";

const SERVER_CONFIG = {
  name: "my-mcp-server",
  version: "0.1.0",
  environment: process.env.NODE_ENV ?? "development",
  capabilities: ["tools", "resources"],
};

export function registerConfigResource(server: McpServer): void {
  server.resource(
    "server-config",
    "config://server",
    {
      description: "Current server configuration and capabilities",
      mimeType: "application/json",
    },
    async () => ({
      contents: [
        {
          uri: "config://server",
          mimeType: "application/json",
          text: JSON.stringify(SERVER_CONFIG, null, 2),
        },
      ],
    }),
  );
}
EOF
success "Created src/resources/config.ts"

# ── Finalize ──────────────────────────────────────────────────
section "Finalizing"
init_git
write_gitignore
write_editorconfig
write_nvmrc "22"

write_readme "$PROJECT_NAME" \
  "MCP (Model Context Protocol) server built with TypeScript and @modelcontextprotocol/sdk. Provides tools and resources for AI assistants." \
  "npm install" \
  "npm run dev" \
  "- \`npm run dev\` - Start in development mode with hot reload
- \`npm run build\` - Build for production
- \`npm run inspect\` - Open MCP Inspector for testing"

finish "npm install && npm run build" "npm run dev"
