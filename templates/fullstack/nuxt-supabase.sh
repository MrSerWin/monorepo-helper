#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-nuxt-supabase" "$@"
create_project_dir

# --- package.json ---
write_package_json '{
  "name": "'"$PROJECT_NAME"'",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "nuxt dev",
    "build": "nuxt build",
    "generate": "nuxt generate",
    "preview": "nuxt preview",
    "postinstall": "nuxt prepare"
  },
  "dependencies": {
    "@nuxtjs/supabase": "^1.5.0",
    "nuxt": "^3.16.2",
    "vue": "^3.5.13",
    "vue-router": "^4.5.0"
  },
  "devDependencies": {
    "@nuxt/devtools": "^2.4.0",
    "@tailwindcss/vite": "^4.1.3",
    "tailwindcss": "^4.1.3",
    "typescript": "^5.8.3"
  }
}'

# --- nuxt.config.ts ---
write_file_heredoc "nuxt.config.ts" << 'EOF'
export default defineNuxtConfig({
  compatibilityDate: "2025-03-30",
  future: {
    compatibilityVersion: 4,
  },
  devtools: { enabled: true },
  modules: [
    "@nuxtjs/supabase",
  ],
  css: ["~/assets/css/main.css"],
  vite: {
    plugins: [
      // Tailwind is handled via CSS import
    ],
  },
  supabase: {
    redirectOptions: {
      login: "/auth/login",
      callback: "/auth/confirm",
      include: ["/protected(/*)?"],
      exclude: [],
      cookieRedirect: false,
    },
  },
});
EOF

# --- tsconfig.json ---
write_tsconfig '{
  "extends": "./.nuxt/tsconfig.json"
}'

# --- .env.example ---
write_file ".env.example" 'SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your-anon-key-here'

# --- assets/css/main.css ---
write_file "assets/css/main.css" '@import "tailwindcss";'

# --- app.vue ---
write_file_heredoc "app.vue" << 'EOF'
<template>
  <NuxtLayout>
    <NuxtPage />
  </NuxtLayout>
</template>
EOF

# --- layouts/default.vue ---
write_file_heredoc "layouts/default.vue" << 'EOF'
<template>
  <div class="antialiased">
    <nav class="border-b border-gray-200 px-6 py-4">
      <div class="max-w-4xl mx-auto flex items-center justify-between">
        <NuxtLink to="/" class="text-lg font-bold">
          Nuxt + <span class="text-green-600">Supabase</span>
        </NuxtLink>
        <div class="flex items-center gap-4">
          <template v-if="user">
            <span class="text-sm text-gray-500">{{ user.email }}</span>
            <button
              @click="signOut"
              class="text-sm text-gray-600 hover:text-gray-900"
            >
              Sign Out
            </button>
          </template>
          <template v-else>
            <NuxtLink
              to="/auth/login"
              class="text-sm text-green-600 hover:text-green-700 font-medium"
            >
              Sign In
            </NuxtLink>
          </template>
        </div>
      </div>
    </nav>
    <slot />
  </div>
</template>

<script setup lang="ts">
const user = useSupabaseUser();
const supabase = useSupabaseClient();

async function signOut() {
  await supabase.auth.signOut();
  navigateTo("/");
}
</script>
EOF

# --- pages/index.vue ---
write_file_heredoc "pages/index.vue" << 'EOF'
<template>
  <div class="grid min-h-[calc(100vh-65px)] items-center justify-items-center p-8 sm:p-20">
    <main class="flex flex-col items-center gap-8">
      <h1 class="text-4xl font-bold tracking-tight sm:text-6xl">
        Nuxt + <span class="text-green-600">Supabase</span>
      </h1>
      <p class="text-lg text-gray-600 max-w-md text-center">
        Full-stack app with authentication powered by Supabase
      </p>
      <div class="flex gap-4">
        <NuxtLink
          v-if="user"
          to="/protected"
          class="rounded-full bg-green-600 text-white px-6 py-3 text-sm font-medium hover:bg-green-700 transition-colors"
        >
          Protected Page
        </NuxtLink>
        <NuxtLink
          v-else
          to="/auth/login"
          class="rounded-full bg-green-600 text-white px-6 py-3 text-sm font-medium hover:bg-green-700 transition-colors"
        >
          Get Started
        </NuxtLink>
        <a
          href="https://supabase.nuxtjs.org"
          target="_blank"
          rel="noopener noreferrer"
          class="rounded-full border border-gray-300 px-6 py-3 text-sm font-medium hover:bg-gray-50 transition-colors"
        >
          Documentation
        </a>
      </div>
    </main>
  </div>
</template>

<script setup lang="ts">
const user = useSupabaseUser();
</script>
EOF

# --- pages/auth/login.vue ---
write_file_heredoc "pages/auth/login.vue" << 'EOF'
<template>
  <div class="grid min-h-[calc(100vh-65px)] items-center justify-items-center p-8">
    <div class="w-full max-w-sm">
      <h1 class="text-2xl font-bold text-center mb-8">Sign In</h1>
      <form @submit.prevent="handleLogin" class="flex flex-col gap-4">
        <p
          v-if="errorMsg"
          class="text-red-600 text-sm text-center bg-red-50 rounded-lg p-3"
        >
          {{ errorMsg }}
        </p>
        <input
          v-model="email"
          type="email"
          placeholder="Email"
          required
          class="rounded-lg border border-gray-300 px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-green-500"
        />
        <input
          v-model="password"
          type="password"
          placeholder="Password"
          required
          class="rounded-lg border border-gray-300 px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-green-500"
        />
        <button
          type="submit"
          :disabled="loading"
          class="rounded-lg bg-green-600 text-white px-4 py-3 text-sm font-medium hover:bg-green-700 transition-colors disabled:opacity-50"
        >
          {{ loading ? "Signing in..." : "Sign In" }}
        </button>
      </form>
      <p class="text-sm text-gray-600 text-center mt-4">
        Don't have an account?
        <NuxtLink to="/auth/signup" class="text-green-600 hover:underline">
          Sign Up
        </NuxtLink>
      </p>
    </div>
  </div>
</template>

<script setup lang="ts">
const supabase = useSupabaseClient();
const email = ref("");
const password = ref("");
const loading = ref(false);
const errorMsg = ref<string | null>(null);

async function handleLogin() {
  loading.value = true;
  errorMsg.value = null;

  const { error } = await supabase.auth.signInWithPassword({
    email: email.value,
    password: password.value,
  });

  if (error) {
    errorMsg.value = error.message;
    loading.value = false;
  } else {
    navigateTo("/protected");
  }
}
</script>
EOF

# --- pages/auth/signup.vue ---
write_file_heredoc "pages/auth/signup.vue" << 'EOF'
<template>
  <div class="grid min-h-[calc(100vh-65px)] items-center justify-items-center p-8">
    <div class="w-full max-w-sm">
      <h1 class="text-2xl font-bold text-center mb-8">Sign Up</h1>
      <form @submit.prevent="handleSignUp" class="flex flex-col gap-4">
        <p
          v-if="errorMsg"
          class="text-red-600 text-sm text-center bg-red-50 rounded-lg p-3"
        >
          {{ errorMsg }}
        </p>
        <input
          v-model="email"
          type="email"
          placeholder="Email"
          required
          class="rounded-lg border border-gray-300 px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-green-500"
        />
        <input
          v-model="password"
          type="password"
          placeholder="Password (min 6 characters)"
          required
          minlength="6"
          class="rounded-lg border border-gray-300 px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-green-500"
        />
        <button
          type="submit"
          :disabled="loading"
          class="rounded-lg bg-green-600 text-white px-4 py-3 text-sm font-medium hover:bg-green-700 transition-colors disabled:opacity-50"
        >
          {{ loading ? "Signing up..." : "Sign Up" }}
        </button>
      </form>
      <p class="text-sm text-gray-600 text-center mt-4">
        Already have an account?
        <NuxtLink to="/auth/login" class="text-green-600 hover:underline">
          Sign In
        </NuxtLink>
      </p>
    </div>
  </div>
</template>

<script setup lang="ts">
const supabase = useSupabaseClient();
const email = ref("");
const password = ref("");
const loading = ref(false);
const errorMsg = ref<string | null>(null);

async function handleSignUp() {
  loading.value = true;
  errorMsg.value = null;

  const { error } = await supabase.auth.signUp({
    email: email.value,
    password: password.value,
  });

  if (error) {
    errorMsg.value = error.message;
    loading.value = false;
  } else {
    navigateTo("/auth/confirm");
  }
}
</script>
EOF

# --- pages/auth/confirm.vue ---
write_file_heredoc "pages/auth/confirm.vue" << 'EOF'
<template>
  <div class="grid min-h-[calc(100vh-65px)] items-center justify-items-center p-8">
    <div class="text-center">
      <h1 class="text-2xl font-bold mb-4">Check your email</h1>
      <p class="text-gray-600 mb-6">
        We sent you a confirmation link. Please check your email to verify your account.
      </p>
      <NuxtLink to="/auth/login" class="text-green-600 hover:underline text-sm">
        Back to Sign In
      </NuxtLink>
    </div>
  </div>
</template>
EOF

# --- pages/protected.vue ---
write_file_heredoc "pages/protected.vue" << 'EOF'
<template>
  <div class="grid min-h-[calc(100vh-65px)] items-center justify-items-center p-8">
    <div class="text-center">
      <h1 class="text-2xl font-bold mb-4">Protected Page</h1>
      <p class="text-gray-600 mb-2">Welcome, {{ user?.email }}!</p>
      <p class="text-sm text-gray-500">
        This page is only visible to authenticated users.
      </p>
    </div>
  </div>
</template>

<script setup lang="ts">
definePageMeta({
  middleware: "auth",
});

const user = useSupabaseUser();
</script>
EOF

# --- middleware/auth.ts ---
write_file_heredoc "middleware/auth.ts" << 'EOF'
export default defineNuxtRouteMiddleware((to) => {
  const user = useSupabaseUser();

  if (!user.value) {
    return navigateTo("/auth/login");
  }
});
EOF

# --- composables/useProfile.ts ---
write_file_heredoc "composables/useProfile.ts" << 'EOF'
export function useProfile() {
  const user = useSupabaseUser();
  const supabase = useSupabaseClient();

  const displayName = computed(() => {
    if (!user.value) return null;
    return user.value.user_metadata?.full_name ?? user.value.email;
  });

  async function updateProfile(data: { full_name?: string }) {
    const { error } = await supabase.auth.updateUser({
      data,
    });
    if (error) throw error;
  }

  return {
    user,
    displayName,
    updateProfile,
  };
}
EOF

# --- server/api/hello.get.ts ---
write_file_heredoc "server/api/hello.get.ts" << 'EOF'
export default defineEventHandler(async (event) => {
  return {
    message: "Hello from the API!",
    timestamp: new Date().toISOString(),
  };
});
EOF

# --- server/api/me.get.ts ---
write_file_heredoc "server/api/me.get.ts" << 'EOF'
import { serverSupabaseUser } from "#supabase/server";

export default defineEventHandler(async (event) => {
  const user = await serverSupabaseUser(event);

  if (!user) {
    throw createError({
      statusCode: 401,
      statusMessage: "Unauthorized",
    });
  }

  return {
    id: user.id,
    email: user.email,
    createdAt: user.created_at,
  };
});
EOF

# --- server/tsconfig.json ---
write_file_heredoc "server/tsconfig.json" << 'EOF'
{
  "extends": "../.nuxt/tsconfig.server.json"
}
EOF

# --- public/ ---
mkdir -p public

init_git
write_gitignore
write_editorconfig
write_nvmrc

finish "npm install" "npm run dev"
