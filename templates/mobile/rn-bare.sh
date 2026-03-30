#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-rn-app" "$@"
create_project_dir

# --- package.json ---
write_package_json '{
  "name": "'"$PROJECT_NAME"'",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "android": "react-native run-android",
    "ios": "react-native run-ios",
    "start": "react-native start",
    "lint": "eslint .",
    "ts:check": "tsc --noEmit"
  },
  "dependencies": {
    "@react-navigation/native": "^7.0.0",
    "@react-navigation/native-stack": "^7.0.0",
    "nativewind": "~4.1.0",
    "react": "18.3.1",
    "react-native": "0.77.0",
    "react-native-reanimated": "~3.16.0",
    "react-native-safe-area-context": "~4.14.0",
    "react-native-screens": "~4.4.0"
  },
  "devDependencies": {
    "@babel/core": "^7.26.0",
    "@babel/preset-env": "^7.26.0",
    "@babel/runtime": "^7.26.0",
    "@react-native/babel-preset": "0.77.0",
    "@react-native/eslint-config": "0.77.0",
    "@react-native/metro-config": "0.77.0",
    "@react-native/typescript-config": "0.77.0",
    "@types/react": "~18.3.0",
    "eslint": "^9.0.0",
    "metro-react-native-babel-preset": "^0.77.0",
    "tailwindcss": "^3.4.0",
    "typescript": "~5.8.0"
  }
}'

# --- tsconfig.json ---
write_tsconfig '{
  "compilerOptions": {
    "target": "esnext",
    "module": "commonjs",
    "lib": ["es2022"],
    "allowJs": true,
    "jsx": "react-native",
    "noEmit": true,
    "strict": true,
    "moduleResolution": "node",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["src/**/*", "App.tsx", "nativewind-env.d.ts"],
  "exclude": ["node_modules", "babel.config.js", "metro.config.js"]
}'

# --- tailwind.config.js ---
write_file "tailwind.config.js" '/** @type {import("tailwindcss").Config} */
module.exports = {
  content: ["./App.tsx", "./src/**/*.{js,jsx,ts,tsx}"],
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
write_file "babel.config.js" 'module.exports = {
  presets: [
    ["module:metro-react-native-babel-preset", { jsxImportSource: "nativewind" }],
    "nativewind/babel",
  ],
  plugins: ["react-native-reanimated/plugin"],
};'

# --- metro.config.js ---
write_file "metro.config.js" 'const { getDefaultConfig, mergeConfig } = require("@react-native/metro-config");
const { withNativeWind } = require("nativewind/metro");

const defaultConfig = getDefaultConfig(__dirname);
const config = mergeConfig(defaultConfig, {});

module.exports = withNativeWind(config, { input: "./global.css" });'

# --- App.tsx ---
write_file "App.tsx" 'import React from "react";
import { NavigationContainer } from "@react-navigation/native";
import { SafeAreaProvider } from "react-native-safe-area-context";
import { RootNavigator } from "./src/navigation/RootNavigator";
import "./global.css";

export default function App() {
  return (
    <SafeAreaProvider>
      <NavigationContainer>
        <RootNavigator />
      </NavigationContainer>
    </SafeAreaProvider>
  );
}'

# --- src/navigation/RootNavigator.tsx ---
write_file "src/navigation/RootNavigator.tsx" 'import React from "react";
import { createNativeStackNavigator } from "@react-navigation/native-stack";
import { HomeScreen } from "../screens/HomeScreen";
import { DetailsScreen } from "../screens/DetailsScreen";

export type RootStackParamList = {
  Home: undefined;
  Details: { itemId: number; title: string };
};

const Stack = createNativeStackNavigator<RootStackParamList>();

export function RootNavigator() {
  return (
    <Stack.Navigator initialRouteName="Home">
      <Stack.Screen name="Home" component={HomeScreen} />
      <Stack.Screen name="Details" component={DetailsScreen} />
    </Stack.Navigator>
  );
}'

# --- src/screens/HomeScreen.tsx ---
write_file "src/screens/HomeScreen.tsx" 'import React from "react";
import { Text, View, Pressable } from "react-native";
import type { NativeStackScreenProps } from "@react-navigation/native-stack";
import type { RootStackParamList } from "../navigation/RootNavigator";

type Props = NativeStackScreenProps<RootStackParamList, "Home">;

export function HomeScreen({ navigation }: Props) {
  return (
    <View className="flex-1 items-center justify-center bg-white px-6">
      <Text className="text-3xl font-bold text-gray-900">Welcome</Text>
      <Text className="mt-2 text-base text-gray-500 text-center">
        This is a React Native app with React Navigation and NativeWind.
      </Text>
      <Pressable
        className="mt-8 rounded-xl bg-blue-600 px-8 py-4 active:bg-blue-700"
        onPress={() =>
          navigation.navigate("Details", { itemId: 1, title: "First Item" })
        }
      >
        <Text className="text-base font-semibold text-white">
          Go to Details
        </Text>
      </Pressable>
    </View>
  );
}'

# --- src/screens/DetailsScreen.tsx ---
write_file "src/screens/DetailsScreen.tsx" 'import React from "react";
import { Text, View, Pressable } from "react-native";
import type { NativeStackScreenProps } from "@react-navigation/native-stack";
import type { RootStackParamList } from "../navigation/RootNavigator";

type Props = NativeStackScreenProps<RootStackParamList, "Details">;

export function DetailsScreen({ route, navigation }: Props) {
  const { itemId, title } = route.params;

  return (
    <View className="flex-1 items-center justify-center bg-white px-6">
      <Text className="text-2xl font-bold text-gray-900">{title}</Text>
      <Text className="mt-2 text-base text-gray-500">Item ID: {itemId}</Text>
      <Pressable
        className="mt-8 rounded-xl bg-gray-200 px-8 py-4 active:bg-gray-300"
        onPress={() => navigation.goBack()}
      >
        <Text className="text-base font-semibold text-gray-900">Go Back</Text>
      </Pressable>
    </View>
  );
}'

# --- index.js ---
write_file "index.js" 'import { AppRegistry } from "react-native";
import App from "./App";
import { name as appName } from "./app.json";

AppRegistry.registerComponent(appName, () => App);'

# --- app.json ---
write_file "app.json" '{
  "name": "'"$PROJECT_NAME"'",
  "displayName": "'"$PROJECT_NAME"'"
}'

init_git
write_gitignore "*.jks" "*.p8" "*.p12" "*.key" "*.mobileprovision" "*.orig.*" "ios/" "android/" ".bundle/"
write_editorconfig

finish "npm install" "npx react-native start"
