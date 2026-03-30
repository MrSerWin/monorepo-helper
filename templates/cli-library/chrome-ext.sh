#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-chrome-extension" "$@"
create_project_dir

# --- package.json ---
write_package_json '{
  "name": "'"$PROJECT_NAME"'",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc -b && vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^19.1.0",
    "react-dom": "^19.1.0"
  },
  "devDependencies": {
    "@crxjs/vite-plugin": "^2.0.0-beta.30",
    "@tailwindcss/vite": "^4.1.3",
    "@types/chrome": "^0.0.304",
    "@types/react": "^19.1.0",
    "@types/react-dom": "^19.1.0",
    "@vitejs/plugin-react": "^4.4.1",
    "tailwindcss": "^4.1.3",
    "typescript": "^5.8.3",
    "vite": "^6.3.0"
  }
}'

# --- manifest.json ---
write_file "manifest.json" '{
  "manifest_version": 3,
  "name": "'"$PROJECT_NAME"'",
  "version": "0.1.0",
  "description": "A Chrome extension built with React, Vite, and CRXJS",
  "permissions": ["storage", "activeTab"],
  "action": {
    "default_popup": "src/popup/index.html",
    "default_title": "'"$PROJECT_NAME"'"
  },
  "background": {
    "service_worker": "src/background/index.ts",
    "type": "module"
  },
  "content_scripts": [
    {
      "matches": ["<all_urls>"],
      "js": ["src/content/index.tsx"]
    }
  ],
  "icons": {
    "16": "public/icon-16.png",
    "48": "public/icon-48.png",
    "128": "public/icon-128.png"
  }
}'

# --- vite.config.ts ---
write_file "vite.config.ts" 'import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import crx from "@crxjs/vite-plugin";
import manifest from "./manifest.json";

export default defineConfig({
  plugins: [
    react(),
    tailwindcss(),
    crx({ manifest }),
  ],
});'

# --- tsconfig.json ---
write_tsconfig '{
  "compilerOptions": {
    "target": "ES2020",
    "useDefineForClassFields": true,
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "isolatedModules": true,
    "moduleDetection": "force",
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true,
    "resolveJsonModule": true
  },
  "include": ["src"]
}'

# --- src/popup/index.html ---
write_file "src/popup/index.html" '<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>'"$PROJECT_NAME"'</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="./main.tsx"></script>
  </body>
</html>'

# --- src/popup/main.tsx ---
write_file "src/popup/main.tsx" 'import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import "../index.css";
import Popup from "./Popup";

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <Popup />
  </StrictMode>
);'

# --- src/popup/Popup.tsx ---
write_file "src/popup/Popup.tsx" 'import { useState, useEffect } from "react";

function Popup() {
  const [count, setCount] = useState(0);

  useEffect(() => {
    // Load saved count from storage
    chrome.storage.local.get(["count"], (result) => {
      if (result.count !== undefined) {
        setCount(result.count);
      }
    });
  }, []);

  const increment = () => {
    const newCount = count + 1;
    setCount(newCount);
    chrome.storage.local.set({ count: newCount });
  };

  return (
    <div className="w-80 p-6 bg-white">
      <h1 className="text-xl font-bold text-gray-900 mb-4">
        '"$PROJECT_NAME"'
      </h1>
      <div className="space-y-3">
        <button
          onClick={increment}
          className="w-full bg-blue-600 text-white px-4 py-2 rounded-lg font-medium hover:bg-blue-700 transition-colors cursor-pointer"
        >
          Count: {count}
        </button>
        <p className="text-gray-500 text-sm">
          Click the button to increment. The count is saved to extension storage.
        </p>
      </div>
    </div>
  );
}

export default Popup;'

# --- src/index.css ---
write_file "src/index.css" '@import "tailwindcss";'

# --- src/background/index.ts ---
write_file "src/background/index.ts" '// Background service worker
chrome.runtime.onInstalled.addListener((details) => {
  if (details.reason === "install") {
    console.log("Extension installed");
    chrome.storage.local.set({ count: 0 });
  }
});

// Example: listen for messages from content scripts
chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (message.type === "GET_COUNT") {
    chrome.storage.local.get(["count"], (result) => {
      sendResponse({ count: result.count ?? 0 });
    });
    return true; // Keep the message channel open for async response
  }
});'

# --- src/content/index.tsx ---
write_file "src/content/index.tsx" '// Content script - runs on web pages
// This script has access to the DOM of the page

console.log("['"$PROJECT_NAME"'] Content script loaded");

// Example: send a message to the background script
chrome.runtime.sendMessage({ type: "GET_COUNT" }, (response) => {
  if (response) {
    console.log("['"$PROJECT_NAME"'] Current count:", response.count);
  }
});'

# --- src/vite-env.d.ts ---
write_file "src/vite-env.d.ts" '/// <reference types="vite/client" />
/// <reference types="@crxjs/vite-plugin/client" />'

mkdir -p public

init_git
write_gitignore
write_editorconfig
write_nvmrc

finish "npm install" "npm run dev"
