#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-node-kafka" "$@"
create_project_dir

# --- package.json ---
write_package_json '{
  "name": "'"$PROJECT_NAME"'",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "tsx watch src/index.ts",
    "build": "tsc",
    "start": "node dist/index.js",
    "produce": "tsx src/producer.ts",
    "consume": "tsx src/consumer.ts"
  },
  "dependencies": {
    "kafkajs": "^2.2.4",
    "dotenv": "^16.4.7"
  },
  "devDependencies": {
    "@types/node": "^22.14.0",
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
write_file ".env.example" '# Kafka Configuration
KAFKA_BROKERS=localhost:9092
KAFKA_CLIENT_ID='"$PROJECT_NAME"'
KAFKA_GROUP_ID='"$PROJECT_NAME"'-group

# Topic Configuration
KAFKA_TOPIC=events'

# --- src/config/kafka.ts ---
write_file "src/config/kafka.ts" 'import { Kafka, logLevel } from "kafkajs";
import "dotenv/config";

const brokers = (process.env.KAFKA_BROKERS || "localhost:9092").split(",");
const clientId = process.env.KAFKA_CLIENT_ID || "'"$PROJECT_NAME"'";

export const kafka = new Kafka({
  clientId,
  brokers,
  logLevel: logLevel.INFO,
  retry: {
    initialRetryTime: 100,
    retries: 8,
  },
});

export const TOPIC = process.env.KAFKA_TOPIC || "events";
export const GROUP_ID = process.env.KAFKA_GROUP_ID || "'"$PROJECT_NAME"'-group";'

# --- src/handlers/event-handler.ts ---
write_file "src/handlers/event-handler.ts" 'import type { EachMessagePayload } from "kafkajs";

export interface EventMessage {
  type: string;
  data: Record<string, unknown>;
  timestamp: string;
}

export async function handleEvent({ topic, partition, message }: EachMessagePayload): Promise<void> {
  const key = message.key?.toString();
  const value = message.value?.toString();

  if (!value) {
    console.warn(`Received empty message on ${topic}[${partition}]`);
    return;
  }

  try {
    const event: EventMessage = JSON.parse(value);
    console.log(`[${topic}][${partition}] key=${key}`, {
      type: event.type,
      data: event.data,
      timestamp: event.timestamp,
    });

    // Handle different event types
    switch (event.type) {
      case "user.created":
        await handleUserCreated(event.data);
        break;
      case "order.placed":
        await handleOrderPlaced(event.data);
        break;
      default:
        console.log(`Unhandled event type: ${event.type}`);
    }
  } catch (error) {
    console.error("Failed to process message:", error);
  }
}

async function handleUserCreated(data: Record<string, unknown>): Promise<void> {
  console.log("Processing user.created event:", data);
  // Add your business logic here
}

async function handleOrderPlaced(data: Record<string, unknown>): Promise<void> {
  console.log("Processing order.placed event:", data);
  // Add your business logic here
}'

# --- src/producer.ts ---
write_file "src/producer.ts" 'import { kafka, TOPIC } from "./config/kafka.js";
import type { EventMessage } from "./handlers/event-handler.js";

const producer = kafka.producer();

async function produce(): Promise<void> {
  await producer.connect();
  console.log("Producer connected");

  const event: EventMessage = {
    type: "user.created",
    data: {
      id: crypto.randomUUID(),
      email: "user@example.com",
      name: "John Doe",
    },
    timestamp: new Date().toISOString(),
  };

  await producer.send({
    topic: TOPIC,
    messages: [
      {
        key: event.data.id as string,
        value: JSON.stringify(event),
      },
    ],
  });

  console.log("Message sent:", event);
  await producer.disconnect();
}

produce().catch(console.error);'

# --- src/consumer.ts ---
write_file "src/consumer.ts" 'import { kafka, TOPIC, GROUP_ID } from "./config/kafka.js";
import { handleEvent } from "./handlers/event-handler.js";

const consumer = kafka.consumer({ groupId: GROUP_ID });

async function consume(): Promise<void> {
  await consumer.connect();
  console.log("Consumer connected");

  await consumer.subscribe({ topic: TOPIC, fromBeginning: true });
  console.log(`Subscribed to topic: ${TOPIC}`);

  await consumer.run({
    eachMessage: handleEvent,
  });
}

// Graceful shutdown
const shutdown = async () => {
  console.log("\nShutting down consumer...");
  await consumer.disconnect();
  process.exit(0);
};

process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);

consume().catch(console.error);'

# --- src/index.ts ---
write_file "src/index.ts" 'import { kafka, TOPIC, GROUP_ID } from "./config/kafka.js";
import { handleEvent } from "./handlers/event-handler.js";

async function main(): Promise<void> {
  const admin = kafka.admin();
  await admin.connect();

  // Create topic if it doesn'\''t exist
  const topics = await admin.listTopics();
  if (!topics.includes(TOPIC)) {
    await admin.createTopics({
      topics: [{ topic: TOPIC, numPartitions: 3, replicationFactor: 1 }],
    });
    console.log(`Created topic: ${TOPIC}`);
  }
  await admin.disconnect();

  // Start consumer
  const consumer = kafka.consumer({ groupId: GROUP_ID });
  await consumer.connect();
  await consumer.subscribe({ topic: TOPIC, fromBeginning: true });
  console.log(`Consumer started, listening on topic: ${TOPIC}`);

  await consumer.run({
    eachMessage: handleEvent,
  });

  // Graceful shutdown
  const shutdown = async () => {
    console.log("\nShutting down...");
    await consumer.disconnect();
    process.exit(0);
  };

  process.on("SIGINT", shutdown);
  process.on("SIGTERM", shutdown);
}

main().catch(console.error);'

# --- docker-compose.yml ---
write_file "docker-compose.yml" 'services:
  zookeeper:
    image: confluentinc/cp-zookeeper:7.7.0
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
      ZOOKEEPER_TICK_TIME: 2000
    ports:
      - "2181:2181"

  kafka:
    image: confluentinc/cp-kafka:7.7.0
    depends_on:
      - zookeeper
    ports:
      - "9092:9092"
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9092
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
      KAFKA_AUTO_CREATE_TOPICS_ENABLE: "true"

  app:
    build: .
    depends_on:
      - kafka
    environment:
      KAFKA_BROKERS: kafka:9092
      KAFKA_CLIENT_ID: '"$PROJECT_NAME"'
      KAFKA_GROUP_ID: '"$PROJECT_NAME"'-group
      KAFKA_TOPIC: events'

# --- Dockerfile ---
write_file "Dockerfile" 'FROM node:22-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:22-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY --from=builder /app/dist ./dist
CMD ["node", "dist/index.js"]'

init_git
write_gitignore
write_editorconfig
write_nvmrc

finish "docker compose up -d" "npm install && npm run dev"
