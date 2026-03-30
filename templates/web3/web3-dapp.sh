#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-web3-dapp" "$@"
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
    "@rainbow-me/rainbowkit": "^2.2.0",
    "@tanstack/react-query": "^5.68.0",
    "viem": "^2.23.0",
    "wagmi": "^2.14.0"
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

const nextConfig: NextConfig = {
  reactStrictMode: true,
  webpack: (config) => {
    config.resolve.fallback = { fs: false, net: false, tls: false };
    return config;
  },
};

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

# --- .env.example ---
write_file ".env.example" '# WalletConnect Project ID - get yours at https://cloud.walletconnect.com
NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID=your_project_id_here

# Alchemy/Infura RPC URL (optional - uses public RPC by default)
NEXT_PUBLIC_ALCHEMY_ID=your_alchemy_id_here'

# --- src/config/wagmi.ts ---
write_file "src/config/wagmi.ts" 'import { getDefaultConfig } from "@rainbow-me/rainbowkit";
import { mainnet, sepolia, polygon, optimism, arbitrum } from "wagmi/chains";

export const config = getDefaultConfig({
  appName: "'"$PROJECT_NAME"'",
  projectId: process.env.NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID || "",
  chains: [mainnet, sepolia, polygon, optimism, arbitrum],
  ssr: true,
});'

# --- src/providers/Web3Provider.tsx ---
write_file "src/providers/Web3Provider.tsx" '"use client";

import { RainbowKitProvider, darkTheme } from "@rainbow-me/rainbowkit";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { WagmiProvider } from "wagmi";
import { config } from "@/config/wagmi";
import "@rainbow-me/rainbowkit/styles.css";

const queryClient = new QueryClient();

export function Web3Provider({ children }: { children: React.ReactNode }) {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <RainbowKitProvider theme={darkTheme()}>
          {children}
        </RainbowKitProvider>
      </QueryClientProvider>
    </WagmiProvider>
  );
}'

# --- src/hooks/useContractRead.ts ---
write_file "src/hooks/useContractRead.ts" '"use client";

import { useReadContract } from "wagmi";
import type { Abi, Address } from "viem";

/**
 * Generic hook for reading from a smart contract.
 *
 * Usage:
 * ```ts
 * const { data, isLoading } = useContractRead({
 *   address: "0x...",
 *   abi: myContractAbi,
 *   functionName: "balanceOf",
 *   args: [userAddress],
 * });
 * ```
 */
export function useContractRead<TAbi extends Abi>({
  address,
  abi,
  functionName,
  args = [],
}: {
  address: Address;
  abi: TAbi;
  functionName: string;
  args?: unknown[];
}) {
  return useReadContract({
    address,
    abi,
    functionName,
    args,
  });
}'

# --- src/hooks/useContractWrite.ts ---
write_file "src/hooks/useContractWrite.ts" '"use client";

import { useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import type { Abi, Address } from "viem";

/**
 * Generic hook for writing to a smart contract.
 *
 * Usage:
 * ```ts
 * const { write, isLoading, isSuccess } = useContractWrite({
 *   address: "0x...",
 *   abi: myContractAbi,
 *   functionName: "transfer",
 * });
 *
 * write({ args: [toAddress, amount] });
 * ```
 */
export function useContractWrite<TAbi extends Abi>({
  address,
  abi,
  functionName,
}: {
  address: Address;
  abi: TAbi;
  functionName: string;
}) {
  const { data: hash, writeContract, isPending } = useWriteContract();

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  });

  const write = ({ args = [] }: { args?: unknown[] } = {}) => {
    writeContract({
      address,
      abi,
      functionName,
      args,
    });
  };

  return {
    write,
    hash,
    isLoading: isPending || isConfirming,
    isSuccess,
  };
}'

# --- src/app/layout.tsx ---
write_file "src/app/layout.tsx" 'import type { Metadata } from "next";
import { Web3Provider } from "@/providers/Web3Provider";
import "./globals.css";

export const metadata: Metadata = {
  title: "'"$PROJECT_NAME"'",
  description: "Web3 dApp built with Next.js, wagmi, and RainbowKit",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className="min-h-screen bg-gray-950 text-white antialiased">
        <Web3Provider>{children}</Web3Provider>
      </body>
    </html>
  );
}'

# --- src/app/globals.css ---
write_file "src/app/globals.css" '@import "tailwindcss";'

# --- src/app/page.tsx ---
write_file "src/app/page.tsx" '"use client";

import { ConnectButton } from "@rainbow-me/rainbowkit";
import { useAccount, useBalance } from "wagmi";

export default function Home() {
  const { address, isConnected } = useAccount();
  const { data: balance } = useBalance({ address });

  return (
    <div className="flex min-h-screen flex-col">
      <header className="flex items-center justify-between border-b border-gray-800 px-6 py-4">
        <h1 className="text-xl font-bold">'"$PROJECT_NAME"'</h1>
        <ConnectButton />
      </header>

      <main className="flex flex-1 flex-col items-center justify-center gap-8 p-8">
        <div className="text-center">
          <h2 className="text-5xl font-bold tracking-tight">
            Web3 <span className="text-blue-500">dApp</span>
          </h2>
          <p className="mt-4 text-lg text-gray-400">
            Built with Next.js, wagmi, viem, and RainbowKit
          </p>
        </div>

        {isConnected && address ? (
          <div className="w-full max-w-md rounded-xl border border-gray-800 bg-gray-900 p-6">
            <h3 className="mb-4 text-lg font-semibold">Wallet Info</h3>
            <div className="space-y-3">
              <div>
                <p className="text-sm text-gray-400">Address</p>
                <p className="font-mono text-sm">
                  {address.slice(0, 6)}...{address.slice(-4)}
                </p>
              </div>
              {balance && (
                <div>
                  <p className="text-sm text-gray-400">Balance</p>
                  <p className="font-mono text-sm">
                    {parseFloat(balance.formatted).toFixed(4)} {balance.symbol}
                  </p>
                </div>
              )}
            </div>
          </div>
        ) : (
          <div className="rounded-xl border border-gray-800 bg-gray-900 p-8 text-center">
            <p className="text-gray-400">Connect your wallet to get started</p>
          </div>
        )}
      </main>

      <footer className="border-t border-gray-800 px-6 py-4 text-center text-sm text-gray-500">
        Built with Next.js + wagmi + RainbowKit
      </footer>
    </div>
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
