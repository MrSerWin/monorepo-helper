#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-saas" "$@"
header "Turborepo + Next.js 15 + Hono 4 + Drizzle + Stripe + NextAuth 5 + Tailwind CSS 4"

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
    "build": "turbo build",
    "lint": "turbo lint",
    "db:generate": "turbo db:generate",
    "db:push": "turbo db:push",
    "db:migrate": "turbo db:migrate"
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
    "lint": { "dependsOn": ["^build"] },
    "dev": { "cache": false, "persistent": true },
    "db:generate": { "cache": false },
    "db:push": { "cache": false },
    "db:migrate": { "cache": false }
  }
}
EOF
success "Created turbo.json"

write_file_heredoc "docker-compose.yml" << 'EOF'
services:
  postgres:
    image: postgres:17-alpine
    restart: unless-stopped
    ports:
      - "5432:5432"
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: app
    volumes:
      - pgdata:/var/lib/postgresql/data

volumes:
  pgdata:
EOF
success "Created docker-compose.yml"

write_file_heredoc ".env.example" << 'EOF'
# Database
DATABASE_URL="postgresql://postgres:postgres@localhost:5432/app?schema=public"

# NextAuth
AUTH_SECRET="generate-with-openssl-rand-base64-32"
AUTH_URL="http://localhost:3000"

# Stripe
STRIPE_SECRET_KEY="sk_test_..."
STRIPE_PUBLISHABLE_KEY="pk_test_..."
STRIPE_WEBHOOK_SECRET="whsec_..."
STRIPE_PRO_PRICE_ID="price_..."

# GitHub OAuth (optional)
AUTH_GITHUB_ID=""
AUTH_GITHUB_SECRET=""
EOF
success "Created .env.example"

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

write_file_heredoc "packages/tsconfig/node.json" << 'EOF'
{
  "extends": "./base.json",
  "compilerOptions": {
    "target": "ES2024",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "lib": ["ES2024"],
    "outDir": "dist",
    "sourceMap": true
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
export * from "./types.js";
export * from "./plans.js";
EOF

write_file_heredoc "packages/shared/src/types.ts" << 'EOF'
export interface User {
  id: string;
  email: string;
  name: string | null;
  image: string | null;
  stripeCustomerId: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface Subscription {
  id: string;
  userId: string;
  stripeSubscriptionId: string;
  stripePriceId: string;
  status: string;
  currentPeriodStart: Date;
  currentPeriodEnd: Date;
  createdAt: Date;
  updatedAt: Date;
}

export interface ApiResponse<T> {
  data: T;
  message?: string;
}
EOF

write_file_heredoc "packages/shared/src/plans.ts" << 'EOF'
export interface Plan {
  name: string;
  slug: string;
  description: string;
  features: string[];
  price: number;
  stripePriceId: string | null;
}

export const PLANS: Plan[] = [
  {
    name: "Free",
    slug: "free",
    description: "Get started for free",
    features: ["Up to 3 projects", "Basic analytics", "Community support"],
    price: 0,
    stripePriceId: null,
  },
  {
    name: "Pro",
    slug: "pro",
    description: "For growing teams",
    features: [
      "Unlimited projects",
      "Advanced analytics",
      "Priority support",
      "Custom domains",
      "Team collaboration",
    ],
    price: 20,
    stripePriceId: process.env.STRIPE_PRO_PRICE_ID ?? null,
  },
];
EOF
success "Created packages/shared"

# ══════════════════════════════════════════════════════════════
# packages/database (Drizzle)
# ══════════════════════════════════════════════════════════════
section "packages/database (Drizzle)"
mkdir -p packages/database/src

write_file_heredoc "packages/database/package.json" << 'EOF'
{
  "name": "@repo/database",
  "version": "0.0.0",
  "private": true,
  "type": "module",
  "main": "./src/index.ts",
  "types": "./src/index.ts",
  "scripts": {
    "db:generate": "drizzle-kit generate",
    "db:push": "drizzle-kit push",
    "db:migrate": "drizzle-kit migrate",
    "db:studio": "drizzle-kit studio"
  },
  "dependencies": {
    "drizzle-orm": "^0.44.0",
    "postgres": "^3.4.5"
  },
  "devDependencies": {
    "@repo/tsconfig": "workspace:*",
    "drizzle-kit": "^0.31.0",
    "typescript": "^5.8.3"
  }
}
EOF

write_file_heredoc "packages/database/tsconfig.json" << 'EOF'
{
  "extends": "@repo/tsconfig/base.json",
  "compilerOptions": {
    "target": "ES2024",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "outDir": "dist",
    "rootDir": "src"
  },
  "include": ["src", "drizzle.config.ts"]
}
EOF

write_file_heredoc "packages/database/drizzle.config.ts" << 'EOF'
import { defineConfig } from "drizzle-kit";

export default defineConfig({
  schema: "./src/schema.ts",
  out: "./drizzle",
  dialect: "postgresql",
  dbCredentials: {
    url: process.env.DATABASE_URL!,
  },
});
EOF

write_file_heredoc "packages/database/src/schema.ts" << 'EOF'
import { pgTable, text, timestamp, boolean, integer } from "drizzle-orm/pg-core";

export const users = pgTable("users", {
  id: text("id").primaryKey().$defaultFn(() => crypto.randomUUID()),
  email: text("email").notNull().unique(),
  name: text("name"),
  image: text("image"),
  emailVerified: timestamp("email_verified"),
  stripeCustomerId: text("stripe_customer_id").unique(),
  createdAt: timestamp("created_at").defaultNow().notNull(),
  updatedAt: timestamp("updated_at").defaultNow().notNull(),
});

export const accounts = pgTable("accounts", {
  id: text("id").primaryKey().$defaultFn(() => crypto.randomUUID()),
  userId: text("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
  type: text("type").notNull(),
  provider: text("provider").notNull(),
  providerAccountId: text("provider_account_id").notNull(),
  refreshToken: text("refresh_token"),
  accessToken: text("access_token"),
  expiresAt: integer("expires_at"),
  tokenType: text("token_type"),
  scope: text("scope"),
  idToken: text("id_token"),
  sessionState: text("session_state"),
});

export const sessions = pgTable("sessions", {
  id: text("id").primaryKey().$defaultFn(() => crypto.randomUUID()),
  sessionToken: text("session_token").notNull().unique(),
  userId: text("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
  expires: timestamp("expires").notNull(),
});

export const subscriptions = pgTable("subscriptions", {
  id: text("id").primaryKey().$defaultFn(() => crypto.randomUUID()),
  userId: text("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
  stripeSubscriptionId: text("stripe_subscription_id").notNull().unique(),
  stripePriceId: text("stripe_price_id").notNull(),
  status: text("status").notNull().default("active"),
  currentPeriodStart: timestamp("current_period_start").notNull(),
  currentPeriodEnd: timestamp("current_period_end").notNull(),
  cancelAtPeriodEnd: boolean("cancel_at_period_end").default(false).notNull(),
  createdAt: timestamp("created_at").defaultNow().notNull(),
  updatedAt: timestamp("updated_at").defaultNow().notNull(),
});
EOF

write_file_heredoc "packages/database/src/index.ts" << 'EOF'
import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import * as schema from "./schema.js";

const connectionString = process.env.DATABASE_URL!;
const client = postgres(connectionString);

export const db = drizzle(client, { schema });

export { schema };
export * from "./schema.js";
EOF
success "Created packages/database"

# ══════════════════════════════════════════════════════════════
# apps/web (Next.js 15 + NextAuth 5 + Stripe)
# ══════════════════════════════════════════════════════════════
section "apps/web (Next.js 15 + NextAuth + Stripe)"
mkdir -p apps/web/src/app/api/auth apps/web/src/app/api/stripe apps/web/src/app/dashboard apps/web/src/app/pricing apps/web/src/lib apps/web/public

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
    "@repo/database": "workspace:*",
    "@repo/shared": "workspace:*",
    "next": "^15.3.0",
    "next-auth": "^5.0.0-beta.28",
    "@auth/drizzle-adapter": "^1.8.0",
    "react": "^19.1.0",
    "react-dom": "^19.1.0",
    "stripe": "^17.7.0"
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
    "paths": { "@/*": ["./src/*"] }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
EOF

write_file "apps/web/next.config.ts" 'import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  transpilePackages: ["@repo/shared", "@repo/database"],
};

export default nextConfig;'

write_file "apps/web/postcss.config.mjs" 'const config = {
  plugins: {
    "@tailwindcss/postcss": {},
  },
};

export default config;'

write_file "apps/web/src/app/globals.css" '@import "tailwindcss";'

write_file "apps/web/next-env.d.ts" '/// <reference types="next" />
/// <reference types="next/image-types/global" />'

# ── Auth config ───────────────────────────────────────────────
write_file_heredoc "apps/web/src/lib/auth.ts" << 'EOF'
import NextAuth from "next-auth";
import GitHub from "next-auth/providers/github";
import { DrizzleAdapter } from "@auth/drizzle-adapter";
import { db } from "@repo/database";

export const { handlers, auth, signIn, signOut } = NextAuth({
  adapter: DrizzleAdapter(db),
  providers: [GitHub],
  callbacks: {
    session: ({ session, user }) => ({
      ...session,
      user: {
        ...session.user,
        id: user.id,
      },
    }),
  },
  pages: {
    signIn: "/auth/signin",
  },
});
EOF

# ── Stripe config ─────────────────────────────────────────────
write_file_heredoc "apps/web/src/lib/stripe.ts" << 'EOF'
import Stripe from "stripe";

if (!process.env.STRIPE_SECRET_KEY) {
  throw new Error("STRIPE_SECRET_KEY is not set");
}

export const stripe = new Stripe(process.env.STRIPE_SECRET_KEY, {
  apiVersion: "2025-03-31.basil",
  typescript: true,
});
EOF

# ── Auth route ────────────────────────────────────────────────
write_file_heredoc "apps/web/src/app/api/auth/[...nextauth]/route.ts" << 'EOF'
import { handlers } from "@/lib/auth";

export const { GET, POST } = handlers;
EOF

# ── Stripe checkout route ────────────────────────────────────
write_file_heredoc "apps/web/src/app/api/stripe/checkout/route.ts" << 'EOF'
import { NextResponse } from "next/server";
import { auth } from "@/lib/auth";
import { stripe } from "@/lib/stripe";
import { db, schema } from "@repo/database";
import { eq } from "drizzle-orm";

export async function POST(req: Request) {
  try {
    const session = await auth();
    if (!session?.user?.id) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    const { priceId } = await req.json();
    if (!priceId) {
      return NextResponse.json({ error: "Price ID required" }, { status: 400 });
    }

    // Get or create Stripe customer
    const [user] = await db
      .select()
      .from(schema.users)
      .where(eq(schema.users.id, session.user.id));

    let customerId = user?.stripeCustomerId;

    if (!customerId) {
      const customer = await stripe.customers.create({
        email: session.user.email!,
        metadata: { userId: session.user.id },
      });
      customerId = customer.id;
      await db
        .update(schema.users)
        .set({ stripeCustomerId: customerId })
        .where(eq(schema.users.id, session.user.id));
    }

    const checkoutSession = await stripe.checkout.sessions.create({
      customer: customerId,
      mode: "subscription",
      payment_method_types: ["card"],
      line_items: [{ price: priceId, quantity: 1 }],
      success_url: `${process.env.AUTH_URL}/dashboard?success=true`,
      cancel_url: `${process.env.AUTH_URL}/pricing?canceled=true`,
      metadata: { userId: session.user.id },
    });

    return NextResponse.json({ url: checkoutSession.url });
  } catch (error) {
    console.error("Checkout error:", error);
    return NextResponse.json({ error: "Internal server error" }, { status: 500 });
  }
}
EOF

# ── Stripe portal route ──────────────────────────────────────
write_file_heredoc "apps/web/src/app/api/stripe/portal/route.ts" << 'EOF'
import { NextResponse } from "next/server";
import { auth } from "@/lib/auth";
import { stripe } from "@/lib/stripe";
import { db, schema } from "@repo/database";
import { eq } from "drizzle-orm";

export async function POST() {
  try {
    const session = await auth();
    if (!session?.user?.id) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    const [user] = await db
      .select()
      .from(schema.users)
      .where(eq(schema.users.id, session.user.id));

    if (!user?.stripeCustomerId) {
      return NextResponse.json({ error: "No billing account" }, { status: 400 });
    }

    const portalSession = await stripe.billingPortal.sessions.create({
      customer: user.stripeCustomerId,
      return_url: `${process.env.AUTH_URL}/dashboard`,
    });

    return NextResponse.json({ url: portalSession.url });
  } catch (error) {
    console.error("Portal error:", error);
    return NextResponse.json({ error: "Internal server error" }, { status: 500 });
  }
}
EOF

# ── Layout ────────────────────────────────────────────────────
write_file_heredoc "apps/web/src/app/layout.tsx" << 'EOF'
import type { Metadata } from "next";
import Link from "next/link";
import { auth, signOut } from "@/lib/auth";
import "./globals.css";

export const metadata: Metadata = {
  title: "SaaS App",
  description: "SaaS application template",
};

export default async function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  const session = await auth();

  return (
    <html lang="en">
      <body className="antialiased bg-gray-50 text-gray-900">
        <nav className="border-b bg-white">
          <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
            <div className="flex h-16 items-center justify-between">
              <Link href="/" className="text-lg font-bold">
                SaaS
              </Link>
              <div className="flex items-center gap-4">
                <Link href="/pricing" className="text-sm text-gray-600 hover:text-gray-900">
                  Pricing
                </Link>
                {session?.user ? (
                  <>
                    <Link href="/dashboard" className="text-sm text-gray-600 hover:text-gray-900">
                      Dashboard
                    </Link>
                    <form
                      action={async () => {
                        "use server";
                        await signOut();
                      }}
                    >
                      <button className="text-sm text-gray-600 hover:text-gray-900">
                        Sign out
                      </button>
                    </form>
                  </>
                ) : (
                  <Link
                    href="/api/auth/signin"
                    className="rounded-full bg-gray-900 px-4 py-2 text-sm font-medium text-white hover:bg-gray-800"
                  >
                    Sign in
                  </Link>
                )}
              </div>
            </div>
          </div>
        </nav>
        {children}
      </body>
    </html>
  );
}
EOF

# ── Home page ─────────────────────────────────────────────────
write_file_heredoc "apps/web/src/app/page.tsx" << 'EOF'
import Link from "next/link";

export default function Home() {
  return (
    <div className="mx-auto max-w-7xl px-4 py-24 sm:px-6 lg:px-8">
      <div className="text-center">
        <h1 className="text-5xl font-bold tracking-tight sm:text-7xl">
          Build your <span className="text-blue-600">SaaS</span> faster
        </h1>
        <p className="mx-auto mt-6 max-w-2xl text-lg text-gray-600">
          Full-stack SaaS template with authentication, payments, and everything
          you need to ship your product.
        </p>
        <div className="mt-10 flex items-center justify-center gap-4">
          <Link
            href="/pricing"
            className="rounded-full bg-blue-600 px-8 py-3 text-sm font-semibold text-white hover:bg-blue-700 transition-colors"
          >
            View Pricing
          </Link>
          <Link
            href="/dashboard"
            className="rounded-full border border-gray-300 px-8 py-3 text-sm font-semibold hover:bg-gray-50 transition-colors"
          >
            Dashboard
          </Link>
        </div>
      </div>
    </div>
  );
}
EOF

# ── Pricing page ──────────────────────────────────────────────
write_file_heredoc "apps/web/src/app/pricing/page.tsx" << 'EOF'
"use client";

import { PLANS } from "@repo/shared";
import { useRouter } from "next/navigation";
import { useState } from "react";

export default function PricingPage() {
  const router = useRouter();
  const [loading, setLoading] = useState<string | null>(null);

  async function handleSubscribe(priceId: string | null) {
    if (!priceId) return;
    setLoading(priceId);
    try {
      const res = await fetch("/api/stripe/checkout", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ priceId }),
      });
      const data = await res.json();
      if (data.url) {
        router.push(data.url);
      }
    } catch (error) {
      console.error("Checkout error:", error);
    } finally {
      setLoading(null);
    }
  }

  return (
    <div className="mx-auto max-w-5xl px-4 py-24 sm:px-6 lg:px-8">
      <div className="text-center">
        <h1 className="text-4xl font-bold tracking-tight">Simple pricing</h1>
        <p className="mt-4 text-lg text-gray-600">
          Choose the plan that works best for you.
        </p>
      </div>
      <div className="mt-16 grid gap-8 sm:grid-cols-2">
        {PLANS.map((plan) => (
          <div
            key={plan.slug}
            className={`rounded-2xl border p-8 ${
              plan.slug === "pro"
                ? "border-blue-600 ring-1 ring-blue-600"
                : "border-gray-200"
            }`}
          >
            <h2 className="text-lg font-semibold">{plan.name}</h2>
            <p className="mt-2 text-sm text-gray-600">{plan.description}</p>
            <p className="mt-6 text-4xl font-bold">
              ${plan.price}
              {plan.price > 0 && (
                <span className="text-base font-normal text-gray-500">/mo</span>
              )}
            </p>
            <ul className="mt-8 space-y-3">
              {plan.features.map((feature) => (
                <li key={feature} className="flex items-center gap-2 text-sm">
                  <span className="text-green-500">&#10003;</span>
                  {feature}
                </li>
              ))}
            </ul>
            <button
              onClick={() => handleSubscribe(plan.stripePriceId)}
              disabled={!plan.stripePriceId || loading === plan.stripePriceId}
              className={`mt-8 w-full rounded-full px-4 py-3 text-sm font-semibold transition-colors ${
                plan.slug === "pro"
                  ? "bg-blue-600 text-white hover:bg-blue-700 disabled:opacity-50"
                  : "border border-gray-300 hover:bg-gray-50"
              }`}
            >
              {plan.stripePriceId
                ? loading === plan.stripePriceId
                  ? "Redirecting..."
                  : "Subscribe"
                : "Current plan"}
            </button>
          </div>
        ))}
      </div>
    </div>
  );
}
EOF

# ── Dashboard page ────────────────────────────────────────────
write_file_heredoc "apps/web/src/app/dashboard/page.tsx" << 'EOF'
import { redirect } from "next/navigation";
import { auth } from "@/lib/auth";
import { db, schema } from "@repo/database";
import { eq } from "drizzle-orm";
import { ManageBilling } from "./manage-billing";

export default async function DashboardPage() {
  const session = await auth();
  if (!session?.user) redirect("/api/auth/signin");

  const [subscription] = await db
    .select()
    .from(schema.subscriptions)
    .where(eq(schema.subscriptions.userId, session.user.id!));

  return (
    <div className="mx-auto max-w-4xl px-4 py-16 sm:px-6 lg:px-8">
      <h1 className="text-3xl font-bold">Dashboard</h1>
      <p className="mt-2 text-gray-600">Welcome back, {session.user.name ?? session.user.email}!</p>

      <div className="mt-8 grid gap-6 sm:grid-cols-2">
        <div className="rounded-xl border border-gray-200 bg-white p-6">
          <h2 className="text-sm font-medium text-gray-500">Plan</h2>
          <p className="mt-1 text-2xl font-semibold">
            {subscription ? "Pro" : "Free"}
          </p>
          {subscription && (
            <p className="mt-1 text-sm text-gray-500">
              Status: {subscription.status}
            </p>
          )}
        </div>
        <div className="rounded-xl border border-gray-200 bg-white p-6">
          <h2 className="text-sm font-medium text-gray-500">Billing</h2>
          <ManageBilling hasSubscription={!!subscription} />
        </div>
      </div>
    </div>
  );
}
EOF

write_file_heredoc "apps/web/src/app/dashboard/manage-billing.tsx" << 'EOF'
"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";

export function ManageBilling({ hasSubscription }: { hasSubscription: boolean }) {
  const router = useRouter();
  const [loading, setLoading] = useState(false);

  async function handleManage() {
    setLoading(true);
    try {
      const res = await fetch("/api/stripe/portal", { method: "POST" });
      const data = await res.json();
      if (data.url) router.push(data.url);
    } catch (error) {
      console.error("Portal error:", error);
    } finally {
      setLoading(false);
    }
  }

  if (!hasSubscription) {
    return (
      <button
        onClick={() => router.push("/pricing")}
        className="mt-3 rounded-full bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
      >
        Upgrade to Pro
      </button>
    );
  }

  return (
    <button
      onClick={handleManage}
      disabled={loading}
      className="mt-3 rounded-full border border-gray-300 px-4 py-2 text-sm font-medium hover:bg-gray-50 disabled:opacity-50"
    >
      {loading ? "Loading..." : "Manage subscription"}
    </button>
  );
}
EOF

success "Created apps/web"

# ══════════════════════════════════════════════════════════════
# apps/api (Hono 4 + Stripe webhooks)
# ══════════════════════════════════════════════════════════════
section "apps/api (Hono + Stripe webhooks)"
mkdir -p apps/api/src/routes

write_file_heredoc "apps/api/package.json" << 'EOF'
{
  "name": "@repo/api",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "tsx watch src/index.ts",
    "build": "tsc",
    "start": "node dist/index.js",
    "lint": "eslint ."
  },
  "dependencies": {
    "@repo/database": "workspace:*",
    "@repo/shared": "workspace:*",
    "hono": "^4.7.0",
    "@hono/node-server": "^1.14.0",
    "stripe": "^17.7.0"
  },
  "devDependencies": {
    "@repo/tsconfig": "workspace:*",
    "@types/node": "^22.14.0",
    "tsx": "^4.19.0",
    "typescript": "^5.8.3"
  }
}
EOF

write_file_heredoc "apps/api/tsconfig.json" << 'EOF'
{
  "extends": "@repo/tsconfig/node.json",
  "compilerOptions": {
    "rootDir": "src",
    "outDir": "dist"
  },
  "include": ["src"]
}
EOF

write_file_heredoc "apps/api/src/index.ts" << 'EOF'
import { serve } from "@hono/node-server";
import { app } from "./app.js";

const port = Number(process.env.PORT) || 4000;

console.log(`API server running on http://localhost:${port}`);

serve({ fetch: app.fetch, port });
EOF

write_file_heredoc "apps/api/src/app.ts" << 'EOF'
import { Hono } from "hono";
import { cors } from "hono/cors";
import { logger } from "hono/logger";
import { webhookRoute } from "./routes/webhook.js";
import { usersRoute } from "./routes/users.js";

export const app = new Hono()
  .use("*", logger())
  .use("*", cors())
  .get("/health", (c) => c.json({ status: "ok", timestamp: new Date().toISOString() }))
  .route("/api/webhooks/stripe", webhookRoute)
  .route("/api/users", usersRoute);

export type AppType = typeof app;
EOF

write_file_heredoc "apps/api/src/routes/users.ts" << 'EOF'
import { Hono } from "hono";
import { db, schema } from "@repo/database";
import { eq } from "drizzle-orm";

export const usersRoute = new Hono()
  .get("/", async (c) => {
    const users = await db.select().from(schema.users);
    return c.json({ data: users });
  })
  .get("/:id", async (c) => {
    const id = c.req.param("id");
    const [user] = await db.select().from(schema.users).where(eq(schema.users.id, id));
    if (!user) return c.json({ error: "User not found" }, 404);
    return c.json({ data: user });
  });
EOF

write_file_heredoc "apps/api/src/routes/webhook.ts" << 'EOF'
import { Hono } from "hono";
import Stripe from "stripe";
import { db, schema } from "@repo/database";
import { eq } from "drizzle-orm";

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: "2025-03-31.basil",
});

export const webhookRoute = new Hono().post("/", async (c) => {
  const body = await c.req.text();
  const signature = c.req.header("stripe-signature");

  if (!signature) {
    return c.json({ error: "Missing signature" }, 400);
  }

  let event: Stripe.Event;
  try {
    event = stripe.webhooks.constructEvent(
      body,
      signature,
      process.env.STRIPE_WEBHOOK_SECRET!,
    );
  } catch (err) {
    console.error("Webhook signature verification failed:", err);
    return c.json({ error: "Invalid signature" }, 400);
  }

  switch (event.type) {
    case "checkout.session.completed": {
      const session = event.data.object as Stripe.Checkout.Session;
      const userId = session.metadata?.userId;
      if (!userId || !session.subscription) break;

      const subscription = await stripe.subscriptions.retrieve(
        session.subscription as string,
      );

      await db.insert(schema.subscriptions).values({
        userId,
        stripeSubscriptionId: subscription.id,
        stripePriceId: subscription.items.data[0]!.price.id,
        status: subscription.status,
        currentPeriodStart: new Date(subscription.current_period_start * 1000),
        currentPeriodEnd: new Date(subscription.current_period_end * 1000),
      });
      break;
    }

    case "customer.subscription.updated": {
      const subscription = event.data.object as Stripe.Subscription;
      await db
        .update(schema.subscriptions)
        .set({
          status: subscription.status,
          stripePriceId: subscription.items.data[0]!.price.id,
          currentPeriodStart: new Date(subscription.current_period_start * 1000),
          currentPeriodEnd: new Date(subscription.current_period_end * 1000),
          cancelAtPeriodEnd: subscription.cancel_at_period_end,
          updatedAt: new Date(),
        })
        .where(eq(schema.subscriptions.stripeSubscriptionId, subscription.id));
      break;
    }

    case "customer.subscription.deleted": {
      const subscription = event.data.object as Stripe.Subscription;
      await db
        .update(schema.subscriptions)
        .set({ status: "canceled", updatedAt: new Date() })
        .where(eq(schema.subscriptions.stripeSubscriptionId, subscription.id));
      break;
    }

    default:
      console.log(`Unhandled event type: ${event.type}`);
  }

  return c.json({ received: true });
});
EOF
success "Created apps/api"

# ── Finalize ──────────────────────────────────────────────────
section "Finalizing"
init_git
write_gitignore ".env" "drizzle/"
write_editorconfig
write_nvmrc

write_readme "$PROJECT_NAME" \
  "Full-stack SaaS template with Turborepo, Next.js 15, Hono 4, Drizzle, Stripe, and NextAuth 5." \
  "pnpm install" \
  "pnpm dev"

finish "pnpm install" "docker compose up -d && pnpm dev"
