#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-hydrogen-store" "$@"
create_project_dir

# --- package.json ---
write_package_json '{
  "name": "'"$PROJECT_NAME"'",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "sideEffects": false,
  "scripts": {
    "dev": "shopify hydrogen dev --codegen",
    "build": "shopify hydrogen build --codegen",
    "preview": "npm run build && shopify hydrogen preview",
    "lint": "eslint --no-error-on-unmatched-pattern --ext .js,.ts,.tsx .",
    "typecheck": "tsc --noEmit",
    "codegen": "shopify hydrogen codegen"
  },
  "dependencies": {
    "@remix-run/react": "^2.16.0",
    "@remix-run/server-runtime": "^2.16.0",
    "@shopify/hydrogen": "^2025.1.0",
    "@shopify/remix-oxygen": "^2.0.10",
    "graphql": "^16.10.0",
    "graphql-tag": "^2.12.6",
    "isbot": "^5.1.0",
    "react": "^19.1.0",
    "react-dom": "^19.1.0"
  },
  "devDependencies": {
    "@remix-run/dev": "^2.16.0",
    "@shopify/hydrogen-codegen": "^0.3.0",
    "@shopify/cli": "^3.73.0",
    "@shopify/cli-hydrogen": "^9.4.0",
    "@tailwindcss/vite": "^4.1.3",
    "@types/react": "^19.1.0",
    "@types/react-dom": "^19.1.0",
    "tailwindcss": "^4.1.3",
    "typescript": "^5.8.3",
    "vite": "^6.2.0"
  }
}'

# --- tsconfig.json ---
write_tsconfig '{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["DOM", "DOM.Iterable", "ES2022"],
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "jsx": "react-jsx",
    "skipLibCheck": true,
    "esModuleInterop": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "paths": {
      "~/*": ["./app/*"]
    },
    "types": ["@shopify/hydrogen/storefront.d.ts"]
  },
  "include": ["**/*.ts", "**/*.tsx", "env.d.ts"],
  "exclude": ["node_modules"]
}'

# --- vite.config.ts ---
write_file "vite.config.ts" 'import { defineConfig } from "vite";
import { hydrogen } from "@shopify/hydrogen/vite";
import { oxygen } from "@shopify/mini-oxygen/vite";
import { vitePlugin as remix } from "@remix-run/dev";
import tailwindcss from "@tailwindcss/vite";

export default defineConfig({
  plugins: [
    tailwindcss(),
    hydrogen(),
    oxygen(),
    remix({
      presets: [hydrogen.preset()],
      future: {
        v3_fetcherPersist: true,
        v3_relativeSplatPath: true,
        v3_throwAbortReason: true,
        v3_lazyRouteDiscovery: true,
        v3_singleFetch: true,
      },
    }),
  ],
});'

# --- env.d.ts ---
write_file "env.d.ts" '/// <reference types="vite/client" />
/// <reference types="@shopify/remix-oxygen" />
/// <reference types="@shopify/hydrogen/storefront.d.ts" />

import type { HydrogenCart, HydrogenSessionData } from "@shopify/hydrogen";
import type { Storefront, CustomerAccount } from "@shopify/hydrogen";

declare module "@shopify/remix-oxygen" {
  export interface AppLoadContext {
    env: Env;
    cart: HydrogenCart;
    storefront: Storefront;
    customerAccount: CustomerAccount;
    waitUntil: ExecutionContext["waitUntil"];
  }

  interface SessionData extends HydrogenSessionData {}
}

interface Env {
  SESSION_SECRET: string;
  PUBLIC_STOREFRONT_API_TOKEN: string;
  PUBLIC_STORE_DOMAIN: string;
  PRIVATE_STOREFRONT_API_TOKEN: string;
  PUBLIC_STOREFRONT_ID: string;
  PUBLIC_CUSTOMER_ACCOUNT_API_CLIENT_ID: string;
  PUBLIC_CUSTOMER_ACCOUNT_API_URL: string;
}'

# --- app/root.tsx ---
write_file "app/root.tsx" 'import {
  Links,
  Meta,
  Outlet,
  Scripts,
  ScrollRestoration,
  useRouteError,
  isRouteErrorResponse,
  type MetaFunction,
} from "@remix-run/react";
import type { LinksFunction, LoaderFunctionArgs } from "@shopify/remix-oxygen";
import "./styles/app.css";

export const meta: MetaFunction = () => {
  return [{ title: "'"$PROJECT_NAME"'" }];
};

export const links: LinksFunction = () => {
  return [];
};

export async function loader({ context }: LoaderFunctionArgs) {
  const { storefront, cart } = context;
  return {
    publicStoreDomain: context.env.PUBLIC_STORE_DOMAIN,
    cart: cart.get(),
  };
}

export default function App() {
  return (
    <html lang="en">
      <head>
        <meta charSet="utf-8" />
        <meta name="viewport" content="width=device-width,initial-scale=1" />
        <Meta />
        <Links />
      </head>
      <body>
        <Layout>
          <Outlet />
        </Layout>
        <ScrollRestoration />
        <Scripts />
      </body>
    </html>
  );
}

function Layout({ children }: { children: React.ReactNode }) {
  return (
    <div className="min-h-screen flex flex-col">
      <Header />
      <main className="flex-1">{children}</main>
      <Footer />
    </div>
  );
}

function Header() {
  return (
    <header className="border-b">
      <nav className="max-w-7xl mx-auto px-4 py-4 flex items-center justify-between">
        <a href="/" className="text-xl font-bold">'"$PROJECT_NAME"'</a>
        <div className="flex items-center gap-6">
          <a href="/collections" className="hover:text-blue-600 transition-colors">
            Collections
          </a>
          <a href="/cart" className="hover:text-blue-600 transition-colors">
            Cart
          </a>
        </div>
      </nav>
    </header>
  );
}

function Footer() {
  return (
    <footer className="border-t py-8 text-center text-gray-500 text-sm">
      <p>Powered by Shopify Hydrogen</p>
    </footer>
  );
}

export function ErrorBoundary() {
  const error = useRouteError();

  if (isRouteErrorResponse(error)) {
    return (
      <div className="p-8 text-center">
        <h1 className="text-2xl font-bold">{error.status}</h1>
        <p>{error.statusText}</p>
      </div>
    );
  }

  return (
    <div className="p-8 text-center">
      <h1 className="text-2xl font-bold">Something went wrong</h1>
      <p>{error instanceof Error ? error.message : "Unknown error"}</p>
    </div>
  );
}'

# --- app/styles/app.css ---
write_file "app/styles/app.css" '@import "tailwindcss";'

# --- app/entry.server.tsx ---
write_file "app/entry.server.tsx" 'import { RemixServer } from "@remix-run/react";
import { isbot } from "isbot";
import { renderToReadableStream } from "react-dom/server";
import type { EntryContext, AppLoadContext } from "@shopify/remix-oxygen";

export default async function handleRequest(
  request: Request,
  responseStatusCode: number,
  responseHeaders: Headers,
  remixContext: EntryContext,
  context: AppLoadContext,
) {
  const body = await renderToReadableStream(
    <RemixServer context={remixContext} url={request.url} />,
    {
      signal: request.signal,
      onError(error) {
        console.error(error);
        responseStatusCode = 500;
      },
    },
  );

  if (isbot(request.headers.get("user-agent"))) {
    await body.allReady;
  }

  responseHeaders.set("Content-Type", "text/html");

  return new Response(body, {
    headers: responseHeaders,
    status: responseStatusCode,
  });
}'

# --- app/routes/_index.tsx ---
write_file "app/routes/_index.tsx" 'import { useLoaderData, Link } from "@remix-run/react";
import type { LoaderFunctionArgs } from "@shopify/remix-oxygen";

export async function loader({ context }: LoaderFunctionArgs) {
  const { storefront } = context;

  const { products } = await storefront.query(FEATURED_PRODUCTS_QUERY);

  return { products };
}

export default function Index() {
  const { products } = useLoaderData<typeof loader>();

  return (
    <div className="max-w-7xl mx-auto px-4 py-8">
      <section className="text-center py-16">
        <h1 className="text-4xl font-bold tracking-tight sm:text-6xl">
          Welcome to our Store
        </h1>
        <p className="mt-4 text-lg text-gray-600 max-w-2xl mx-auto">
          Discover our curated collection of products
        </p>
      </section>

      <section>
        <h2 className="text-2xl font-bold mb-6">Featured Products</h2>
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
          {products.nodes.map((product: any) => (
            <Link
              key={product.id}
              to={`/products/${product.handle}`}
              className="group border rounded-lg overflow-hidden hover:shadow-lg transition-shadow"
            >
              {product.featuredImage && (
                <div className="aspect-square overflow-hidden">
                  <img
                    src={product.featuredImage.url}
                    alt={product.featuredImage.altText || product.title}
                    className="w-full h-full object-cover group-hover:scale-105 transition-transform"
                  />
                </div>
              )}
              <div className="p-4">
                <h3 className="font-semibold">{product.title}</h3>
                <p className="text-gray-600 mt-1">
                  {product.priceRange.minVariantPrice.amount}{" "}
                  {product.priceRange.minVariantPrice.currencyCode}
                </p>
              </div>
            </Link>
          ))}
        </div>
      </section>
    </div>
  );
}

const FEATURED_PRODUCTS_QUERY = `#graphql
  query FeaturedProducts {
    products(first: 8, sortKey: BEST_SELLING) {
      nodes {
        id
        title
        handle
        featuredImage {
          url
          altText
        }
        priceRange {
          minVariantPrice {
            amount
            currencyCode
          }
        }
      }
    }
  }
`;'

# --- app/routes/products.$handle.tsx ---
write_file "app/routes/products.\$handle.tsx" 'import { useLoaderData } from "@remix-run/react";
import type { LoaderFunctionArgs } from "@shopify/remix-oxygen";

export async function loader({ params, context }: LoaderFunctionArgs) {
  const { handle } = params;
  const { storefront } = context;

  const { product } = await storefront.query(PRODUCT_QUERY, {
    variables: { handle },
  });

  if (!product) {
    throw new Response("Product not found", { status: 404 });
  }

  return { product };
}

export default function ProductPage() {
  const { product } = useLoaderData<typeof loader>();

  return (
    <div className="max-w-7xl mx-auto px-4 py-8">
      <div className="grid md:grid-cols-2 gap-8">
        <div className="aspect-square bg-gray-100 rounded-lg overflow-hidden">
          {product.featuredImage && (
            <img
              src={product.featuredImage.url}
              alt={product.featuredImage.altText || product.title}
              className="w-full h-full object-cover"
            />
          )}
        </div>
        <div>
          <h1 className="text-3xl font-bold">{product.title}</h1>
          <p className="text-2xl mt-4">
            {product.priceRange.minVariantPrice.amount}{" "}
            {product.priceRange.minVariantPrice.currencyCode}
          </p>
          <div
            className="mt-4 text-gray-600 prose"
            dangerouslySetInnerHTML={{ __html: product.descriptionHtml }}
          />
          <div className="mt-6 flex flex-wrap gap-2">
            {product.variants.nodes.map((variant: any) => (
              <button
                key={variant.id}
                className="border rounded px-4 py-2 hover:border-blue-500 transition-colors"
              >
                {variant.title}
              </button>
            ))}
          </div>
          <button className="mt-8 w-full bg-blue-600 text-white py-3 rounded-lg hover:bg-blue-700 transition-colors font-medium">
            Add to Cart
          </button>
        </div>
      </div>
    </div>
  );
}

const PRODUCT_QUERY = `#graphql
  query Product($handle: String!) {
    product(handle: $handle) {
      id
      title
      handle
      descriptionHtml
      featuredImage {
        url
        altText
      }
      priceRange {
        minVariantPrice {
          amount
          currencyCode
        }
      }
      variants(first: 100) {
        nodes {
          id
          title
          availableForSale
          price {
            amount
            currencyCode
          }
        }
      }
    }
  }
`;'

# --- app/routes/cart.tsx ---
write_file "app/routes/cart.tsx" 'import type { LoaderFunctionArgs, ActionFunctionArgs } from "@shopify/remix-oxygen";
import { useLoaderData } from "@remix-run/react";

export async function loader({ context }: LoaderFunctionArgs) {
  const cart = await context.cart.get();
  return { cart };
}

export default function CartPage() {
  const { cart } = useLoaderData<typeof loader>();

  return (
    <div className="max-w-4xl mx-auto px-4 py-8">
      <h1 className="text-3xl font-bold mb-8">Your Cart</h1>
      {!cart || !cart.lines?.nodes?.length ? (
        <div className="text-center py-12">
          <p className="text-gray-500 text-lg">Your cart is empty</p>
          <a
            href="/"
            className="inline-block mt-4 bg-blue-600 text-white px-6 py-3 rounded-lg hover:bg-blue-700 transition-colors"
          >
            Continue Shopping
          </a>
        </div>
      ) : (
        <div>
          <ul className="divide-y">
            {cart.lines.nodes.map((line: any) => (
              <li key={line.id} className="py-4 flex items-center gap-4">
                {line.merchandise.image && (
                  <img
                    src={line.merchandise.image.url}
                    alt={line.merchandise.image.altText || ""}
                    className="w-20 h-20 object-cover rounded"
                  />
                )}
                <div className="flex-1">
                  <h3 className="font-semibold">{line.merchandise.product.title}</h3>
                  <p className="text-gray-500">{line.merchandise.title}</p>
                  <p className="text-sm">Qty: {line.quantity}</p>
                </div>
                <p className="font-medium">
                  {line.cost.totalAmount.amount} {line.cost.totalAmount.currencyCode}
                </p>
              </li>
            ))}
          </ul>
          <div className="mt-8 border-t pt-4 text-right">
            <p className="text-xl font-bold">
              Total: {cart.cost.totalAmount.amount} {cart.cost.totalAmount.currencyCode}
            </p>
            <a
              href={cart.checkoutUrl}
              className="inline-block mt-4 bg-blue-600 text-white px-8 py-3 rounded-lg hover:bg-blue-700 transition-colors font-medium"
            >
              Checkout
            </a>
          </div>
        </div>
      )}
    </div>
  );
}'

# --- app/components/ProductCard.tsx ---
write_file "app/components/ProductCard.tsx" 'import { Link } from "@remix-run/react";

type ProductCardProps = {
  product: {
    id: string;
    title: string;
    handle: string;
    featuredImage?: {
      url: string;
      altText?: string;
    };
    priceRange: {
      minVariantPrice: {
        amount: string;
        currencyCode: string;
      };
    };
  };
};

export function ProductCard({ product }: ProductCardProps) {
  return (
    <Link
      to={`/products/${product.handle}`}
      className="group border rounded-lg overflow-hidden hover:shadow-lg transition-shadow"
    >
      {product.featuredImage && (
        <div className="aspect-square overflow-hidden">
          <img
            src={product.featuredImage.url}
            alt={product.featuredImage.altText || product.title}
            className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
          />
        </div>
      )}
      <div className="p-4">
        <h3 className="font-semibold truncate">{product.title}</h3>
        <p className="text-gray-600 mt-1">
          {product.priceRange.minVariantPrice.amount}{" "}
          {product.priceRange.minVariantPrice.currencyCode}
        </p>
      </div>
    </Link>
  );
}'

# --- .env.example ---
write_file ".env.example" '# Shopify Storefront API
SESSION_SECRET="foobar"
PUBLIC_STOREFRONT_API_TOKEN="your-public-storefront-api-token"
PUBLIC_STORE_DOMAIN="your-store.myshopify.com"
PRIVATE_STOREFRONT_API_TOKEN="your-private-storefront-api-token"
PUBLIC_STOREFRONT_ID=""
PUBLIC_CUSTOMER_ACCOUNT_API_CLIENT_ID=""
PUBLIC_CUSTOMER_ACCOUNT_API_URL=""'

mkdir -p public

init_git
write_gitignore ".hydrogen/" ".shopify/"
write_editorconfig
write_nvmrc

finish "npm install" "npx shopify hydrogen dev"
