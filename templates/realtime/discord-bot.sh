#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-discord-bot" "$@"
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
    "deploy-commands": "tsx src/deploy-commands.ts",
    "lint": "eslint src/"
  },
  "dependencies": {
    "discord.js": "^14.18.0",
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
write_file "src/index.ts" 'import { Client, Collection, GatewayIntentBits } from "discord.js";
import { config } from "dotenv";
import { loadCommands } from "./handlers/commandHandler.js";
import { loadEvents } from "./handlers/eventHandler.js";

config();

const client = new Client({
  intents: [
    GatewayIntentBits.Guilds,
    GatewayIntentBits.GuildMessages,
    GatewayIntentBits.MessageContent,
  ],
});

// Extend the Client type to include commands collection
declare module "discord.js" {
  interface Client {
    commands: Collection<string, any>;
  }
}

client.commands = new Collection();

async function main() {
  await loadCommands(client);
  await loadEvents(client);

  const token = process.env.DISCORD_TOKEN;
  if (!token) {
    console.error("DISCORD_TOKEN is not set in environment variables");
    process.exit(1);
  }

  await client.login(token);
}

main().catch(console.error);'

# --- src/handlers/commandHandler.ts ---
write_file "src/handlers/commandHandler.ts" 'import { Client, Collection } from "discord.js";
import { pingCommand } from "../commands/ping.js";
import { helpCommand } from "../commands/help.js";
import { serverInfoCommand } from "../commands/serverinfo.js";
import type { SlashCommand } from "../types.js";

const commands: SlashCommand[] = [pingCommand, helpCommand, serverInfoCommand];

export async function loadCommands(client: Client) {
  client.commands = new Collection();

  for (const command of commands) {
    client.commands.set(command.data.name, command);
    console.log(`Loaded command: ${command.data.name}`);
  }
}

export { commands };'

# --- src/handlers/eventHandler.ts ---
write_file "src/handlers/eventHandler.ts" 'import { Client } from "discord.js";
import { onReady } from "../events/ready.js";
import { onInteractionCreate } from "../events/interactionCreate.js";

export async function loadEvents(client: Client) {
  client.once("ready", onReady);
  client.on("interactionCreate", onInteractionCreate);

  console.log("Events loaded");
}'

# --- src/types.ts ---
write_file "src/types.ts" 'import type {
  SlashCommandBuilder,
  ChatInputCommandInteraction,
  SlashCommandOptionsOnlyBuilder,
} from "discord.js";

export interface SlashCommand {
  data: SlashCommandBuilder | SlashCommandOptionsOnlyBuilder;
  execute: (interaction: ChatInputCommandInteraction) => Promise<void>;
}'

# --- src/commands/ping.ts ---
write_file "src/commands/ping.ts" 'import { SlashCommandBuilder, ChatInputCommandInteraction } from "discord.js";
import type { SlashCommand } from "../types.js";

export const pingCommand: SlashCommand = {
  data: new SlashCommandBuilder()
    .setName("ping")
    .setDescription("Replies with Pong and shows latency"),

  async execute(interaction: ChatInputCommandInteraction) {
    const sent = await interaction.reply({
      content: "Pinging...",
      fetchReply: true,
    });

    const latency = sent.createdTimestamp - interaction.createdTimestamp;
    const apiLatency = Math.round(interaction.client.ws.ping);

    await interaction.editReply(
      `Pong! Latency: ${latency}ms | API Latency: ${apiLatency}ms`
    );
  },
};'

# --- src/commands/help.ts ---
write_file "src/commands/help.ts" 'import {
  SlashCommandBuilder,
  ChatInputCommandInteraction,
  EmbedBuilder,
} from "discord.js";
import type { SlashCommand } from "../types.js";

export const helpCommand: SlashCommand = {
  data: new SlashCommandBuilder()
    .setName("help")
    .setDescription("Shows all available commands"),

  async execute(interaction: ChatInputCommandInteraction) {
    const commands = interaction.client.commands;

    const embed = new EmbedBuilder()
      .setTitle("Bot Commands")
      .setDescription("Here are all the available commands:")
      .setColor(0x5865f2)
      .setTimestamp();

    commands.forEach((command: SlashCommand) => {
      embed.addFields({
        name: `/${command.data.name}`,
        value: command.data.description || "No description",
        inline: true,
      });
    });

    await interaction.reply({ embeds: [embed] });
  },
};'

# --- src/commands/serverinfo.ts ---
write_file "src/commands/serverinfo.ts" 'import {
  SlashCommandBuilder,
  ChatInputCommandInteraction,
  EmbedBuilder,
} from "discord.js";
import type { SlashCommand } from "../types.js";

export const serverInfoCommand: SlashCommand = {
  data: new SlashCommandBuilder()
    .setName("serverinfo")
    .setDescription("Shows information about the server"),

  async execute(interaction: ChatInputCommandInteraction) {
    const guild = interaction.guild;
    if (!guild) {
      await interaction.reply("This command can only be used in a server.");
      return;
    }

    const embed = new EmbedBuilder()
      .setTitle(guild.name)
      .setThumbnail(guild.iconURL() || "")
      .setColor(0x5865f2)
      .addFields(
        { name: "Members", value: `${guild.memberCount}`, inline: true },
        { name: "Created", value: guild.createdAt.toLocaleDateString(), inline: true },
        { name: "Channels", value: `${guild.channels.cache.size}`, inline: true },
        { name: "Roles", value: `${guild.roles.cache.size}`, inline: true },
        { name: "Owner", value: `<@${guild.ownerId}>`, inline: true },
        { name: "Boost Level", value: `${guild.premiumTier}`, inline: true },
      )
      .setTimestamp();

    await interaction.reply({ embeds: [embed] });
  },
};'

# --- src/events/ready.ts ---
write_file "src/events/ready.ts" 'import type { Client } from "discord.js";

export function onReady(client: Client<true>) {
  console.log(`Bot is online! Logged in as ${client.user.tag}`);
  console.log(`Serving ${client.guilds.cache.size} server(s)`);

  client.user.setActivity("with slash commands", { type: 0 });
}'

# --- src/events/interactionCreate.ts ---
write_file "src/events/interactionCreate.ts" 'import type { Interaction } from "discord.js";

export async function onInteractionCreate(interaction: Interaction) {
  if (!interaction.isChatInputCommand()) return;

  const command = interaction.client.commands.get(interaction.commandName);

  if (!command) {
    console.error(`No command matching ${interaction.commandName} was found.`);
    return;
  }

  try {
    await command.execute(interaction);
  } catch (error) {
    console.error(`Error executing ${interaction.commandName}:`, error);

    const reply = {
      content: "There was an error while executing this command!",
      ephemeral: true,
    };

    if (interaction.replied || interaction.deferred) {
      await interaction.followUp(reply);
    } else {
      await interaction.reply(reply);
    }
  }
}'

# --- src/deploy-commands.ts ---
write_file "src/deploy-commands.ts" 'import { REST, Routes } from "discord.js";
import { config } from "dotenv";
import { commands } from "./handlers/commandHandler.js";

config();

const token = process.env.DISCORD_TOKEN;
const clientId = process.env.DISCORD_CLIENT_ID;
const guildId = process.env.DISCORD_GUILD_ID;

if (!token || !clientId) {
  console.error("DISCORD_TOKEN and DISCORD_CLIENT_ID are required");
  process.exit(1);
}

const rest = new REST().setToken(token);

const commandData = commands.map((cmd) => cmd.data.toJSON());

async function deployCommands() {
  try {
    console.log(`Deploying ${commandData.length} slash commands...`);

    if (guildId) {
      // Deploy to specific guild (instant, good for development)
      await rest.put(Routes.applicationGuildCommands(clientId, guildId), {
        body: commandData,
      });
      console.log(`Commands deployed to guild ${guildId}`);
    } else {
      // Deploy globally (takes up to 1 hour to propagate)
      await rest.put(Routes.applicationCommands(clientId), {
        body: commandData,
      });
      console.log("Commands deployed globally");
    }
  } catch (error) {
    console.error("Failed to deploy commands:", error);
  }
}

deployCommands();'

# --- .env.example ---
write_file ".env.example" '# Discord Bot Token (from https://discord.com/developers/applications)
DISCORD_TOKEN=your-bot-token-here

# Discord Application Client ID
DISCORD_CLIENT_ID=your-client-id-here

# Optional: Guild ID for faster command deployment during development
DISCORD_GUILD_ID=your-guild-id-here'

init_git
write_gitignore
write_editorconfig
write_nvmrc

finish "npm install" "npm run dev"
