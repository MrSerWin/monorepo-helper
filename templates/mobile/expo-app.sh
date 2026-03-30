#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-expo-app" "$@"
create_project_dir

# --- package.json ---
write_package_json '{
  "name": "'"$PROJECT_NAME"'",
  "version": "1.0.0",
  "main": "expo-router/entry",
  "private": true,
  "scripts": {
    "start": "expo start",
    "android": "expo start --android",
    "ios": "expo start --ios",
    "web": "expo start --web",
    "lint": "eslint .",
    "ts:check": "tsc --noEmit"
  },
  "dependencies": {
    "expo": "~52.0.0",
    "expo-constants": "~17.0.0",
    "expo-linking": "~7.0.0",
    "expo-router": "~4.0.0",
    "expo-splash-screen": "~0.29.0",
    "expo-status-bar": "~2.0.0",
    "expo-system-ui": "~4.0.0",
    "expo-web-browser": "~14.0.0",
    "nativewind": "~4.1.0",
    "react": "18.3.1",
    "react-dom": "18.3.1",
    "react-native": "0.76.6",
    "react-native-reanimated": "~3.16.0",
    "react-native-safe-area-context": "~4.14.0",
    "react-native-screens": "~4.4.0",
    "react-native-web": "~0.19.13"
  },
  "devDependencies": {
    "@babel/core": "^7.26.0",
    "@types/react": "~18.3.0",
    "eslint": "^9.0.0",
    "tailwindcss": "^3.4.0",
    "typescript": "~5.8.0"
  }
}'

# --- app.json ---
write_file "app.json" '{
  "expo": {
    "name": "'"$PROJECT_NAME"'",
    "slug": "'"$PROJECT_NAME"'",
    "version": "1.0.0",
    "orientation": "portrait",
    "icon": "./assets/images/icon.png",
    "scheme": "'"$PROJECT_NAME"'",
    "userInterfaceStyle": "automatic",
    "newArchEnabled": true,
    "splash": {
      "image": "./assets/images/splash-icon.png",
      "resizeMode": "contain",
      "backgroundColor": "#ffffff"
    },
    "ios": {
      "supportsTablet": true,
      "bundleIdentifier": "com.example.'"${PROJECT_NAME//\-/}"'"
    },
    "android": {
      "adaptiveIcon": {
        "foregroundImage": "./assets/images/adaptive-icon.png",
        "backgroundColor": "#ffffff"
      },
      "package": "com.example.'"${PROJECT_NAME//\-/}"'"
    },
    "web": {
      "bundler": "metro",
      "output": "static",
      "favicon": "./assets/images/favicon.png"
    },
    "plugins": [
      "expo-router"
    ],
    "experiments": {
      "typedRoutes": true
    }
  }
}'

# --- tsconfig.json ---
write_tsconfig '{
  "extends": "expo/tsconfig.base",
  "compilerOptions": {
    "strict": true,
    "paths": {
      "@/*": ["./*"]
    }
  },
  "include": ["**/*.ts", "**/*.tsx", ".expo/types/**/*.ts", "expo-env.d.ts"]
}'

# --- tailwind.config.js ---
write_file "tailwind.config.js" '/** @type {import("tailwindcss").Config} */
module.exports = {
  content: ["./app/**/*.{js,jsx,ts,tsx}", "./components/**/*.{js,jsx,ts,tsx}"],
  presets: [require("nativewind/preset")],
  theme: {
    extend: {},
  },
  plugins: [],
};'

# --- global.css ---
write_file "global.css" '@tailwind base;
@tailwind components;
@tailwind utilities;'

# --- nativewind-env.d.ts ---
write_file "nativewind-env.d.ts" '/// <reference types="nativewind/types" />'

# --- babel.config.js ---
write_file "babel.config.js" 'module.exports = function (api) {
  api.cache(true);
  return {
    presets: [
      ["babel-preset-expo", { jsxImportSource: "nativewind" }],
      "nativewind/babel",
    ],
  };
};'

# --- metro.config.js ---
write_file "metro.config.js" 'const { getDefaultConfig } = require("expo/metro-config");
const { withNativeWind } = require("nativewind/metro");

const config = getDefaultConfig(__dirname);

module.exports = withNativeWind(config, { input: "./global.css" });'

# --- app/_layout.tsx ---
write_file "app/_layout.tsx" 'import { Stack } from "expo-router";
import { StatusBar } from "expo-status-bar";
import "../global.css";

export default function RootLayout() {
  return (
    <>
      <Stack>
        <Stack.Screen name="index" options={{ title: "Home" }} />
        <Stack.Screen name="+not-found" />
      </Stack>
      <StatusBar style="auto" />
    </>
  );
}'

# --- app/index.tsx ---
write_file "app/index.tsx" 'import { Text, View } from "react-native";

export default function HomeScreen() {
  return (
    <View className="flex-1 items-center justify-center bg-white">
      <Text className="text-3xl font-bold text-gray-900">
        Welcome to '"$PROJECT_NAME"'
      </Text>
      <Text className="mt-2 text-lg text-gray-500">
        Edit app/index.tsx to get started
      </Text>
    </View>
  );
}'

# --- app/+not-found.tsx ---
write_file "app/+not-found.tsx" 'import { Link, Stack } from "expo-router";
import { Text, View } from "react-native";

export default function NotFoundScreen() {
  return (
    <>
      <Stack.Screen options={{ title: "Oops!" }} />
      <View className="flex-1 items-center justify-center bg-white p-5">
        <Text className="text-xl font-bold text-gray-900">
          This screen does not exist.
        </Text>
        <Link href="/" className="mt-4 py-4">
          <Text className="text-base text-blue-500">Go to home screen</Text>
        </Link>
      </View>
    </>
  );
}'

# --- assets ---
mkdir -p assets/images

# --- .npmrc ---
write_file ".npmrc" 'node-linker=hoisted'

init_git
write_gitignore "*.jks" "*.p8" "*.p12" "*.key" "*.mobileprovision" "*.orig.*" "web-build/" ".expo/"
write_editorconfig

finish "npm install" "npx expo start"
