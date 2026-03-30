#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-electron-app" "$@"
create_project_dir

# --- package.json ---
write_package_json '{
  "name": "'"$PROJECT_NAME"'",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "main": "dist-electron/main.js",
  "scripts": {
    "dev": "vite",
    "build": "tsc -b && vite build && electron-builder",
    "preview": "vite preview",
    "lint": "eslint ."
  },
  "dependencies": {
    "react": "^19.1.0",
    "react-dom": "^19.1.0"
  },
  "devDependencies": {
    "@tailwindcss/vite": "^4.1.3",
    "@types/react": "^19.1.0",
    "@types/react-dom": "^19.1.0",
    "@vitejs/plugin-react": "^4.4.1",
    "electron": "^34.2.0",
    "electron-builder": "^25.1.8",
    "tailwindcss": "^4.1.3",
    "typescript": "^5.8.3",
    "vite": "^6.3.0",
    "vite-plugin-electron": "^0.29.0",
    "vite-plugin-electron-renderer": "^0.14.6"
  },
  "build": {
    "appId": "com.electron.'"$PROJECT_NAME"'",
    "productName": "'"$PROJECT_NAME"'",
    "files": [
      "dist/**/*",
      "dist-electron/**/*"
    ],
    "directories": {
      "output": "release"
    }
  }
}'

# --- vite.config.ts ---
write_file "vite.config.ts" 'import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import electron from "vite-plugin-electron";
import renderer from "vite-plugin-electron-renderer";

export default defineConfig({
  plugins: [
    react(),
    tailwindcss(),
    electron([
      {
        entry: "electron/main.ts",
        vite: {
          build: {
            outDir: "dist-electron",
            rollupOptions: {
              external: ["electron"],
            },
          },
        },
      },
      {
        entry: "electron/preload.ts",
        onstart({ reload }) {
          reload();
        },
        vite: {
          build: {
            outDir: "dist-electron",
            rollupOptions: {
              external: ["electron"],
            },
          },
        },
      },
    ]),
    renderer(),
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
    "noFallthroughCasesInSwitch": true
  },
  "include": ["src", "electron"]
}'

# --- electron/main.ts ---
write_file "electron/main.ts" 'import { app, BrowserWindow, ipcMain } from "electron";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

process.env.APP_ROOT = path.join(__dirname, "..");
const VITE_DEV_SERVER_URL = process.env["VITE_DEV_SERVER_URL"];
const RENDERER_DIST = path.join(process.env.APP_ROOT, "dist");

function createWindow() {
  const win = new BrowserWindow({
    width: 1024,
    height: 768,
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  // IPC example: handle "get-app-info" from renderer
  ipcMain.handle("get-app-info", () => ({
    name: app.getName(),
    version: app.getVersion(),
    electron: process.versions.electron,
    node: process.versions.node,
    chrome: process.versions.chrome,
  }));

  if (VITE_DEV_SERVER_URL) {
    win.loadURL(VITE_DEV_SERVER_URL);
  } else {
    win.loadFile(path.join(RENDERER_DIST, "index.html"));
  }
}

app.whenReady().then(createWindow);

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") {
    app.quit();
  }
});

app.on("activate", () => {
  if (BrowserWindow.getAllWindows().length === 0) {
    createWindow();
  }
});'

# --- electron/preload.ts ---
write_file "electron/preload.ts" 'import { contextBridge, ipcRenderer } from "electron";

contextBridge.exposeInMainWorld("electronAPI", {
  getAppInfo: () => ipcRenderer.invoke("get-app-info"),
});'

# --- src/main.tsx ---
write_file "src/main.tsx" 'import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import "./index.css";
import App from "./App";

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <App />
  </StrictMode>
);'

# --- src/index.css ---
write_file "src/index.css" '@import "tailwindcss";'

# --- src/App.tsx ---
write_file "src/App.tsx" 'import { useState, useEffect } from "react";

interface AppInfo {
  name: string;
  version: string;
  electron: string;
  node: string;
  chrome: string;
}

function App() {
  const [count, setCount] = useState(0);
  const [appInfo, setAppInfo] = useState<AppInfo | null>(null);

  useEffect(() => {
    window.electronAPI.getAppInfo().then(setAppInfo);
  }, []);

  return (
    <div className="min-h-screen flex flex-col items-center justify-center bg-gray-50">
      <div className="text-center space-y-6">
        <h1 className="text-5xl font-bold text-gray-900">
          Electron + React
        </h1>
        <div className="bg-white shadow rounded-xl p-8 space-y-4">
          <button
            onClick={() => setCount((c) => c + 1)}
            className="bg-blue-600 text-white px-6 py-3 rounded-lg font-medium hover:bg-blue-700 transition-colors cursor-pointer"
          >
            Count is {count}
          </button>
          {appInfo && (
            <div className="text-sm text-gray-500 space-y-1">
              <p>Electron {appInfo.electron} | Node {appInfo.node} | Chrome {appInfo.chrome}</p>
            </div>
          )}
          <p className="text-gray-500 text-sm">
            Edit <code className="bg-gray-100 px-2 py-1 rounded font-mono text-xs">src/App.tsx</code> and save to test HMR
          </p>
        </div>
      </div>
    </div>
  );
}

export default App;'

# --- src/electron.d.ts ---
write_file "src/electron.d.ts" 'export interface ElectronAPI {
  getAppInfo: () => Promise<{
    name: string;
    version: string;
    electron: string;
    node: string;
    chrome: string;
  }>;
}

declare global {
  interface Window {
    electronAPI: ElectronAPI;
  }
}'

# --- src/vite-env.d.ts ---
write_file "src/vite-env.d.ts" '/// <reference types="vite/client" />'

# --- index.html ---
write_file "index.html" '<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>'"$PROJECT_NAME"'</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>'

mkdir -p public

init_git
write_gitignore "dist-electron/" "release/"
write_editorconfig
write_nvmrc

finish "npm install" "npm run dev"
