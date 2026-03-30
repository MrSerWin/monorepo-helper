#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-expo-firebase" "$@"
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
    "@react-native-firebase/app": "^21.0.0",
    "@react-native-firebase/auth": "^21.0.0",
    "@react-native-firebase/firestore": "^21.0.0",
    "expo": "~52.0.0",
    "expo-constants": "~17.0.0",
    "expo-dev-client": "~5.0.0",
    "expo-linking": "~7.0.0",
    "expo-router": "~4.0.0",
    "expo-splash-screen": "~0.29.0",
    "expo-status-bar": "~2.0.0",
    "expo-system-ui": "~4.0.0",
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
      "bundleIdentifier": "com.example.'"${PROJECT_NAME//\-/}"'",
      "googleServicesFile": "./GoogleService-Info.plist"
    },
    "android": {
      "adaptiveIcon": {
        "foregroundImage": "./assets/images/adaptive-icon.png",
        "backgroundColor": "#ffffff"
      },
      "package": "com.example.'"${PROJECT_NAME//\-/}"'",
      "googleServicesFile": "./google-services.json"
    },
    "web": {
      "bundler": "metro",
      "output": "static",
      "favicon": "./assets/images/favicon.png"
    },
    "plugins": [
      "expo-router",
      "@react-native-firebase/app"
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

# --- lib/firebase.ts ---
write_file "lib/firebase.ts" 'import firebase from "@react-native-firebase/app";
import auth from "@react-native-firebase/auth";
import firestore from "@react-native-firebase/firestore";

// Firebase is auto-initialized by @react-native-firebase
// using google-services.json (Android) and GoogleService-Info.plist (iOS).
// No manual initialization is required.

export { firebase, auth, firestore };'

# --- lib/useAuth.ts ---
write_file "lib/useAuth.ts" 'import { useEffect, useState } from "react";
import auth, { type FirebaseAuthTypes } from "@react-native-firebase/auth";

export function useAuth() {
  const [user, setUser] = useState<FirebaseAuthTypes.User | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsubscribe = auth().onAuthStateChanged((user) => {
      setUser(user);
      setLoading(false);
    });
    return unsubscribe;
  }, []);

  return { user, loading };
}'

# --- app/_layout.tsx ---
write_file "app/_layout.tsx" 'import { Slot, useRouter, useSegments } from "expo-router";
import { StatusBar } from "expo-status-bar";
import { useEffect } from "react";
import { useAuth } from "../lib/useAuth";
import "../global.css";

export default function RootLayout() {
  const { user, loading } = useAuth();
  const segments = useSegments();
  const router = useRouter();

  useEffect(() => {
    if (loading) return;

    const inAuthGroup = segments[0] === "(auth)";

    if (!user && !inAuthGroup) {
      router.replace("/(auth)/login");
    } else if (user && inAuthGroup) {
      router.replace("/");
    }
  }, [user, loading, segments]);

  return (
    <>
      <Slot />
      <StatusBar style="auto" />
    </>
  );
}'

# --- app/index.tsx ---
write_file "app/index.tsx" 'import { useEffect, useState } from "react";
import { Text, View, Pressable, FlatList } from "react-native";
import auth from "@react-native-firebase/auth";
import firestore from "@react-native-firebase/firestore";
import { useAuth } from "../lib/useAuth";

type Item = { id: string; title: string; createdAt: Date };

export default function HomeScreen() {
  const { user } = useAuth();
  const [items, setItems] = useState<Item[]>([]);

  useEffect(() => {
    if (!user) return;

    const unsubscribe = firestore()
      .collection("items")
      .where("userId", "==", user.uid)
      .orderBy("createdAt", "desc")
      .onSnapshot((snapshot) => {
        const data = snapshot.docs.map((doc) => ({
          id: doc.id,
          ...doc.data(),
        })) as Item[];
        setItems(data);
      });

    return unsubscribe;
  }, [user]);

  async function addItem() {
    await firestore().collection("items").add({
      title: `Item ${Date.now()}`,
      userId: user!.uid,
      createdAt: firestore.FieldValue.serverTimestamp(),
    });
  }

  return (
    <View className="flex-1 bg-white px-6 pt-16">
      <Text className="text-2xl font-bold text-gray-900">Welcome</Text>
      <Text className="mt-1 text-base text-gray-500">{user?.email}</Text>

      <Pressable
        className="mt-6 rounded-xl bg-blue-600 py-3 active:bg-blue-700"
        onPress={addItem}
      >
        <Text className="text-center text-base font-semibold text-white">
          Add Item
        </Text>
      </Pressable>

      <FlatList
        className="mt-4"
        data={items}
        keyExtractor={(item) => item.id}
        renderItem={({ item }) => (
          <View className="border-b border-gray-100 py-3">
            <Text className="text-base text-gray-900">{item.title}</Text>
          </View>
        )}
        ListEmptyComponent={
          <Text className="mt-4 text-center text-gray-400">
            No items yet. Tap "Add Item" to create one.
          </Text>
        }
      />

      <Pressable
        className="mb-8 mt-4 rounded-xl bg-red-600 py-3 active:bg-red-700"
        onPress={() => auth().signOut()}
      >
        <Text className="text-center text-base font-semibold text-white">
          Sign Out
        </Text>
      </Pressable>
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

# --- app/(auth)/_layout.tsx ---
write_file "app/(auth)/_layout.tsx" 'import { Stack } from "expo-router";

export default function AuthLayout() {
  return (
    <Stack screenOptions={{ headerShown: false }} />
  );
}'

# --- app/(auth)/login.tsx ---
write_file "app/(auth)/login.tsx" 'import { useState } from "react";
import { Text, View, TextInput, Pressable, Alert } from "react-native";
import { Link } from "expo-router";
import auth from "@react-native-firebase/auth";

export default function LoginScreen() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);

  async function handleLogin() {
    setLoading(true);
    try {
      await auth().signInWithEmailAndPassword(email, password);
    } catch (error: any) {
      Alert.alert("Error", error.message);
    }
    setLoading(false);
  }

  return (
    <View className="flex-1 items-center justify-center bg-white px-6">
      <Text className="text-3xl font-bold text-gray-900 mb-8">Sign In</Text>
      <TextInput
        className="w-full rounded-xl border border-gray-300 bg-gray-50 px-4 py-3 text-base mb-4"
        placeholder="Email"
        value={email}
        onChangeText={setEmail}
        autoCapitalize="none"
        keyboardType="email-address"
      />
      <TextInput
        className="w-full rounded-xl border border-gray-300 bg-gray-50 px-4 py-3 text-base mb-6"
        placeholder="Password"
        value={password}
        onChangeText={setPassword}
        secureTextEntry
      />
      <Pressable
        className="w-full rounded-xl bg-blue-600 py-4 active:bg-blue-700"
        onPress={handleLogin}
        disabled={loading}
      >
        <Text className="text-center text-base font-semibold text-white">
          {loading ? "Signing in..." : "Sign In"}
        </Text>
      </Pressable>
      <Link href="/(auth)/register" className="mt-4 py-2">
        <Text className="text-base text-blue-500">
          Don'\''t have an account? Sign Up
        </Text>
      </Link>
    </View>
  );
}'

# --- app/(auth)/register.tsx ---
write_file "app/(auth)/register.tsx" 'import { useState } from "react";
import { Text, View, TextInput, Pressable, Alert } from "react-native";
import { Link } from "expo-router";
import auth from "@react-native-firebase/auth";

export default function RegisterScreen() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);

  async function handleRegister() {
    setLoading(true);
    try {
      await auth().createUserWithEmailAndPassword(email, password);
    } catch (error: any) {
      Alert.alert("Error", error.message);
    }
    setLoading(false);
  }

  return (
    <View className="flex-1 items-center justify-center bg-white px-6">
      <Text className="text-3xl font-bold text-gray-900 mb-8">Sign Up</Text>
      <TextInput
        className="w-full rounded-xl border border-gray-300 bg-gray-50 px-4 py-3 text-base mb-4"
        placeholder="Email"
        value={email}
        onChangeText={setEmail}
        autoCapitalize="none"
        keyboardType="email-address"
      />
      <TextInput
        className="w-full rounded-xl border border-gray-300 bg-gray-50 px-4 py-3 text-base mb-6"
        placeholder="Password"
        value={password}
        onChangeText={setPassword}
        secureTextEntry
      />
      <Pressable
        className="w-full rounded-xl bg-blue-600 py-4 active:bg-blue-700"
        onPress={handleRegister}
        disabled={loading}
      >
        <Text className="text-center text-base font-semibold text-white">
          {loading ? "Creating account..." : "Sign Up"}
        </Text>
      </Pressable>
      <Link href="/(auth)/login" className="mt-4 py-2">
        <Text className="text-base text-blue-500">
          Already have an account? Sign In
        </Text>
      </Link>
    </View>
  );
}'

# --- assets ---
mkdir -p assets/images

# --- .npmrc ---
write_file ".npmrc" 'node-linker=hoisted'

init_git
write_gitignore "*.jks" "*.p8" "*.p12" "*.key" "*.mobileprovision" "*.orig.*" "web-build/" ".expo/" "google-services.json" "GoogleService-Info.plist"
write_editorconfig

finish "npm install" "npx expo start"
