#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-medusa-store" "$@"
create_project_dir

# --- Root package.json (workspaces) ---
write_package_json '{
  "name": "'"$PROJECT_NAME"'",
  "version": "0.1.0",
  "private": true,
  "workspaces": ["backend", "storefront"]
}'

# ========== BACKEND ==========

# --- backend/package.json ---
write_file "backend/package.json" '{
  "name": "'"$PROJECT_NAME"'-backend",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "medusa develop",
    "start": "medusa start",
    "build": "medusa build",
    "seed": "medusa exec ./src/scripts/seed.ts",
    "db:migrate": "medusa db:migrate"
  },
  "dependencies": {
    "@medusajs/framework": "^2.6.0",
    "@medusajs/medusa": "^2.6.0",
    "@medusajs/medusa-cli": "^2.2.0"
  },
  "devDependencies": {
    "@types/node": "^22.14.0",
    "typescript": "^5.8.3"
  },
  "engines": {
    "node": ">=20"
  }
}'

# --- backend/medusa-config.ts ---
write_file "backend/medusa-config.ts" 'import { defineConfig, loadEnv } from "@medusajs/framework/utils";

loadEnv(process.env.NODE_ENV || "development", process.cwd());

export default defineConfig({
  projectConfig: {
    databaseUrl: process.env.DATABASE_URL,
    redisUrl: process.env.REDIS_URL,
    http: {
      storeCors: process.env.STORE_CORS || "http://localhost:8000",
      adminCors: process.env.ADMIN_CORS || "http://localhost:9000",
      authCors: process.env.AUTH_CORS || "http://localhost:8000,http://localhost:9000",
      jwtSecret: process.env.JWT_SECRET || "supersecret",
      cookieSecret: process.env.COOKIE_SECRET || "supersecret",
    },
  },
  admin: {
    disable: false,
    backendUrl: process.env.MEDUSA_BACKEND_URL || "http://localhost:9000",
  },
});'

# --- backend/tsconfig.json ---
write_file "backend/tsconfig.json" '{
  "compilerOptions": {
    "target": "ES2021",
    "module": "commonjs",
    "lib": ["ES2021"],
    "moduleResolution": "node",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "outDir": "./dist",
    "rootDir": "./src",
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["src/**/*.ts"],
  "exclude": ["node_modules", "dist"]
}'

# --- backend/src/api/store/custom/route.ts ---
write_file "backend/src/api/store/custom/route.ts" 'import type { MedusaRequest, MedusaResponse } from "@medusajs/framework/http";

export async function GET(req: MedusaRequest, res: MedusaResponse) {
  res.json({
    message: "Hello from custom API route!",
  });
}'

# --- backend/src/api/middlewares.ts ---
write_file "backend/src/api/middlewares.ts" 'import { defineMiddlewares } from "@medusajs/medusa";

export default defineMiddlewares({
  routes: [
    // Add custom middleware configurations here
    // {
    //   matcher: "/store/custom",
    //   middlewares: [authenticate("customer", ["bearer", "session"])],
    // },
  ],
});'

# --- backend/src/modules/README.md ---
write_file "backend/src/modules/.gitkeep" ''

# --- backend/src/workflows/create-greeting.ts ---
write_file "backend/src/workflows/create-greeting.ts" 'import {
  createWorkflow,
  createStep,
  StepResponse,
  WorkflowResponse,
} from "@medusajs/framework/workflows-sdk";

type GreetingInput = {
  name: string;
};

const createGreetingStep = createStep(
  "create-greeting-step",
  async (input: GreetingInput) => {
    const greeting = `Hello, ${input.name}! Welcome to our store.`;
    return new StepResponse(greeting);
  }
);

export const createGreetingWorkflow = createWorkflow(
  "create-greeting",
  (input: GreetingInput) => {
    const greeting = createGreetingStep(input);
    return new WorkflowResponse(greeting);
  }
);'

# --- backend/src/scripts/seed.ts ---
write_file "backend/src/scripts/seed.ts" 'import { ExecArgs } from "@medusajs/framework/types";

export default async function seed({ container }: ExecArgs) {
  const logger = container.resolve("logger");
  logger.info("Seeding database...");

  // Add your seed logic here
  // Example: create regions, products, etc.

  logger.info("Seeding complete!");
}'

# --- backend/.env.example ---
write_file "backend/.env.example" '# Database
DATABASE_URL=postgresql://medusa:medusa@localhost:5432/medusa

# Redis
REDIS_URL=redis://localhost:6379

# Auth
JWT_SECRET=supersecret-change-in-production
COOKIE_SECRET=supersecret-change-in-production

# CORS
STORE_CORS=http://localhost:8000
ADMIN_CORS=http://localhost:9000
AUTH_CORS=http://localhost:8000,http://localhost:9000

# Backend URL
MEDUSA_BACKEND_URL=http://localhost:9000'

# ========== STOREFRONT ==========

# --- storefront/package.json ---
write_file "storefront/package.json" '{
  "name": "'"$PROJECT_NAME"'-storefront",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "next dev -p 8000 --turbopack",
    "build": "next build",
    "start": "next start -p 8000",
    "lint": "next lint"
  },
  "dependencies": {
    "next": "^15.3.0",
    "react": "^19.1.0",
    "react-dom": "^19.1.0"
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

# --- storefront/next.config.ts ---
write_file "storefront/next.config.ts" 'import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  images: {
    remotePatterns: [
      {
        protocol: "http",
        hostname: "localhost",
        port: "9000",
      },
    ],
  },
};

export default nextConfig;'

# --- storefront/tsconfig.json ---
write_file "storefront/tsconfig.json" '{
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
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}'

# --- storefront/postcss.config.mjs ---
write_file "storefront/postcss.config.mjs" 'const config = {
  plugins: {
    "@tailwindcss/postcss": {},
  },
};

export default config;'

# --- storefront/src/lib/medusa.ts ---
write_file "storefront/src/lib/medusa.ts" 'const MEDUSA_BACKEND_URL = process.env.NEXT_PUBLIC_MEDUSA_BACKEND_URL || "http://localhost:9000";

export async function medusaRequest(path: string, options?: RequestInit) {
  const url = `${MEDUSA_BACKEND_URL}${path}`;
  const response = await fetch(url, {
    ...options,
    headers: {
      "Content-Type": "application/json",
      "x-publishable-api-key": process.env.NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY || "",
      ...options?.headers,
    },
    next: { revalidate: 60 },
  });

  if (!response.ok) {
    throw new Error(`Medusa API error: ${response.status} ${response.statusText}`);
  }

  return response.json();
}

export async function getProducts(limit = 12, offset = 0) {
  return medusaRequest(`/store/products?limit=${limit}&offset=${offset}`);
}

export async function getProduct(handle: string) {
  const { products } = await medusaRequest(`/store/products?handle=${handle}`);
  return products[0] || null;
}'

# --- storefront/src/app/layout.tsx ---
write_file "storefront/src/app/layout.tsx" 'import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "'"$PROJECT_NAME"' Storefront",
  description: "Medusa.js powered storefront",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className="antialiased">
        <header className="border-b">
          <nav className="max-w-7xl mx-auto px-4 py-4 flex items-center justify-between">
            <a href="/" className="text-xl font-bold">'"$PROJECT_NAME"'</a>
            <div className="flex gap-6">
              <a href="/" className="hover:text-blue-600 transition-colors">Products</a>
              <a href="/cart" className="hover:text-blue-600 transition-colors">Cart</a>
            </div>
          </nav>
        </header>
        {children}
      </body>
    </html>
  );
}'

# --- storefront/src/app/globals.css ---
write_file "storefront/src/app/globals.css" '@import "tailwindcss";'

# --- storefront/src/app/page.tsx ---
write_file "storefront/src/app/page.tsx" 'import { getProducts } from "@/lib/medusa";
import Link from "next/link";

type Product = {
  id: string;
  title: string;
  handle: string;
  description: string;
  thumbnail: string | null;
  variants: Array<{
    calculated_price: {
      calculated_amount: number;
      currency_code: string;
    };
  }>;
};

export default async function Home() {
  let products: Product[] = [];

  try {
    const data = await getProducts();
    products = data.products || [];
  } catch {
    // Medusa backend may not be running yet
  }

  return (
    <main className="max-w-7xl mx-auto px-4 py-8">
      <h1 className="text-3xl font-bold mb-8">Products</h1>
      {products.length === 0 ? (
        <div className="text-center py-12">
          <p className="text-gray-500 text-lg">No products found.</p>
          <p className="text-gray-400 mt-2">
            Make sure the Medusa backend is running and has products seeded.
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
          {products.map((product) => (
            <Link
              key={product.id}
              href={`/products/${product.handle}`}
              className="group border rounded-lg overflow-hidden hover:shadow-lg transition-shadow"
            >
              <div className="aspect-square bg-gray-100">
                {product.thumbnail && (
                  <img
                    src={product.thumbnail}
                    alt={product.title}
                    className="w-full h-full object-cover group-hover:scale-105 transition-transform"
                  />
                )}
              </div>
              <div className="p-4">
                <h2 className="font-semibold">{product.title}</h2>
                <p className="text-gray-500 text-sm mt-1 line-clamp-2">
                  {product.description}
                </p>
              </div>
            </Link>
          ))}
        </div>
      )}
    </main>
  );
}'

# --- storefront/src/app/products/[handle]/page.tsx ---
write_file "storefront/src/app/products/[handle]/page.tsx" 'import { getProduct, getProducts } from "@/lib/medusa";
import { notFound } from "next/navigation";

type Props = {
  params: Promise<{ handle: string }>;
};

export async function generateStaticParams() {
  try {
    const { products } = await getProducts(100);
    return (products || []).map((p: { handle: string }) => ({ handle: p.handle }));
  } catch {
    return [];
  }
}

export default async function ProductPage({ params }: Props) {
  const { handle } = await params;
  let product;

  try {
    product = await getProduct(handle);
  } catch {
    notFound();
  }

  if (!product) notFound();

  return (
    <main className="max-w-7xl mx-auto px-4 py-8">
      <div className="grid md:grid-cols-2 gap-8">
        <div className="aspect-square bg-gray-100 rounded-lg overflow-hidden">
          {product.thumbnail && (
            <img
              src={product.thumbnail}
              alt={product.title}
              className="w-full h-full object-cover"
            />
          )}
        </div>
        <div>
          <h1 className="text-3xl font-bold">{product.title}</h1>
          <p className="text-gray-600 mt-4">{product.description}</p>
          <div className="mt-8">
            <h3 className="font-semibold mb-2">Variants</h3>
            <div className="flex flex-wrap gap-2">
              {product.variants?.map((variant: { id: string; title: string }) => (
                <button
                  key={variant.id}
                  className="border rounded px-4 py-2 hover:border-blue-500 transition-colors"
                >
                  {variant.title}
                </button>
              ))}
            </div>
          </div>
          <button className="mt-8 w-full bg-blue-600 text-white py-3 rounded-lg hover:bg-blue-700 transition-colors font-medium">
            Add to Cart
          </button>
        </div>
      </div>
    </main>
  );
}'

# --- storefront/next-env.d.ts ---
write_file "storefront/next-env.d.ts" '/// <reference types="next" />
/// <reference types="next/image-types/global" />'

# --- storefront/.env.example ---
write_file "storefront/.env.example" 'NEXT_PUBLIC_MEDUSA_BACKEND_URL=http://localhost:9000
NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY=your-publishable-key'

# --- docker-compose.yml ---
write_file "docker-compose.yml" 'services:
  postgres:
    image: postgres:17-alpine
    restart: unless-stopped
    ports:
      - "5432:5432"
    environment:
      POSTGRES_USER: medusa
      POSTGRES_PASSWORD: medusa
      POSTGRES_DB: medusa
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    ports:
      - "6379:6379"

volumes:
  postgres_data:'

# --- .env.example ---
write_file ".env.example" '# See backend/.env.example and storefront/.env.example for per-package env vars'

mkdir -p storefront/public

init_git
write_gitignore
write_editorconfig
write_nvmrc

finish "npm install" "npm run --workspace=backend dev"
