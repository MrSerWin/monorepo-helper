#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-telegram-bot" "$@"
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
    "lint": "eslint src/"
  },
  "dependencies": {
    "grammy": "^1.35.0",
    "dotenv": "^16.4.0"
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
    "outDir": "./dist",
    "rootDir": "./src",
    "declaration": true,
    "sourceMap": true,
    "resolveJsonModule": true,
    "allowImportingTsExtensions": false
  },
  "include": ["src"],
  "exclude": ["node_modules", "dist"]
}'

# --- src/index.ts ---
write_file "src/index.ts" 'import { Bot, session } from "grammy";
import { config } from "dotenv";
import { registerCommands } from "./commands/index.js";
import { registerHandlers } from "./handlers/index.js";
import type { BotContext } from "./types.js";

config();

const token = process.env.BOT_TOKEN;
if (!token) {
  console.error("BOT_TOKEN is not set in environment variables");
  process.exit(1);
}

const bot = new Bot<BotContext>(token);

// Session middleware for storing per-chat data
bot.use(
  session({
    initial: () => ({
      messageCount: 0,
    }),
  })
);

// Register all commands and handlers
registerCommands(bot);
registerHandlers(bot);

// Error handler
bot.catch((err) => {
  const ctx = err.ctx;
  console.error(`Error while handling update ${ctx.update.update_id}:`);
  console.error(err.error);
});

// Start the bot
bot.start({
  onStart: (botInfo) => {
    console.log(`Bot @${botInfo.username} is running!`);
  },
});

// Graceful shutdown
const shutdown = () => {
  console.log("Shutting down...");
  bot.stop();
};

process.once("SIGINT", shutdown);
process.once("SIGTERM", shutdown);'

# --- src/types.ts ---
write_file "src/types.ts" 'import type { Context, SessionFlavor } from "grammy";

export interface SessionData {
  messageCount: number;
}

export type BotContext = Context & SessionFlavor<SessionData>;'

# --- src/commands/index.ts ---
write_file "src/commands/index.ts" 'import type { Bot } from "grammy";
import type { BotContext } from "../types.js";
import { startCommand } from "./start.js";
import { helpCommand } from "./help.js";
import { statsCommand } from "./stats.js";
import { settingsCommand } from "./settings.js";

export function registerCommands(bot: Bot<BotContext>) {
  // Register command handlers
  bot.command("start", startCommand);
  bot.command("help", helpCommand);
  bot.command("stats", statsCommand);
  bot.command("settings", settingsCommand);

  // Set bot commands menu
  bot.api.setMyCommands([
    { command: "start", description: "Start the bot" },
    { command: "help", description: "Show available commands" },
    { command: "stats", description: "Show your message stats" },
    { command: "settings", description: "Bot settings" },
  ]).catch(console.error);
}'

# --- src/commands/start.ts ---
write_file "src/commands/start.ts" 'import type { BotContext } from "../types.js";
import { mainMenuKeyboard } from "../keyboards/mainMenu.js";

export async function startCommand(ctx: BotContext) {
  const name = ctx.from?.first_name || "there";

  await ctx.reply(
    `Welcome, ${name}! I am your bot assistant.\n\nUse the buttons below or type /help to see available commands.`,
    {
      reply_markup: mainMenuKeyboard,
    }
  );
}'

# --- src/commands/help.ts ---
write_file "src/commands/help.ts" 'import type { BotContext } from "../types.js";

export async function helpCommand(ctx: BotContext) {
  const helpText = [
    "<b>Available Commands</b>",
    "",
    "/start - Start the bot and show main menu",
    "/help - Show this help message",
    "/stats - Show your message statistics",
    "/settings - Bot settings",
    "",
    "<i>You can also use the inline keyboard buttons for quick access.</i>",
  ].join("\n");

  await ctx.reply(helpText, { parse_mode: "HTML" });
}'

# --- src/commands/stats.ts ---
write_file "src/commands/stats.ts" 'import type { BotContext } from "../types.js";

export async function statsCommand(ctx: BotContext) {
  const count = ctx.session.messageCount;
  const name = ctx.from?.first_name || "User";

  await ctx.reply(
    `<b>Stats for ${name}</b>\n\nMessages sent: ${count}`,
    { parse_mode: "HTML" }
  );
}'

# --- src/commands/settings.ts ---
write_file "src/commands/settings.ts" 'import type { BotContext } from "../types.js";
import { settingsKeyboard } from "../keyboards/settings.js";

export async function settingsCommand(ctx: BotContext) {
  await ctx.reply("Bot Settings", {
    reply_markup: settingsKeyboard,
  });
}'

# --- src/handlers/index.ts ---
write_file "src/handlers/index.ts" 'import type { Bot } from "grammy";
import type { BotContext } from "../types.js";
import { handleMessage } from "./message.js";
import { handleCallbackQuery } from "./callback.js";

export function registerHandlers(bot: Bot<BotContext>) {
  // Handle callback queries from inline keyboards
  bot.on("callback_query:data", handleCallbackQuery);

  // Handle text messages (must be last)
  bot.on("message:text", handleMessage);
}'

# --- src/handlers/message.ts ---
write_file "src/handlers/message.ts" 'import type { BotContext } from "../types.js";

export async function handleMessage(ctx: BotContext) {
  // Increment message counter
  ctx.session.messageCount += 1;

  const text = ctx.message?.text;
  if (!text) return;

  // Echo handler for demonstration
  if (text.toLowerCase().startsWith("echo ")) {
    const echoText = text.slice(5);
    await ctx.reply(echoText);
    return;
  }

  // Auto-reply for greetings
  const greetings = ["hi", "hello", "hey", "greetings"];
  if (greetings.includes(text.toLowerCase())) {
    const name = ctx.from?.first_name || "there";
    await ctx.reply(`Hello, ${name}! Type /help to see what I can do.`);
  }
}'

# --- src/handlers/callback.ts ---
write_file "src/handlers/callback.ts" 'import type { BotContext } from "../types.js";
import { mainMenuKeyboard } from "../keyboards/mainMenu.js";

export async function handleCallbackQuery(ctx: BotContext) {
  const data = ctx.callbackQuery?.data;
  if (!data) return;

  switch (data) {
    case "menu_help":
      await ctx.answerCallbackQuery();
      await ctx.reply(
        "Use /help to see all available commands.",
      );
      break;

    case "menu_stats":
      await ctx.answerCallbackQuery();
      const count = ctx.session.messageCount;
      await ctx.reply(`Messages sent: ${count}`);
      break;

    case "menu_main":
      await ctx.answerCallbackQuery();
      await ctx.editMessageText("Main Menu", {
        reply_markup: mainMenuKeyboard,
      });
      break;

    case "settings_reset":
      ctx.session.messageCount = 0;
      await ctx.answerCallbackQuery({ text: "Stats reset!" });
      await ctx.editMessageText("Stats have been reset.", {
        reply_markup: mainMenuKeyboard,
      });
      break;

    default:
      await ctx.answerCallbackQuery({ text: "Unknown action" });
  }
}'

# --- src/keyboards/mainMenu.ts ---
write_file "src/keyboards/mainMenu.ts" 'import { InlineKeyboard } from "grammy";

export const mainMenuKeyboard = new InlineKeyboard()
  .text("Help", "menu_help")
  .text("Stats", "menu_stats")
  .row()
  .url("GitHub", "https://github.com");'

# --- src/keyboards/settings.ts ---
write_file "src/keyboards/settings.ts" 'import { InlineKeyboard } from "grammy";

export const settingsKeyboard = new InlineKeyboard()
  .text("Reset Stats", "settings_reset")
  .row()
  .text("Back to Main Menu", "menu_main");'

# --- .env.example ---
write_file ".env.example" '# Telegram Bot Token (from @BotFather)
BOT_TOKEN=your-bot-token-here'

init_git
write_gitignore
write_editorconfig
write_nvmrc

finish "npm install" "npm run dev"
