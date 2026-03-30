#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-ionic-react-app" "$@"
create_project_dir

# --- package.json ---
write_package_json '{
  "name": "'"$PROJECT_NAME"'",
  "version": "0.0.1",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "preview": "vite preview",
    "lint": "eslint .",
    "ionic:serve": "vite"
  },
  "dependencies": {
    "@capacitor/app": "^6.0.0",
    "@capacitor/core": "^6.0.0",
    "@capacitor/haptics": "^6.0.0",
    "@capacitor/keyboard": "^6.0.0",
    "@capacitor/status-bar": "^6.0.0",
    "@ionic/react": "^8.4.0",
    "@ionic/react-router": "^8.4.0",
    "ionicons": "^7.4.0",
    "react": "^19.0.0",
    "react-dom": "^19.0.0",
    "react-router": "^6.28.0",
    "react-router-dom": "^6.28.0"
  },
  "devDependencies": {
    "@capacitor/cli": "^6.0.0",
    "@types/react": "^19.0.0",
    "@types/react-dom": "^19.0.0",
    "@vitejs/plugin-react": "^4.3.4",
    "typescript": "~5.7.0",
    "vite": "^6.0.0"
  }
}'

# --- ionic.config.json ---
write_file "ionic.config.json" '{
  "name": "'"$PROJECT_NAME"'",
  "integrations": {
    "capacitor": {}
  },
  "type": "react-vite"
}'

# --- capacitor.config.ts ---
write_file_heredoc "capacitor.config.ts" << EOF
import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.example.${PROJECT_NAME//[-]/.}',
  appName: '${PROJECT_NAME}',
  webDir: 'dist',
  server: {
    androidScheme: 'https'
  }
};

export default config;
EOF

# --- vite.config.ts ---
write_file_heredoc "vite.config.ts" << 'EOF'
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'path';

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
});
EOF

# --- tsconfig.json ---
write_tsconfig '{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
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
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["src"]
}'

# --- index.html ---
write_file_heredoc "index.html" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="viewport-fit=cover, width=device-width, initial-scale=1.0, minimum-scale=1.0, maximum-scale=1.0, user-scalable=no" />
  <meta name="color-scheme" content="light dark" />
  <title>${PROJECT_NAME}</title>
</head>
<body>
  <div id="root"></div>
  <script type="module" src="/src/main.tsx"></script>
</body>
</html>
EOF

# --- src/main.tsx ---
write_file_heredoc "src/main.tsx" << 'EOF'
import React from 'react';
import { createRoot } from 'react-dom/client';
import App from './App';

/* Core CSS required for Ionic components */
import '@ionic/react/css/core.css';
import '@ionic/react/css/normalize.css';
import '@ionic/react/css/structure.css';
import '@ionic/react/css/typography.css';

/* Optional CSS utils */
import '@ionic/react/css/padding.css';
import '@ionic/react/css/float-elements.css';
import '@ionic/react/css/text-alignment.css';
import '@ionic/react/css/text-transformation.css';
import '@ionic/react/css/flex-utils.css';
import '@ionic/react/css/display.css';

/* Theme */
import './theme/variables.css';

const container = document.getElementById('root');
const root = createRoot(container!);
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
EOF

# --- src/App.tsx ---
write_file_heredoc "src/App.tsx" << 'EOF'
import { IonApp, IonRouterOutlet, setupIonicReact } from '@ionic/react';
import { IonReactRouter } from '@ionic/react-router';
import { Route, Redirect } from 'react-router-dom';
import Home from './pages/Home';

setupIonicReact();

const App: React.FC = () => (
  <IonApp>
    <IonReactRouter>
      <IonRouterOutlet>
        <Route exact path="/home" component={Home} />
        <Route exact path="/">
          <Redirect to="/home" />
        </Route>
      </IonRouterOutlet>
    </IonReactRouter>
  </IonApp>
);

export default App;
EOF

# --- src/pages/Home.tsx ---
write_file_heredoc "src/pages/Home.tsx" << 'EOF'
import { useState } from 'react';
import {
  IonContent,
  IonHeader,
  IonPage,
  IonTitle,
  IonToolbar,
  IonList,
  IonItem,
  IonLabel,
  IonCheckbox,
  IonButton,
  IonIcon,
  IonFab,
  IonFabButton,
  IonAlert,
} from '@ionic/react';
import { add, trash } from 'ionicons/icons';

interface TodoItem {
  id: number;
  text: string;
  completed: boolean;
}

const Home: React.FC = () => {
  const [todos, setTodos] = useState<TodoItem[]>([
    { id: 1, text: 'Learn Ionic React', completed: false },
    { id: 2, text: 'Build a mobile app', completed: false },
    { id: 3, text: 'Ship to app stores', completed: false },
  ]);
  const [showAlert, setShowAlert] = useState(false);

  const toggleTodo = (id: number) => {
    setTodos((prev) =>
      prev.map((t) => (t.id === id ? { ...t, completed: !t.completed } : t))
    );
  };

  const deleteTodo = (id: number) => {
    setTodos((prev) => prev.filter((t) => t.id !== id));
  };

  const addTodo = (text: string) => {
    if (text.trim()) {
      setTodos((prev) => [
        ...prev,
        { id: Date.now(), text: text.trim(), completed: false },
      ]);
    }
  };

  return (
    <IonPage>
      <IonHeader>
        <IonToolbar>
          <IonTitle>Todo List</IonTitle>
        </IonToolbar>
      </IonHeader>
      <IonContent fullscreen>
        <IonHeader collapse="condense">
          <IonToolbar>
            <IonTitle size="large">Todo List</IonTitle>
          </IonToolbar>
        </IonHeader>

        <IonList>
          {todos.length === 0 ? (
            <IonItem>
              <IonLabel className="ion-text-center">
                <p>No todos yet. Tap + to add one!</p>
              </IonLabel>
            </IonItem>
          ) : (
            todos.map((todo) => (
              <IonItem key={todo.id}>
                <IonCheckbox
                  slot="start"
                  checked={todo.completed}
                  onIonChange={() => toggleTodo(todo.id)}
                />
                <IonLabel
                  style={{
                    textDecoration: todo.completed ? 'line-through' : 'none',
                  }}
                >
                  {todo.text}
                </IonLabel>
                <IonButton
                  fill="clear"
                  slot="end"
                  onClick={() => deleteTodo(todo.id)}
                >
                  <IonIcon icon={trash} slot="icon-only" />
                </IonButton>
              </IonItem>
            ))
          )}
        </IonList>

        <IonFab vertical="bottom" horizontal="end" slot="fixed">
          <IonFabButton onClick={() => setShowAlert(true)}>
            <IonIcon icon={add} />
          </IonFabButton>
        </IonFab>

        <IonAlert
          isOpen={showAlert}
          onDidDismiss={() => setShowAlert(false)}
          header="New Todo"
          inputs={[
            {
              name: 'text',
              type: 'text',
              placeholder: 'What needs to be done?',
            },
          ]}
          buttons={[
            { text: 'Cancel', role: 'cancel' },
            {
              text: 'Add',
              handler: (data: { text: string }) => addTodo(data.text),
            },
          ]}
        />
      </IonContent>
    </IonPage>
  );
};

export default Home;
EOF

# --- src/theme/variables.css ---
write_file_heredoc "src/theme/variables.css" << 'EOF'
:root {
  --ion-color-primary: #3880ff;
  --ion-color-primary-rgb: 56, 128, 255;
  --ion-color-primary-contrast: #ffffff;
  --ion-color-primary-contrast-rgb: 255, 255, 255;
  --ion-color-primary-shade: #3171e0;
  --ion-color-primary-tint: #4c8dff;

  --ion-color-secondary: #3dc2ff;
  --ion-color-secondary-rgb: 61, 194, 255;
  --ion-color-secondary-contrast: #ffffff;
  --ion-color-secondary-contrast-rgb: 255, 255, 255;
  --ion-color-secondary-shade: #36abe0;
  --ion-color-secondary-tint: #50c8ff;

  --ion-color-success: #2dd36f;
  --ion-color-warning: #ffc409;
  --ion-color-danger: #eb445a;
  --ion-color-medium: #92949c;
  --ion-color-light: #f4f5f8;
}
EOF

# --- src/vite-env.d.ts ---
write_file "src/vite-env.d.ts" '/// <reference types="vite/client" />'

mkdir -p public

init_git
write_gitignore \
  "www/" \
  "android/" \
  "ios/"
write_editorconfig
write_nvmrc

finish "npm install" "npm run dev"
