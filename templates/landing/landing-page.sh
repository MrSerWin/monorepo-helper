#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-landing-page" "$@"
create_project_dir

# --- package.json ---
write_package_json '{
  "name": "'"$PROJECT_NAME"'",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "next dev --turbopack",
    "build": "next build",
    "start": "next start",
    "lint": "next lint"
  },
  "dependencies": {
    "next": "^15.3.0",
    "react": "^19.1.0",
    "react-dom": "^19.1.0",
    "framer-motion": "^12.6.0"
  },
  "devDependencies": {
    "@tailwindcss/postcss": "^4.1.3",
    "@types/node": "^22.14.0",
    "@types/react": "^19.1.0",
    "@types/react-dom": "^19.1.0",
    "tailwindcss": "^4.1.3",
    "typescript": "^5.8.3"
  }
}'

# --- next.config.ts ---
write_file "next.config.ts" 'import type { NextConfig } from "next";

const nextConfig: NextConfig = {};

export default nextConfig;'

# --- tsconfig.json ---
write_tsconfig '{
  "compilerOptions": {
    "target": "ES2017",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [{ "name": "next" }],
    "paths": { "@/*": ["./src/*"] }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}'

# --- postcss.config.mjs ---
write_file "postcss.config.mjs" 'const config = {
  plugins: {
    "@tailwindcss/postcss": {},
  },
};

export default config;'

# --- src/app/globals.css ---
write_file "src/app/globals.css" '@import "tailwindcss";'

# --- src/app/layout.tsx ---
write_file "src/app/layout.tsx" 'import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "'"$PROJECT_NAME"' - Modern Landing Page",
  description: "A beautiful landing page built with Next.js, Tailwind CSS, and Framer Motion",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="scroll-smooth">
      <body className="bg-white text-gray-900 antialiased">
        {children}
      </body>
    </html>
  );
}'

# --- src/app/page.tsx ---
write_file "src/app/page.tsx" 'import { Navbar } from "@/components/Navbar";
import { Hero } from "@/components/Hero";
import { Features } from "@/components/Features";
import { Pricing } from "@/components/Pricing";
import { Footer } from "@/components/Footer";

export default function Home() {
  return (
    <>
      <Navbar />
      <main>
        <Hero />
        <Features />
        <Pricing />
      </main>
      <Footer />
    </>
  );
}'

# --- src/components/Navbar.tsx ---
write_file "src/components/Navbar.tsx" '"use client";

import { useState } from "react";
import { motion } from "framer-motion";

const navLinks = [
  { label: "Features", href: "#features" },
  { label: "Pricing", href: "#pricing" },
  { label: "Contact", href: "#contact" },
];

export function Navbar() {
  const [isOpen, setIsOpen] = useState(false);

  return (
    <motion.header
      initial={{ y: -100 }}
      animate={{ y: 0 }}
      transition={{ duration: 0.5 }}
      className="fixed top-0 z-50 w-full border-b border-gray-100 bg-white/80 backdrop-blur-md"
    >
      <nav className="mx-auto flex max-w-7xl items-center justify-between px-6 py-4">
        <a href="/" className="text-xl font-bold">
          '"$PROJECT_NAME"'
        </a>

        {/* Desktop Navigation */}
        <div className="hidden items-center gap-8 md:flex">
          {navLinks.map((link) => (
            <a
              key={link.href}
              href={link.href}
              className="text-sm text-gray-600 transition-colors hover:text-gray-900"
            >
              {link.label}
            </a>
          ))}
          <a
            href="#pricing"
            className="rounded-full bg-gray-900 px-5 py-2 text-sm font-medium text-white transition-colors hover:bg-gray-700"
          >
            Get Started
          </a>
        </div>

        {/* Mobile Menu Button */}
        <button
          onClick={() => setIsOpen(!isOpen)}
          className="md:hidden"
          aria-label="Toggle menu"
        >
          <svg className="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            {isOpen ? (
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            ) : (
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
            )}
          </svg>
        </button>
      </nav>

      {/* Mobile Navigation */}
      {isOpen && (
        <motion.div
          initial={{ opacity: 0, height: 0 }}
          animate={{ opacity: 1, height: "auto" }}
          className="border-t border-gray-100 bg-white px-6 py-4 md:hidden"
        >
          {navLinks.map((link) => (
            <a
              key={link.href}
              href={link.href}
              onClick={() => setIsOpen(false)}
              className="block py-2 text-gray-600"
            >
              {link.label}
            </a>
          ))}
        </motion.div>
      )}
    </motion.header>
  );
}'

# --- src/components/Hero.tsx ---
write_file "src/components/Hero.tsx" '"use client";

import { motion } from "framer-motion";

export function Hero() {
  return (
    <section className="relative flex min-h-screen items-center justify-center overflow-hidden px-6 pt-20">
      {/* Background gradient */}
      <div className="absolute inset-0 -z-10 bg-gradient-to-b from-blue-50 via-white to-white" />

      <div className="mx-auto max-w-4xl text-center">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
        >
          <span className="mb-6 inline-block rounded-full border border-blue-200 bg-blue-50 px-4 py-1.5 text-sm font-medium text-blue-700">
            Now in Beta
          </span>
        </motion.div>

        <motion.h1
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 0.1 }}
          className="text-5xl font-bold leading-tight tracking-tight sm:text-7xl"
        >
          Build something{" "}
          <span className="bg-gradient-to-r from-blue-600 to-violet-600 bg-clip-text text-transparent">
            amazing
          </span>
        </motion.h1>

        <motion.p
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 0.2 }}
          className="mx-auto mt-6 max-w-2xl text-lg leading-relaxed text-gray-600"
        >
          A modern platform that helps teams ship faster. Streamline your
          workflow, collaborate seamlessly, and deliver exceptional results.
        </motion.p>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 0.3 }}
          className="mt-10 flex flex-col items-center gap-4 sm:flex-row sm:justify-center"
        >
          <a
            href="#pricing"
            className="rounded-full bg-gray-900 px-8 py-3.5 text-sm font-medium text-white shadow-lg transition-all hover:bg-gray-700 hover:shadow-xl"
          >
            Start for Free
          </a>
          <a
            href="#features"
            className="rounded-full border border-gray-300 px-8 py-3.5 text-sm font-medium text-gray-700 transition-colors hover:bg-gray-50"
          >
            Learn More
          </a>
        </motion.div>
      </div>
    </section>
  );
}'

# --- src/components/Features.tsx ---
write_file "src/components/Features.tsx" '"use client";

import { motion } from "framer-motion";

const features = [
  {
    title: "Lightning Fast",
    description: "Optimized for speed with cutting-edge technology that keeps your team moving.",
    icon: "\u26a1",
  },
  {
    title: "Secure by Default",
    description: "Enterprise-grade security built into every layer of the platform.",
    icon: "\ud83d\udd12",
  },
  {
    title: "Team Collaboration",
    description: "Real-time collaboration tools that bring your team together seamlessly.",
    icon: "\ud83d\udc65",
  },
  {
    title: "Analytics & Insights",
    description: "Powerful analytics to help you make data-driven decisions.",
    icon: "\ud83d\udcca",
  },
  {
    title: "API First",
    description: "Comprehensive API that integrates with your existing tools and workflows.",
    icon: "\ud83d\udd17",
  },
  {
    title: "24/7 Support",
    description: "Round-the-clock support from our team of experts whenever you need help.",
    icon: "\ud83d\udcac",
  },
];

const container = {
  hidden: { opacity: 0 },
  show: {
    opacity: 1,
    transition: { staggerChildren: 0.1 },
  },
};

const item = {
  hidden: { opacity: 0, y: 20 },
  show: { opacity: 1, y: 0 },
};

export function Features() {
  return (
    <section id="features" className="px-6 py-24">
      <div className="mx-auto max-w-7xl">
        <div className="text-center">
          <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">
            Everything you need
          </h2>
          <p className="mx-auto mt-4 max-w-2xl text-lg text-gray-600">
            Powerful features to help you manage, collaborate, and scale.
          </p>
        </div>

        <motion.div
          variants={container}
          initial="hidden"
          whileInView="show"
          viewport={{ once: true, margin: "-100px" }}
          className="mt-16 grid gap-8 sm:grid-cols-2 lg:grid-cols-3"
        >
          {features.map((feature) => (
            <motion.div
              key={feature.title}
              variants={item}
              className="rounded-2xl border border-gray-100 bg-white p-8 shadow-sm transition-shadow hover:shadow-md"
            >
              <span className="text-3xl">{feature.icon}</span>
              <h3 className="mt-4 text-lg font-semibold">{feature.title}</h3>
              <p className="mt-2 text-gray-600">{feature.description}</p>
            </motion.div>
          ))}
        </motion.div>
      </div>
    </section>
  );
}'

# --- src/components/Pricing.tsx ---
write_file "src/components/Pricing.tsx" '"use client";

import { motion } from "framer-motion";

const plans = [
  {
    name: "Starter",
    price: "$0",
    period: "/month",
    description: "Perfect for individuals and small projects.",
    features: ["Up to 3 projects", "Basic analytics", "Community support", "1 GB storage"],
    cta: "Get Started",
    popular: false,
  },
  {
    name: "Pro",
    price: "$29",
    period: "/month",
    description: "For growing teams that need more power.",
    features: [
      "Unlimited projects",
      "Advanced analytics",
      "Priority support",
      "50 GB storage",
      "Custom integrations",
      "Team management",
    ],
    cta: "Start Free Trial",
    popular: true,
  },
  {
    name: "Enterprise",
    price: "Custom",
    period: "",
    description: "For large organizations with specific needs.",
    features: [
      "Everything in Pro",
      "Unlimited storage",
      "Dedicated support",
      "SLA guarantee",
      "SSO & SAML",
      "Custom contracts",
    ],
    cta: "Contact Sales",
    popular: false,
  },
];

export function Pricing() {
  return (
    <section id="pricing" className="bg-gray-50 px-6 py-24">
      <div className="mx-auto max-w-7xl">
        <div className="text-center">
          <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">
            Simple, transparent pricing
          </h2>
          <p className="mx-auto mt-4 max-w-2xl text-lg text-gray-600">
            Choose the plan that fits your needs. Upgrade or downgrade anytime.
          </p>
        </div>

        <div className="mt-16 grid gap-8 lg:grid-cols-3">
          {plans.map((plan, index) => (
            <motion.div
              key={plan.name}
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ delay: index * 0.1 }}
              className={`relative rounded-2xl bg-white p-8 shadow-sm ${
                plan.popular ? "ring-2 ring-blue-600 shadow-lg" : "border border-gray-200"
              }`}
            >
              {plan.popular && (
                <span className="absolute -top-3 left-1/2 -translate-x-1/2 rounded-full bg-blue-600 px-4 py-1 text-xs font-semibold text-white">
                  Most Popular
                </span>
              )}
              <h3 className="text-lg font-semibold">{plan.name}</h3>
              <div className="mt-4 flex items-baseline">
                <span className="text-4xl font-bold">{plan.price}</span>
                <span className="ml-1 text-gray-500">{plan.period}</span>
              </div>
              <p className="mt-2 text-sm text-gray-600">{plan.description}</p>
              <ul className="mt-8 space-y-3">
                {plan.features.map((feature) => (
                  <li key={feature} className="flex items-center gap-3 text-sm">
                    <svg className="h-5 w-5 shrink-0 text-blue-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                    </svg>
                    {feature}
                  </li>
                ))}
              </ul>
              <a
                href="#"
                className={`mt-8 block rounded-full py-3 text-center text-sm font-medium transition-colors ${
                  plan.popular
                    ? "bg-blue-600 text-white hover:bg-blue-700"
                    : "border border-gray-300 text-gray-700 hover:bg-gray-50"
                }`}
              >
                {plan.cta}
              </a>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}'

# --- src/components/Footer.tsx ---
write_file "src/components/Footer.tsx" 'const footerLinks = {
  Product: ["Features", "Pricing", "Changelog", "Documentation"],
  Company: ["About", "Blog", "Careers", "Contact"],
  Legal: ["Privacy", "Terms", "License"],
};

export function Footer() {
  return (
    <footer id="contact" className="border-t border-gray-200 bg-white px-6 py-16">
      <div className="mx-auto max-w-7xl">
        <div className="grid gap-8 sm:grid-cols-2 lg:grid-cols-4">
          <div>
            <h3 className="text-lg font-bold">'"$PROJECT_NAME"'</h3>
            <p className="mt-2 text-sm text-gray-600">
              Building the future, one step at a time.
            </p>
          </div>
          {Object.entries(footerLinks).map(([title, links]) => (
            <div key={title}>
              <h4 className="font-semibold">{title}</h4>
              <ul className="mt-3 space-y-2">
                {links.map((link) => (
                  <li key={link}>
                    <a href="#" className="text-sm text-gray-600 transition-colors hover:text-gray-900">
                      {link}
                    </a>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>
        <div className="mt-12 border-t border-gray-200 pt-8 text-center text-sm text-gray-500">
          &copy; {new Date().getFullYear()} '"$PROJECT_NAME"'. All rights reserved.
        </div>
      </div>
    </footer>
  );
}'

# --- next-env.d.ts ---
write_file "next-env.d.ts" '/// <reference types="next" />
/// <reference types="next/image-types/global" />

// NOTE: This file should not be edited
// see https://nextjs.org/docs/app/api-reference/config/typescript for more information.'

# --- public/ ---
write_file "public/.gitkeep" ""

init_git
write_gitignore
write_editorconfig
write_nvmrc

finish "npm install" "npm run dev"
