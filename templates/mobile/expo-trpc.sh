#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-expo-trpc-app" "$@"
create_project_dir

# --- package.json ---
write_package_json '{
  "name": "'"$PROJECT_NAME"'",
  "version": "1.0.0",
  "private": true,
  "main": "expo-router/entry",
  "scripts": {
    "start": "expo start",
    "android": "expo start --android",
    "ios": "expo start --ios",
    "web": "expo start --web",
    "lint": "eslint .",
    "typecheck": "tsc --noEmit"
  },
  "dependencies": {
    "@expo/vector-icons": "^14.0.0",
    "@tanstack/react-query": "^5.62.0",
    "@trpc/client": "^11.0.0",
    "@trpc/react-query": "^11.0.0",
    "@trpc/server": "^11.0.0",
    "expo": "~52.0.0",
    "expo-constants": "~17.0.0",
    "expo-font": "~13.0.0",
    "expo-linking": "~7.0.0",
    "expo-router": "~4.0.0",
    "expo-splash-screen": "~0.29.0",
    "expo-status-bar": "~2.0.0",
    "expo-system-ui": "~4.0.0",
    "nativewind": "^4.1.0",
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "react-native": "~0.76.0",
    "react-native-reanimated": "~3.16.0",
    "react-native-safe-area-context": "~4.14.0",
    "react-native-screens": "~4.4.0",
    "react-native-web": "~0.19.13",
    "superjson": "^2.2.1",
    "tailwindcss": "^3.4.17"
  },
  "devDependencies": {
    "@babel/core": "^7.26.0",
    "@types/react": "~18.3.0",
    "typescript": "~5.7.0"
  }
}'

# --- app.json ---
write_file_heredoc "app.json" << EOF
{
  "expo": {
    "name": "${PROJECT_NAME}",
    "slug": "${PROJECT_NAME}",
    "version": "1.0.0",
    "orientation": "portrait",
    "icon": "./assets/images/icon.png",
    "scheme": "${PROJECT_NAME}",
    "userInterfaceStyle": "automatic",
    "newArchEnabled": true,
    "splash": {
      "image": "./assets/images/splash-icon.png",
      "resizeMode": "contain",
      "backgroundColor": "#ffffff"
    },
    "ios": {
      "supportsTablet": true,
      "bundleIdentifier": "com.example.${PROJECT_NAME//[-]/}"
    },
    "android": {
      "adaptiveIcon": {
        "foregroundImage": "./assets/images/adaptive-icon.png",
        "backgroundColor": "#ffffff"
      },
      "package": "com.example.${PROJECT_NAME//[-]/}"
    },
    "web": {
      "bundler": "metro",
      "output": "static",
      "favicon": "./assets/images/favicon.png"
    },
    "plugins": ["expo-router"],
    "experiments": {
      "typedRoutes": true
    }
  }
}
EOF

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
write_file_heredoc "tailwind.config.js" << 'EOF'
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./app/**/*.{js,jsx,ts,tsx}",
    "./components/**/*.{js,jsx,ts,tsx}",
  ],
  presets: [require("nativewind/preset")],
  theme: {
    extend: {},
  },
  plugins: [],
};
EOF

# --- global.css ---
write_file "global.css" '@tailwind base;
@tailwind components;
@tailwind utilities;'

# --- nativewind-env.d.ts ---
write_file "nativewind-env.d.ts" '/// <reference types="nativewind/types" />'

# --- babel.config.js ---
write_file_heredoc "babel.config.js" << 'EOF'
module.exports = function (api) {
  api.cache(true);
  return {
    presets: [
      ["babel-preset-expo", { jsxImportSource: "nativewind" }],
      "nativewind/babel",
    ],
  };
};
EOF

# --- metro.config.js ---
write_file_heredoc "metro.config.js" << 'EOF'
const { getDefaultConfig } = require("expo/metro-config");
const { withNativeWind } = require("nativewind/metro");

const config = getDefaultConfig(__dirname);

module.exports = withNativeWind(config, { input: "./global.css" });
EOF

# --- lib/trpc.ts ---
write_file_heredoc "lib/trpc.ts" << 'EOF'
import { createTRPCReact } from "@trpc/react-query";
import { httpBatchLink } from "@trpc/client";
import { QueryClient } from "@tanstack/react-query";
import superjson from "superjson";
import type { AppRouter } from "./api/root";

export const trpc = createTRPCReact<AppRouter>();

const getBaseUrl = () => {
  // Replace with your API URL
  // For local development with Expo, use your machine's local IP
  return process.env.EXPO_PUBLIC_API_URL ?? "http://localhost:3000/api/trpc";
};

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 30 * 1000,
    },
  },
});

export const trpcClient = trpc.createClient({
  links: [
    httpBatchLink({
      url: getBaseUrl(),
      transformer: superjson,
    }),
  ],
});
EOF

# --- lib/api/root.ts ---
write_file_heredoc "lib/api/root.ts" << 'EOF'
import { initTRPC } from "@trpc/server";
import superjson from "superjson";
import { z } from "zod";

/**
 * This file defines the tRPC router types for the client.
 * In a real app, this would be imported from your backend package.
 * Here we define it inline as a reference for type-safe API calls.
 */

const t = initTRPC.create({
  transformer: superjson,
});

const router = t.router;
const publicProcedure = t.procedure;

// Example router - replace with your actual backend router
export const appRouter = router({
  hello: publicProcedure
    .input(z.object({ name: z.string().optional() }))
    .query(({ input }) => {
      return { greeting: `Hello ${input.name ?? "World"}!` };
    }),

  posts: router({
    list: publicProcedure.query(() => {
      return [
        { id: 1, title: "First Post", content: "Hello from tRPC!" },
        { id: 2, title: "Second Post", content: "Type-safe APIs are great." },
        { id: 3, title: "Third Post", content: "React Query + tRPC = magic." },
      ];
    }),

    byId: publicProcedure
      .input(z.object({ id: z.number() }))
      .query(({ input }) => {
        return {
          id: input.id,
          title: `Post ${input.id}`,
          content: `Content for post ${input.id}`,
        };
      }),

    create: publicProcedure
      .input(z.object({ title: z.string(), content: z.string() }))
      .mutation(({ input }) => {
        return { id: Date.now(), ...input };
      }),
  }),
});

export type AppRouter = typeof appRouter;
EOF

# --- lib/providers.tsx ---
write_file_heredoc "lib/providers.tsx" << 'EOF'
import { QueryClientProvider } from "@tanstack/react-query";
import { trpc, trpcClient, queryClient } from "./trpc";

export function TRPCProvider({ children }: { children: React.ReactNode }) {
  return (
    <trpc.Provider client={trpcClient} queryClient={queryClient}>
      <QueryClientProvider client={queryClient}>
        {children}
      </QueryClientProvider>
    </trpc.Provider>
  );
}
EOF

# --- app/_layout.tsx ---
write_file_heredoc "app/_layout.tsx" << 'EOF'
import "../global.css";
import { Stack } from "expo-router";
import { StatusBar } from "expo-status-bar";
import { TRPCProvider } from "@/lib/providers";

export default function RootLayout() {
  return (
    <TRPCProvider>
      <Stack>
        <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
      </Stack>
      <StatusBar style="auto" />
    </TRPCProvider>
  );
}
EOF

# --- app/(tabs)/_layout.tsx ---
write_file_heredoc "app/(tabs)/_layout.tsx" << 'EOF'
import { Tabs } from "expo-router";
import { Ionicons } from "@expo/vector-icons";

export default function TabLayout() {
  return (
    <Tabs
      screenOptions={{
        tabBarActiveTintColor: "#2563eb",
        headerStyle: { backgroundColor: "#2563eb" },
        headerTintColor: "#fff",
      }}
    >
      <Tabs.Screen
        name="index"
        options={{
          title: "Home",
          tabBarIcon: ({ color, size }) => (
            <Ionicons name="home" size={size} color={color} />
          ),
        }}
      />
      <Tabs.Screen
        name="posts"
        options={{
          title: "Posts",
          tabBarIcon: ({ color, size }) => (
            <Ionicons name="list" size={size} color={color} />
          ),
        }}
      />
    </Tabs>
  );
}
EOF

# --- app/(tabs)/index.tsx ---
write_file_heredoc "app/(tabs)/index.tsx" << 'EOF'
import { View, Text, ActivityIndicator } from "react-native";
import { trpc } from "@/lib/trpc";

export default function HomeScreen() {
  const hello = trpc.hello.useQuery({ name: "Expo" });

  return (
    <View className="flex-1 items-center justify-center bg-white p-6">
      <Text className="text-3xl font-bold text-gray-900 mb-4">
        Expo + tRPC
      </Text>

      {hello.isLoading ? (
        <ActivityIndicator size="large" color="#2563eb" />
      ) : hello.error ? (
        <View className="bg-red-50 p-4 rounded-xl">
          <Text className="text-red-600">Error: {hello.error.message}</Text>
        </View>
      ) : (
        <View className="bg-blue-50 p-6 rounded-xl">
          <Text className="text-xl text-blue-700 font-semibold">
            {hello.data?.greeting}
          </Text>
        </View>
      )}

      <Text className="text-gray-500 mt-8 text-center">
        Type-safe API calls with tRPC 11 + Tanstack Query
      </Text>
    </View>
  );
}
EOF

# --- app/(tabs)/posts.tsx ---
write_file_heredoc "app/(tabs)/posts.tsx" << 'EOF'
import {
  View,
  Text,
  FlatList,
  ActivityIndicator,
  Pressable,
  RefreshControl,
} from "react-native";
import { trpc } from "@/lib/trpc";

export default function PostsScreen() {
  const posts = trpc.posts.list.useQuery();

  return (
    <View className="flex-1 bg-gray-50">
      {posts.isLoading ? (
        <View className="flex-1 items-center justify-center">
          <ActivityIndicator size="large" color="#2563eb" />
        </View>
      ) : posts.error ? (
        <View className="flex-1 items-center justify-center p-6">
          <Text className="text-red-600 text-center">
            Error loading posts: {posts.error.message}
          </Text>
          <Pressable
            onPress={() => posts.refetch()}
            className="mt-4 bg-blue-600 px-6 py-3 rounded-lg"
          >
            <Text className="text-white font-semibold">Retry</Text>
          </Pressable>
        </View>
      ) : (
        <FlatList
          data={posts.data}
          keyExtractor={(item) => item.id.toString()}
          contentContainerClassName="p-4 gap-3"
          refreshControl={
            <RefreshControl
              refreshing={posts.isRefetching}
              onRefresh={() => posts.refetch()}
            />
          }
          renderItem={({ item }) => (
            <Pressable className="bg-white rounded-xl p-4 shadow-sm active:opacity-70">
              <Text className="text-lg font-semibold text-gray-900">
                {item.title}
              </Text>
              <Text className="text-gray-600 mt-1">{item.content}</Text>
            </Pressable>
          )}
          ListEmptyComponent={
            <Text className="text-gray-500 text-center mt-8">
              No posts found
            </Text>
          }
        />
      )}
    </View>
  );
}
EOF

# --- assets directories ---
mkdir -p assets/images assets/fonts

init_git
write_gitignore \
  ".expo/" \
  "android/" \
  "ios/" \
  "web-build/" \
  "*.jks" \
  "*.keystore"
write_editorconfig
write_nvmrc

write_readme "$PROJECT_NAME" "An Expo 52 app with tRPC 11, Tanstack Query, and NativeWind." \
  "npm install" \
  "npx expo start" \
  "- \`npx expo start\` - Start Expo dev server
- \`npm run android\` - Run on Android
- \`npm run ios\` - Run on iOS
- \`npm run web\` - Run on web"

finish "npm install" "npx expo start"
