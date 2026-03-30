#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-saas-landing" "$@"
create_project_dir

# --- package.json ---
write_package_json '{
  "name": "'"$PROJECT_NAME"'",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "astro dev",
    "build": "astro build",
    "preview": "astro preview",
    "check": "astro check"
  },
  "dependencies": {
    "astro": "^5.7.0",
    "@astrojs/node": "^9.1.0",
    "stripe": "^17.7.0",
    "tailwindcss": "^4.1.3",
    "@tailwindcss/vite": "^4.1.3"
  },
  "devDependencies": {
    "@types/node": "^22.14.0",
    "typescript": "^5.8.3"
  }
}'

# --- astro.config.mjs ---
write_file "astro.config.mjs" 'import { defineConfig } from "astro/config";
import node from "@astrojs/node";
import tailwindcss from "@tailwindcss/vite";

export default defineConfig({
  output: "server",
  adapter: node({ mode: "standalone" }),
  vite: {
    plugins: [tailwindcss()],
  },
});'

# --- tsconfig.json ---
write_tsconfig '{
  "extends": "astro/tsconfigs/strict",
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@/*": ["src/*"]
    }
  }
}'

# --- .env.example ---
write_file ".env.example" '# Stripe Keys - get yours at https://dashboard.stripe.com
STRIPE_SECRET_KEY=sk_test_your_secret_key
STRIPE_PUBLISHABLE_KEY=pk_test_your_publishable_key
STRIPE_WEBHOOK_SECRET=whsec_your_webhook_secret

# Price IDs from Stripe Dashboard
STRIPE_PRICE_ID_PRO=price_your_pro_price_id
STRIPE_PRICE_ID_ENTERPRISE=price_your_enterprise_price_id

# Site URL
SITE_URL=http://localhost:4321'

# --- src/styles/global.css ---
write_file "src/styles/global.css" '@import "tailwindcss";

@theme {
  --color-primary: #6366f1;
  --color-primary-dark: #4f46e5;
  --color-primary-light: #818cf8;
}'

# --- src/layouts/BaseLayout.astro ---
write_file "src/layouts/BaseLayout.astro" '---
import "../styles/global.css";

interface Props {
  title: string;
  description?: string;
}

const { title, description = "SaaS platform" } = Astro.props;
---

<!doctype html>
<html lang="en" class="scroll-smooth">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <meta name="description" content={description} />
    <link rel="icon" type="image/svg+xml" href="/favicon.svg" />
    <title>{title}</title>
  </head>
  <body class="bg-white text-gray-900 antialiased">
    <slot />
  </body>
</html>'

# --- src/components/Hero.astro ---
write_file "src/components/Hero.astro" '<section class="relative overflow-hidden px-6 pt-32 pb-24">
  <div class="absolute inset-0 -z-10 bg-gradient-to-b from-indigo-50 via-white to-white"></div>
  <div class="mx-auto max-w-4xl text-center">
    <span class="mb-6 inline-block rounded-full border border-indigo-200 bg-indigo-50 px-4 py-1.5 text-sm font-medium text-indigo-700">
      Launch your SaaS faster
    </span>
    <h1 class="text-5xl font-bold leading-tight tracking-tight sm:text-7xl">
      Ship your product
      <span class="bg-gradient-to-r from-indigo-600 to-violet-600 bg-clip-text text-transparent">
        in days, not months
      </span>
    </h1>
    <p class="mx-auto mt-6 max-w-2xl text-lg leading-relaxed text-gray-600">
      Everything you need to build, launch, and grow your SaaS. Authentication,
      payments, email, and more — all pre-configured and ready to go.
    </p>
    <div class="mt-10 flex flex-col items-center gap-4 sm:flex-row sm:justify-center">
      <a
        href="#pricing"
        class="rounded-full bg-indigo-600 px-8 py-3.5 text-sm font-medium text-white shadow-lg transition-all hover:bg-indigo-700 hover:shadow-xl"
      >
        Get Started — $29/mo
      </a>
      <a
        href="#features"
        class="rounded-full border border-gray-300 px-8 py-3.5 text-sm font-medium text-gray-700 transition-colors hover:bg-gray-50"
      >
        See Features
      </a>
    </div>
  </div>
</section>'

# --- src/components/Features.astro ---
write_file "src/components/Features.astro" '---
const features = [
  {
    title: "Authentication",
    description: "Email/password, OAuth, magic links — all built in with session management.",
    icon: "M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z",
  },
  {
    title: "Stripe Payments",
    description: "Subscriptions, one-time payments, and usage-based billing pre-configured.",
    icon: "M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z",
  },
  {
    title: "Email System",
    description: "Transactional emails with beautiful templates using React Email + Resend.",
    icon: "M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z",
  },
  {
    title: "Database Ready",
    description: "PostgreSQL with Drizzle ORM — type-safe queries with automatic migrations.",
    icon: "M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4",
  },
];
---

<section id="features" class="px-6 py-24">
  <div class="mx-auto max-w-7xl">
    <div class="text-center">
      <h2 class="text-3xl font-bold tracking-tight sm:text-4xl">
        Everything you need to launch
      </h2>
      <p class="mx-auto mt-4 max-w-2xl text-lg text-gray-600">
        Stop rebuilding the same features. Focus on what makes your product unique.
      </p>
    </div>
    <div class="mt-16 grid gap-8 sm:grid-cols-2">
      {features.map((feature) => (
        <div class="rounded-2xl border border-gray-100 bg-white p-8 shadow-sm transition-shadow hover:shadow-md">
          <div class="flex h-12 w-12 items-center justify-center rounded-lg bg-indigo-50">
            <svg class="h-6 w-6 text-indigo-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round" d={feature.icon} />
            </svg>
          </div>
          <h3 class="mt-4 text-lg font-semibold">{feature.title}</h3>
          <p class="mt-2 text-gray-600">{feature.description}</p>
        </div>
      ))}
    </div>
  </div>
</section>'

# --- src/components/Pricing.astro ---
write_file "src/components/Pricing.astro" '---
const plans = [
  {
    name: "Starter",
    price: "$0",
    period: "/month",
    description: "For side projects and experiments.",
    features: ["Up to 100 users", "Basic analytics", "Community support", "1 project"],
    cta: "Start Free",
    priceId: null,
    popular: false,
  },
  {
    name: "Pro",
    price: "$29",
    period: "/month",
    description: "For growing SaaS businesses.",
    features: ["Unlimited users", "Advanced analytics", "Priority support", "Unlimited projects", "Custom domain", "API access"],
    cta: "Start Free Trial",
    priceId: "pro",
    popular: true,
  },
  {
    name: "Enterprise",
    price: "$99",
    period: "/month",
    description: "For large teams and organizations.",
    features: ["Everything in Pro", "SSO / SAML", "Dedicated support", "SLA guarantee", "Custom integrations", "On-premise option"],
    cta: "Contact Sales",
    priceId: "enterprise",
    popular: false,
  },
];
---

<section id="pricing" class="bg-gray-50 px-6 py-24">
  <div class="mx-auto max-w-7xl">
    <div class="text-center">
      <h2 class="text-3xl font-bold tracking-tight sm:text-4xl">
        Simple pricing, no surprises
      </h2>
      <p class="mx-auto mt-4 max-w-2xl text-lg text-gray-600">
        Start free. Upgrade when you are ready.
      </p>
    </div>
    <div class="mt-16 grid gap-8 lg:grid-cols-3">
      {plans.map((plan) => (
        <div class={`relative rounded-2xl bg-white p-8 shadow-sm ${plan.popular ? "ring-2 ring-indigo-600 shadow-lg" : "border border-gray-200"}`}>
          {plan.popular && (
            <span class="absolute -top-3 left-1/2 -translate-x-1/2 rounded-full bg-indigo-600 px-4 py-1 text-xs font-semibold text-white">
              Most Popular
            </span>
          )}
          <h3 class="text-lg font-semibold">{plan.name}</h3>
          <div class="mt-4 flex items-baseline">
            <span class="text-4xl font-bold">{plan.price}</span>
            <span class="ml-1 text-gray-500">{plan.period}</span>
          </div>
          <p class="mt-2 text-sm text-gray-600">{plan.description}</p>
          <ul class="mt-8 space-y-3">
            {plan.features.map((feature) => (
              <li class="flex items-center gap-3 text-sm">
                <svg class="h-5 w-5 shrink-0 text-indigo-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                </svg>
                {feature}
              </li>
            ))}
          </ul>
          {plan.priceId ? (
            <a
              href={`/api/checkout?plan=${plan.priceId}`}
              class={`mt-8 block rounded-full py-3 text-center text-sm font-medium transition-colors ${
                plan.popular
                  ? "bg-indigo-600 text-white hover:bg-indigo-700"
                  : "border border-gray-300 text-gray-700 hover:bg-gray-50"
              }`}
            >
              {plan.cta}
            </a>
          ) : (
            <a
              href="#"
              class="mt-8 block rounded-full border border-gray-300 py-3 text-center text-sm font-medium text-gray-700 transition-colors hover:bg-gray-50"
            >
              {plan.cta}
            </a>
          )}
        </div>
      ))}
    </div>
  </div>
</section>'

# --- src/components/CTA.astro ---
write_file "src/components/CTA.astro" '<section class="px-6 py-24">
  <div class="mx-auto max-w-4xl rounded-2xl bg-gradient-to-r from-indigo-600 to-violet-600 px-8 py-16 text-center text-white shadow-xl">
    <h2 class="text-3xl font-bold tracking-tight sm:text-4xl">
      Ready to launch your SaaS?
    </h2>
    <p class="mx-auto mt-4 max-w-xl text-lg text-indigo-100">
      Join thousands of founders who shipped their products faster with our platform.
    </p>
    <div class="mt-8 flex flex-col items-center gap-4 sm:flex-row sm:justify-center">
      <a
        href="#pricing"
        class="rounded-full bg-white px-8 py-3.5 text-sm font-medium text-indigo-600 shadow-lg transition-all hover:bg-indigo-50 hover:shadow-xl"
      >
        Get Started Now
      </a>
      <a
        href="https://github.com"
        class="rounded-full border border-white/30 px-8 py-3.5 text-sm font-medium text-white transition-colors hover:bg-white/10"
      >
        View on GitHub
      </a>
    </div>
  </div>
</section>'

# --- src/pages/index.astro ---
write_file "src/pages/index.astro" '---
import BaseLayout from "../layouts/BaseLayout.astro";
import Hero from "../components/Hero.astro";
import Features from "../components/Features.astro";
import Pricing from "../components/Pricing.astro";
import CTA from "../components/CTA.astro";
---

<BaseLayout title="'"$PROJECT_NAME"' - Ship Your SaaS Faster">
  <header class="fixed top-0 z-50 w-full border-b border-gray-100 bg-white/80 backdrop-blur-md">
    <nav class="mx-auto flex max-w-7xl items-center justify-between px-6 py-4">
      <a href="/" class="text-xl font-bold">'"$PROJECT_NAME"'</a>
      <div class="flex items-center gap-8">
        <a href="#features" class="text-sm text-gray-600 transition-colors hover:text-gray-900">Features</a>
        <a href="#pricing" class="text-sm text-gray-600 transition-colors hover:text-gray-900">Pricing</a>
        <a
          href="#pricing"
          class="rounded-full bg-indigo-600 px-5 py-2 text-sm font-medium text-white transition-colors hover:bg-indigo-700"
        >
          Get Started
        </a>
      </div>
    </nav>
  </header>
  <main>
    <Hero />
    <Features />
    <Pricing />
    <CTA />
  </main>
  <footer class="border-t border-gray-200 px-6 py-8 text-center text-sm text-gray-500">
    &copy; {new Date().getFullYear()} '"$PROJECT_NAME"'. All rights reserved.
  </footer>
</BaseLayout>'

# --- src/pages/api/checkout.ts ---
write_file "src/pages/api/checkout.ts" 'import type { APIRoute } from "astro";
import Stripe from "stripe";

const stripe = new Stripe(import.meta.env.STRIPE_SECRET_KEY || "");

const PRICE_MAP: Record<string, string> = {
  pro: import.meta.env.STRIPE_PRICE_ID_PRO || "",
  enterprise: import.meta.env.STRIPE_PRICE_ID_ENTERPRISE || "",
};

export const GET: APIRoute = async ({ request, redirect }) => {
  const url = new URL(request.url);
  const plan = url.searchParams.get("plan");

  if (!plan || !PRICE_MAP[plan]) {
    return new Response(JSON.stringify({ error: "Invalid plan" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const siteUrl = import.meta.env.SITE_URL || "http://localhost:4321";

  try {
    const session = await stripe.checkout.sessions.create({
      mode: "subscription",
      payment_method_types: ["card"],
      line_items: [
        {
          price: PRICE_MAP[plan],
          quantity: 1,
        },
      ],
      success_url: `${siteUrl}?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${siteUrl}#pricing`,
    });

    return redirect(session.url!, 303);
  } catch (error) {
    console.error("Stripe checkout error:", error);
    return new Response(
      JSON.stringify({ error: "Failed to create checkout session" }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      }
    );
  }
};'

# --- public/favicon.svg ---
write_file "public/favicon.svg" '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 128 128"><path fill="#6366f1" d="M64 0C28.7 0 0 28.7 0 64s28.7 64 64 64 64-28.7 64-64S99.3 0 64 0zm0 110c-25.4 0-46-20.6-46-46S38.6 18 64 18s46 20.6 46 46-20.6 46-46 46z"/></svg>'

init_git
write_gitignore ".astro/"
write_editorconfig
write_nvmrc

finish "npm install" "npm run dev"
