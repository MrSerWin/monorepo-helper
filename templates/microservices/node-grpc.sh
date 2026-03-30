#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-node-grpc" "$@"
create_project_dir

# --- package.json ---
write_package_json '{
  "name": "'"$PROJECT_NAME"'",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "tsx watch src/server.ts",
    "build": "tsc",
    "start": "node dist/server.js",
    "client": "tsx src/client.ts",
    "proto:gen": "bash scripts/generate-proto.sh"
  },
  "dependencies": {
    "@grpc/grpc-js": "^1.12.0",
    "@grpc/proto-loader": "^0.7.13",
    "dotenv": "^16.4.7"
  },
  "devDependencies": {
    "@types/node": "^22.14.0",
    "grpc-tools": "^1.12.4",
    "grpc_tools_node_protoc_ts": "^5.3.3",
    "tsx": "^4.19.0",
    "typescript": "^5.8.3"
  }
}'

# --- tsconfig.json ---
write_tsconfig '{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "outDir": "dist",
    "rootDir": "src",
    "declaration": true,
    "sourceMap": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}'

# --- .env.example ---
write_file ".env.example" '# gRPC Server Configuration
GRPC_HOST=0.0.0.0
GRPC_PORT=50051'

# --- proto/service.proto ---
write_file "proto/service.proto" 'syntax = "proto3";

package greeter;

// The greeting service definition.
service GreeterService {
  // Sends a greeting
  rpc SayHello (HelloRequest) returns (HelloReply) {}
  // Sends a greeting with server streaming
  rpc SayHelloStream (HelloRequest) returns (stream HelloReply) {}
  // Lists all greetings
  rpc ListGreetings (ListGreetingsRequest) returns (ListGreetingsReply) {}
}

message HelloRequest {
  string name = 1;
}

message HelloReply {
  string message = 1;
  string timestamp = 2;
}

message ListGreetingsRequest {
  int32 page_size = 1;
  string page_token = 2;
}

message ListGreetingsReply {
  repeated HelloReply greetings = 1;
  string next_page_token = 2;
}'

# --- scripts/generate-proto.sh ---
write_file "scripts/generate-proto.sh" '#!/usr/bin/env bash
set -euo pipefail

PROTO_DIR="proto"
OUT_DIR="src/generated"

mkdir -p "$OUT_DIR"

# Generate TypeScript definitions from proto files
npx grpc_tools_node_protoc \
  --js_out=import_style=commonjs,binary:"$OUT_DIR" \
  --grpc_out=grpc_js:"$OUT_DIR" \
  --plugin=protoc-gen-grpc=./node_modules/.bin/grpc_tools_node_protoc_plugin \
  -I "$PROTO_DIR" \
  "$PROTO_DIR"/*.proto

npx grpc_tools_node_protoc \
  --plugin=protoc-gen-ts=./node_modules/.bin/protoc-gen-ts \
  --ts_out=grpc_js:"$OUT_DIR" \
  -I "$PROTO_DIR" \
  "$PROTO_DIR"/*.proto

echo "Proto files generated in $OUT_DIR"'

# --- src/config/grpc.ts ---
write_file "src/config/grpc.ts" 'import "dotenv/config";

export const GRPC_HOST = process.env.GRPC_HOST || "0.0.0.0";
export const GRPC_PORT = process.env.GRPC_PORT || "50051";
export const GRPC_ADDRESS = `${GRPC_HOST}:${GRPC_PORT}`;'

# --- src/services/greeter.ts ---
write_file "src/services/greeter.ts" 'import type * as grpc from "@grpc/grpc-js";

interface HelloRequest {
  name: string;
}

interface HelloReply {
  message: string;
  timestamp: string;
}

interface ListGreetingsRequest {
  pageSize: number;
  pageToken: string;
}

interface ListGreetingsReply {
  greetings: HelloReply[];
  nextPageToken: string;
}

// In-memory store for demo purposes
const greetingsStore: HelloReply[] = [];

export const greeterService = {
  sayHello(
    call: grpc.ServerUnaryCall<HelloRequest, HelloReply>,
    callback: grpc.sendUnaryData<HelloReply>
  ): void {
    const reply: HelloReply = {
      message: `Hello, ${call.request.name}!`,
      timestamp: new Date().toISOString(),
    };
    greetingsStore.push(reply);
    console.log(`SayHello: ${call.request.name}`);
    callback(null, reply);
  },

  sayHelloStream(
    call: grpc.ServerWritableStream<HelloRequest, HelloReply>
  ): void {
    const name = call.request.name;
    console.log(`SayHelloStream: ${name}`);

    const greetings = [
      `Hello, ${name}!`,
      `How are you, ${name}?`,
      `Nice to meet you, ${name}!`,
    ];

    let index = 0;
    const interval = setInterval(() => {
      if (index >= greetings.length) {
        clearInterval(interval);
        call.end();
        return;
      }
      call.write({
        message: greetings[index],
        timestamp: new Date().toISOString(),
      });
      index++;
    }, 1000);
  },

  listGreetings(
    call: grpc.ServerUnaryCall<ListGreetingsRequest, ListGreetingsReply>,
    callback: grpc.sendUnaryData<ListGreetingsReply>
  ): void {
    const pageSize = call.request.pageSize || 10;
    const startIndex = call.request.pageToken
      ? parseInt(call.request.pageToken, 10)
      : 0;

    const greetings = greetingsStore.slice(startIndex, startIndex + pageSize);
    const nextPageToken =
      startIndex + pageSize < greetingsStore.length
        ? String(startIndex + pageSize)
        : "";

    callback(null, { greetings, nextPageToken });
  },
};'

# --- src/server.ts ---
write_file "src/server.ts" 'import * as grpc from "@grpc/grpc-js";
import * as protoLoader from "@grpc/proto-loader";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { GRPC_ADDRESS } from "./config/grpc.js";
import { greeterService } from "./services/greeter.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const PROTO_PATH = path.resolve(__dirname, "../proto/service.proto");

const packageDefinition = protoLoader.loadSync(PROTO_PATH, {
  keepCase: false,
  longs: String,
  enums: String,
  defaults: true,
  oneofs: true,
});

const protoDescriptor = grpc.loadPackageDefinition(packageDefinition) as any;
const greeterProto = protoDescriptor.greeter;

function main(): void {
  const server = new grpc.Server();

  server.addService(greeterProto.GreeterService.service, greeterService);

  server.bindAsync(
    GRPC_ADDRESS,
    grpc.ServerCredentials.createInsecure(),
    (error, port) => {
      if (error) {
        console.error("Failed to start server:", error);
        process.exit(1);
      }
      console.log(`gRPC server running on ${GRPC_ADDRESS}`);
    }
  );

  // Graceful shutdown
  const shutdown = () => {
    console.log("\nShutting down gRPC server...");
    server.tryShutdown(() => {
      console.log("Server shut down");
      process.exit(0);
    });
  };

  process.on("SIGINT", shutdown);
  process.on("SIGTERM", shutdown);
}

main();'

# --- src/client.ts ---
write_file "src/client.ts" 'import * as grpc from "@grpc/grpc-js";
import * as protoLoader from "@grpc/proto-loader";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { GRPC_ADDRESS } from "./config/grpc.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const PROTO_PATH = path.resolve(__dirname, "../proto/service.proto");

const packageDefinition = protoLoader.loadSync(PROTO_PATH, {
  keepCase: false,
  longs: String,
  enums: String,
  defaults: true,
  oneofs: true,
});

const protoDescriptor = grpc.loadPackageDefinition(packageDefinition) as any;
const greeterProto = protoDescriptor.greeter;

const client = new greeterProto.GreeterService(
  GRPC_ADDRESS,
  grpc.credentials.createInsecure()
);

// Unary call
console.log("--- Unary Call ---");
client.sayHello({ name: "World" }, (error: any, response: any) => {
  if (error) {
    console.error("Error:", error.message);
    return;
  }
  console.log("Response:", response);

  // Server streaming call
  console.log("\n--- Server Streaming ---");
  const stream = client.sayHelloStream({ name: "World" });

  stream.on("data", (data: any) => {
    console.log("Stream data:", data);
  });

  stream.on("end", () => {
    console.log("Stream ended");

    // List greetings
    console.log("\n--- List Greetings ---");
    client.listGreetings(
      { pageSize: 10, pageToken: "" },
      (error: any, response: any) => {
        if (error) {
          console.error("Error:", error.message);
          return;
        }
        console.log("Greetings:", response);
        process.exit(0);
      }
    );
  });

  stream.on("error", (error: any) => {
    console.error("Stream error:", error.message);
  });
});'

init_git
write_gitignore "src/generated/"
write_editorconfig
write_nvmrc

finish "npm install" "npm run dev"
