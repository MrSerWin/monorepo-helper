#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-turbo-expo" "$@"
header "Turborepo + Next.js 15 + Expo 52 + Shared UI + Tailwind CSS 4"

create_project_dir

# ══════════════════════════════════════════════════════════════
# Root configuration
# ══════════════════════════════════════════════════════════════
section "Root configuration"

write_package_json '{
  "name": "'"$PROJECT_NAME"'",
  "private": true,
  "scripts": {
    "dev": "turbo dev",
    "dev:web": "turbo dev --filter=@repo/web",
    "dev:mobile": "turbo dev --filter=@repo/mobile",
    "build": "turbo build",
    "lint": "turbo lint"
  },
  "devDependencies": {
    "turbo": "^2.5.0"
  },
  "packageManager": "pnpm@10.8.0"
}'

write_file_heredoc "pnpm-workspace.yaml" << 'EOF'
packages:
  - "apps/*"
  - "packages/*"
EOF
success "Created pnpm-workspace.yaml"

write_file_heredoc "turbo.json" << 'EOF'
{
  "$schema": "https://turbo.build/schema.json",
  "tasks": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": [".next/**", "!.next/cache/**", "dist/**"]
    },
    "lint": {
      "dependsOn": ["^build"]
    },
    "dev": {
      "cache": false,
      "persistent": true
    }
  }
}
EOF
success "Created turbo.json"

# ══════════════════════════════════════════════════════════════
# packages/tsconfig
# ══════════════════════════════════════════════════════════════
section "packages/tsconfig"
mkdir -p packages/tsconfig

write_file_heredoc "packages/tsconfig/package.json" << 'EOF'
{
  "name": "@repo/tsconfig",
  "version": "0.0.0",
  "private": true,
  "files": ["*.json"]
}
EOF

write_file_heredoc "packages/tsconfig/base.json" << 'EOF'
{
  "compilerOptions": {
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "declaration": true,
    "declarationMap": true
  }
}
EOF

write_file_heredoc "packages/tsconfig/nextjs.json" << 'EOF'
{
  "extends": "./base.json",
  "compilerOptions": {
    "target": "ES2017",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "noEmit": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "jsx": "preserve",
    "incremental": true,
    "plugins": [{ "name": "next" }]
  }
}
EOF

write_file_heredoc "packages/tsconfig/expo.json" << 'EOF'
{
  "extends": "./base.json",
  "compilerOptions": {
    "target": "ESNext",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "jsx": "react-jsx",
    "lib": ["ES2024"]
  }
}
EOF
success "Created packages/tsconfig"

# ══════════════════════════════════════════════════════════════
# packages/shared
# ══════════════════════════════════════════════════════════════
section "packages/shared"
mkdir -p packages/shared/src

write_file_heredoc "packages/shared/package.json" << 'EOF'
{
  "name": "@repo/shared",
  "version": "0.0.0",
  "private": true,
  "type": "module",
  "main": "./src/index.ts",
  "types": "./src/index.ts",
  "devDependencies": {
    "@repo/tsconfig": "workspace:*"
  }
}
EOF

write_file_heredoc "packages/shared/tsconfig.json" << 'EOF'
{
  "extends": "@repo/tsconfig/base.json",
  "compilerOptions": {
    "target": "ES2024",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "outDir": "dist",
    "rootDir": "src"
  },
  "include": ["src"]
}
EOF

write_file_heredoc "packages/shared/src/index.ts" << 'EOF'
export const APP_NAME = "My App";

export interface User {
  id: string;
  email: string;
  name: string | null;
}
EOF
success "Created packages/shared"

# ══════════════════════════════════════════════════════════════
# packages/ui (shared React Native Web + Native components)
# ══════════════════════════════════════════════════════════════
section "packages/ui"
mkdir -p packages/ui/src

write_file_heredoc "packages/ui/package.json" << 'EOF'
{
  "name": "@repo/ui",
  "version": "0.0.0",
  "private": true,
  "main": "./src/index.tsx",
  "types": "./src/index.tsx",
  "dependencies": {
    "react": "^19.1.0",
    "react-native": "^0.77.0"
  },
  "devDependencies": {
    "@repo/tsconfig": "workspace:*",
    "@types/react": "^19.1.0",
    "typescript": "^5.8.3"
  }
}
EOF

write_file_heredoc "packages/ui/tsconfig.json" << 'EOF'
{
  "extends": "@repo/tsconfig/base.json",
  "compilerOptions": {
    "target": "ESNext",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "jsx": "react-jsx",
    "lib": ["ES2024"]
  },
  "include": ["src"]
}
EOF

write_file_heredoc "packages/ui/src/index.tsx" << 'EOF'
export { Button } from "./Button.js";
export { Card } from "./Card.js";
export { Typography } from "./Typography.js";
EOF

write_file_heredoc "packages/ui/src/Button.tsx" << 'EOF'
import { Pressable, Text, StyleSheet, type ViewStyle, type TextStyle } from "react-native";

interface ButtonProps {
  title: string;
  onPress?: () => void;
  variant?: "primary" | "secondary";
}

export function Button({ title, onPress, variant = "primary" }: ButtonProps) {
  const isPrimary = variant === "primary";

  return (
    <Pressable
      onPress={onPress}
      style={({ pressed }) => [
        styles.base,
        isPrimary ? styles.primary : styles.secondary,
        pressed && styles.pressed,
      ]}
    >
      <Text style={[styles.text, isPrimary ? styles.textPrimary : styles.textSecondary]}>
        {title}
      </Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  base: {
    paddingHorizontal: 24,
    paddingVertical: 12,
    borderRadius: 9999,
    alignItems: "center",
    justifyContent: "center",
  } as ViewStyle,
  primary: {
    backgroundColor: "#2563eb",
  } as ViewStyle,
  secondary: {
    backgroundColor: "transparent",
    borderWidth: 1,
    borderColor: "#d1d5db",
  } as ViewStyle,
  pressed: {
    opacity: 0.8,
  } as ViewStyle,
  text: {
    fontSize: 14,
    fontWeight: "600",
  } as TextStyle,
  textPrimary: {
    color: "#ffffff",
  } as TextStyle,
  textSecondary: {
    color: "#374151",
  } as TextStyle,
});
EOF

write_file_heredoc "packages/ui/src/Card.tsx" << 'EOF'
import { View, StyleSheet, type ViewStyle } from "react-native";
import type { ReactNode } from "react";

interface CardProps {
  children: ReactNode;
}

export function Card({ children }: CardProps) {
  return <View style={styles.card}>{children}</View>;
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: "#ffffff",
    borderRadius: 12,
    padding: 16,
    borderWidth: 1,
    borderColor: "#e5e7eb",
  } as ViewStyle,
});
EOF

write_file_heredoc "packages/ui/src/Typography.tsx" << 'EOF'
import { Text, StyleSheet, type TextStyle } from "react-native";
import type { ReactNode } from "react";

interface TypographyProps {
  children: ReactNode;
  variant?: "h1" | "h2" | "body" | "caption";
}

export function Typography({ children, variant = "body" }: TypographyProps) {
  return <Text style={styles[variant]}>{children}</Text>;
}

const styles = StyleSheet.create({
  h1: {
    fontSize: 32,
    fontWeight: "bold",
    color: "#111827",
  } as TextStyle,
  h2: {
    fontSize: 24,
    fontWeight: "600",
    color: "#111827",
  } as TextStyle,
  body: {
    fontSize: 16,
    color: "#374151",
  } as TextStyle,
  caption: {
    fontSize: 12,
    color: "#6b7280",
  } as TextStyle,
});
EOF
success "Created packages/ui"

# ══════════════════════════════════════════════════════════════
# apps/web (Next.js 15)
# ══════════════════════════════════════════════════════════════
section "apps/web (Next.js 15)"
mkdir -p apps/web/src/app apps/web/public

write_file_heredoc "apps/web/package.json" << 'EOF'
{
  "name": "@repo/web",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "next dev --turbopack --port 3000",
    "build": "next build",
    "start": "next start",
    "lint": "next lint"
  },
  "dependencies": {
    "@repo/shared": "workspace:*",
    "@repo/ui": "workspace:*",
    "next": "^15.3.0",
    "react": "^19.1.0",
    "react-dom": "^19.1.0",
    "react-native-web": "^0.19.13"
  },
  "devDependencies": {
    "@repo/tsconfig": "workspace:*",
    "@tailwindcss/postcss": "^4.1.3",
    "@types/node": "^22.14.0",
    "@types/react": "^19.1.0",
    "@types/react-dom": "^19.1.0",
    "eslint": "^9.24.0",
    "eslint-config-next": "^15.3.0",
    "tailwindcss": "^4.1.3",
    "typescript": "^5.8.3"
  }
}
EOF

write_file_heredoc "apps/web/tsconfig.json" << 'EOF'
{
  "extends": "@repo/tsconfig/nextjs.json",
  "compilerOptions": {
    "paths": {
      "@/*": ["./src/*"],
      "react-native": ["react-native-web"]
    }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
EOF

write_file_heredoc "apps/web/next.config.ts" << 'EOF'
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  transpilePackages: ["@repo/shared", "@repo/ui", "react-native-web"],
  webpack: (config) => {
    config.resolve.alias = {
      ...(config.resolve.alias || {}),
      "react-native$": "react-native-web",
    };
    return config;
  },
};

export default nextConfig;
EOF

write_file "apps/web/postcss.config.mjs" 'const config = {
  plugins: {
    "@tailwindcss/postcss": {},
  },
};

export default config;'

write_file "apps/web/src/app/globals.css" '@import "tailwindcss";'

write_file_heredoc "apps/web/src/app/layout.tsx" << 'EOF'
import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Web App",
  description: "Next.js + Expo universal app",
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body className="antialiased">{children}</body>
    </html>
  );
}
EOF

write_file_heredoc "apps/web/src/app/page.tsx" << 'EOF'
"use client";

import { Button, Card, Typography } from "@repo/ui";
import { APP_NAME } from "@repo/shared";

export default function Home() {
  return (
    <div className="grid min-h-screen items-center justify-items-center p-8 sm:p-20">
      <div className="flex flex-col items-center gap-8">
        <h1 className="text-4xl font-bold tracking-tight sm:text-6xl">
          {APP_NAME}
        </h1>
        <Card>
          <Typography variant="h2">Universal Components</Typography>
          <Typography>
            These components work on both web and native!
          </Typography>
        </Card>
        <div className="flex gap-4">
          <Button title="Primary" onPress={() => alert("Hello!")} />
          <Button title="Secondary" variant="secondary" onPress={() => alert("Hello!")} />
        </div>
      </div>
    </div>
  );
}
EOF

write_file "apps/web/next-env.d.ts" '/// <reference types="next" />
/// <reference types="next/image-types/global" />'

success "Created apps/web"

# ══════════════════════════════════════════════════════════════
# apps/mobile (Expo 52)
# ══════════════════════════════════════════════════════════════
section "apps/mobile (Expo 52)"
mkdir -p apps/mobile/src/app apps/mobile/assets

write_file_heredoc "apps/mobile/package.json" << 'EOF'
{
  "name": "@repo/mobile",
  "version": "0.1.0",
  "private": true,
  "main": "expo-router/entry",
  "scripts": {
    "dev": "expo start",
    "build:ios": "eas build --platform ios",
    "build:android": "eas build --platform android",
    "lint": "eslint ."
  },
  "dependencies": {
    "@repo/shared": "workspace:*",
    "@repo/ui": "workspace:*",
    "expo": "~52.0.0",
    "expo-router": "~4.0.0",
    "expo-linking": "~7.0.0",
    "expo-constants": "~17.0.0",
    "expo-status-bar": "~2.0.0",
    "react": "^19.1.0",
    "react-native": "^0.77.0",
    "react-native-safe-area-context": "^5.3.0",
    "react-native-screens": "~4.5.0",
    "react-native-web": "^0.19.13"
  },
  "devDependencies": {
    "@repo/tsconfig": "workspace:*",
    "@types/react": "^19.1.0",
    "typescript": "^5.8.3"
  }
}
EOF

write_file_heredoc "apps/mobile/tsconfig.json" << 'EOF'
{
  "extends": "@repo/tsconfig/expo.json",
  "compilerOptions": {
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["**/*.ts", "**/*.tsx", ".expo/types/**/*.ts"],
  "exclude": ["node_modules"]
}
EOF

write_file_heredoc "apps/mobile/app.json" << 'EOF'
{
  "expo": {
    "name": "mobile",
    "slug": "mobile",
    "version": "1.0.0",
    "scheme": "mobile",
    "platforms": ["ios", "android"],
    "newArchEnabled": true,
    "ios": {
      "bundleIdentifier": "com.example.mobile"
    },
    "android": {
      "package": "com.example.mobile",
      "adaptiveIcon": {
        "backgroundColor": "#ffffff"
      }
    },
    "web": {
      "bundler": "metro",
      "output": "static"
    },
    "plugins": ["expo-router"]
  }
}
EOF

write_file_heredoc "apps/mobile/src/app/_layout.tsx" << 'EOF'
import { Stack } from "expo-router";
import { StatusBar } from "expo-status-bar";

export default function RootLayout() {
  return (
    <>
      <StatusBar style="auto" />
      <Stack
        screenOptions={{
          headerStyle: { backgroundColor: "#ffffff" },
          headerTintColor: "#111827",
          headerTitleStyle: { fontWeight: "bold" },
        }}
      />
    </>
  );
}
EOF

write_file_heredoc "apps/mobile/src/app/index.tsx" << 'EOF'
import { View, StyleSheet } from "react-native";
import { Button, Card, Typography } from "@repo/ui";
import { APP_NAME } from "@repo/shared";

export default function HomeScreen() {
  return (
    <View style={styles.container}>
      <Typography variant="h1">{APP_NAME}</Typography>
      <Card>
        <Typography variant="h2">Universal Components</Typography>
        <Typography>
          These components work on both web and native!
        </Typography>
      </Card>
      <View style={styles.buttons}>
        <Button title="Primary" onPress={() => console.log("pressed")} />
        <Button title="Secondary" variant="secondary" onPress={() => console.log("pressed")} />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    padding: 24,
    gap: 24,
    backgroundColor: "#f9fafb",
  },
  buttons: {
    flexDirection: "row",
    gap: 12,
  },
});
EOF

write_file_heredoc "apps/mobile/metro.config.js" << 'EOF'
const { getDefaultConfig } = require("expo/metro-config");
const path = require("path");

const projectRoot = __dirname;
const monorepoRoot = path.resolve(projectRoot, "../..");

const config = getDefaultConfig(projectRoot);

config.watchFolders = [monorepoRoot];
config.resolver.nodeModulesPaths = [
  path.resolve(projectRoot, "node_modules"),
  path.resolve(monorepoRoot, "node_modules"),
];

module.exports = config;
EOF
success "Created apps/mobile"

# ── Finalize ──────────────────────────────────────────────────
section "Finalizing"
init_git
write_gitignore ".expo/" "ios/" "android/" "*.jks" "*.p8" "*.p12" "*.key" "*.mobileprovision" "*.orig.*"
write_editorconfig
write_nvmrc

write_readme "$PROJECT_NAME" \
  "Turborepo monorepo with Next.js 15, Expo 52, shared UI components, and Tailwind CSS 4." \
  "pnpm install" \
  "pnpm dev"

finish "pnpm install" "pnpm dev"
