#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-ionic-angular-app" "$@"
create_project_dir

# --- package.json ---
write_package_json '{
  "name": "'"$PROJECT_NAME"'",
  "version": "0.0.1",
  "private": true,
  "scripts": {
    "ng": "ng",
    "start": "ng serve",
    "build": "ng build",
    "watch": "ng build --watch --configuration development",
    "test": "ng test",
    "lint": "ng lint",
    "ionic:serve": "ionic serve"
  },
  "dependencies": {
    "@angular/animations": "^19.1.0",
    "@angular/common": "^19.1.0",
    "@angular/compiler": "^19.1.0",
    "@angular/core": "^19.1.0",
    "@angular/forms": "^19.1.0",
    "@angular/platform-browser": "^19.1.0",
    "@angular/platform-browser-dynamic": "^19.1.0",
    "@angular/router": "^19.1.0",
    "@capacitor/app": "^6.0.0",
    "@capacitor/core": "^6.0.0",
    "@capacitor/haptics": "^6.0.0",
    "@capacitor/keyboard": "^6.0.0",
    "@capacitor/status-bar": "^6.0.0",
    "@ionic/angular": "^8.4.0",
    "ionicons": "^7.4.0",
    "rxjs": "~7.8.1",
    "tslib": "^2.8.0",
    "zone.js": "~0.15.0"
  },
  "devDependencies": {
    "@angular-devkit/build-angular": "^19.1.0",
    "@angular/cli": "^19.1.0",
    "@angular/compiler-cli": "^19.1.0",
    "@capacitor/cli": "^6.0.0",
    "@types/node": "^22.10.0",
    "typescript": "~5.7.0"
  }
}'

# --- ionic.config.json ---
write_file "ionic.config.json" '{
  "name": "'"$PROJECT_NAME"'",
  "integrations": {
    "capacitor": {}
  },
  "type": "angular"
}'

# --- capacitor.config.ts ---
write_file_heredoc "capacitor.config.ts" << EOF
import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.example.${PROJECT_NAME//[-]/.}',
  appName: '${PROJECT_NAME}',
  webDir: 'www',
  server: {
    androidScheme: 'https'
  }
};

export default config;
EOF

# --- angular.json ---
write_file_heredoc "angular.json" << EOF
{
  "\$schema": "./node_modules/@angular/cli/lib/config/schema.json",
  "version": 1,
  "newProjectRoot": "projects",
  "projects": {
    "${PROJECT_NAME}": {
      "projectType": "application",
      "root": "",
      "sourceRoot": "src",
      "prefix": "app",
      "architect": {
        "build": {
          "builder": "@angular-devkit/build-angular:application",
          "options": {
            "outputPath": "www",
            "index": "src/index.html",
            "browser": "src/main.ts",
            "polyfills": ["zone.js"],
            "tsConfig": "tsconfig.app.json",
            "assets": [
              { "glob": "**/*", "input": "src/assets", "output": "/assets" },
              { "glob": "**/*.svg", "input": "node_modules/ionicons/dist/ionicons/svg", "output": "./svg" }
            ],
            "styles": [
              "src/global.scss",
              "src/theme/variables.scss"
            ]
          },
          "configurations": {
            "production": {
              "budgets": [
                { "type": "initial", "maximumWarning": "2mb", "maximumError": "5mb" }
              ],
              "outputHashing": "all"
            },
            "development": {
              "optimization": false,
              "extractLicenses": false,
              "sourceMap": true
            }
          },
          "defaultConfiguration": "production"
        },
        "serve": {
          "builder": "@angular-devkit/build-angular:dev-server",
          "configurations": {
            "production": { "buildTarget": "${PROJECT_NAME}:build:production" },
            "development": { "buildTarget": "${PROJECT_NAME}:build:development" }
          },
          "defaultConfiguration": "development"
        }
      }
    }
  }
}
EOF

# --- tsconfig.json ---
write_tsconfig '{
  "compileOnSave": false,
  "compilerOptions": {
    "baseUrl": "./",
    "outDir": "./dist/out-tsc",
    "forceConsistentCasingInFileNames": true,
    "strict": true,
    "noImplicitOverride": true,
    "noPropertyAccessFromIndexSignature": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "sourceMap": true,
    "declaration": false,
    "downlevelIteration": true,
    "experimentalDecorators": true,
    "moduleResolution": "bundler",
    "importHelpers": true,
    "target": "ES2022",
    "module": "ES2022",
    "lib": ["ES2022", "dom"],
    "paths": {
      "@app/*": ["src/app/*"],
      "@env/*": ["src/environments/*"]
    }
  },
  "angularCompilerOptions": {
    "enableI18nLegacyMessageIdFormat": false,
    "strictInjectionParameters": true,
    "strictInputAccessModifiers": true,
    "strictTemplates": true
  }
}'

# --- tsconfig.app.json ---
write_file "tsconfig.app.json" '{
  "extends": "./tsconfig.json",
  "compilerOptions": {
    "outDir": "./out-tsc/app",
    "types": []
  },
  "files": ["src/main.ts"],
  "include": ["src/**/*.d.ts"]
}'

# --- src/index.html ---
write_file_heredoc "src/index.html" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <title>${PROJECT_NAME}</title>
  <base href="/" />
  <meta name="color-scheme" content="light dark" />
  <meta name="viewport" content="viewport-fit=cover, width=device-width, initial-scale=1.0, minimum-scale=1.0, maximum-scale=1.0, user-scalable=no" />
  <meta name="format-detection" content="telephone=no" />
  <meta name="msapplication-tap-highlight" content="no" />
  <link rel="icon" type="image/png" href="assets/icon/favicon.png" />
</head>
<body>
  <app-root></app-root>
</body>
</html>
EOF

# --- src/main.ts ---
write_file_heredoc "src/main.ts" << 'EOF'
import { bootstrapApplication } from '@angular/platform-browser';
import { RouteReuseStrategy, provideRouter, withPreloading, PreloadAllModules } from '@angular/router';
import { IonicRouteStrategy, provideIonicAngular } from '@ionic/angular/standalone';
import { AppComponent } from './app/app.component';
import { routes } from './app/app.routes';

bootstrapApplication(AppComponent, {
  providers: [
    { provide: RouteReuseStrategy, useClass: IonicRouteStrategy },
    provideIonicAngular(),
    provideRouter(routes, withPreloading(PreloadAllModules)),
  ],
});
EOF

# --- src/app/app.component.ts ---
write_file_heredoc "src/app/app.component.ts" << 'EOF'
import { Component } from '@angular/core';
import { IonApp, IonRouterOutlet } from '@ionic/angular/standalone';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [IonApp, IonRouterOutlet],
  template: `
    <ion-app>
      <ion-router-outlet></ion-router-outlet>
    </ion-app>
  `,
})
export class AppComponent {}
EOF

# --- src/app/app.routes.ts ---
write_file_heredoc "src/app/app.routes.ts" << 'EOF'
import { Routes } from '@angular/router';

export const routes: Routes = [
  {
    path: '',
    redirectTo: 'home',
    pathMatch: 'full',
  },
  {
    path: 'home',
    loadComponent: () => import('./pages/home/home.page').then((m) => m.HomePage),
  },
];
EOF

# --- src/app/pages/home/home.page.ts ---
write_file_heredoc "src/app/pages/home/home.page.ts" << 'EOF'
import { Component, signal } from '@angular/core';
import {
  IonHeader,
  IonToolbar,
  IonTitle,
  IonContent,
  IonList,
  IonItem,
  IonLabel,
  IonButton,
  IonIcon,
  IonFab,
  IonFabButton,
  IonCheckbox,
  IonInput,
  IonAlert,
} from '@ionic/angular/standalone';
import { addIcons } from 'ionicons';
import { add, trash } from 'ionicons/icons';
import { FormsModule } from '@angular/forms';

interface TodoItem {
  id: number;
  text: string;
  completed: boolean;
}

@Component({
  selector: 'app-home',
  standalone: true,
  imports: [
    IonHeader,
    IonToolbar,
    IonTitle,
    IonContent,
    IonList,
    IonItem,
    IonLabel,
    IonButton,
    IonIcon,
    IonFab,
    IonFabButton,
    IonCheckbox,
    IonInput,
    IonAlert,
    FormsModule,
  ],
  template: `
    <ion-header [translucent]="true">
      <ion-toolbar>
        <ion-title>Todo List</ion-title>
      </ion-toolbar>
    </ion-header>

    <ion-content [fullscreen]="true">
      <ion-header collapse="condense">
        <ion-toolbar>
          <ion-title size="large">Todo List</ion-title>
        </ion-toolbar>
      </ion-header>

      <ion-list>
        @for (item of todos(); track item.id) {
          <ion-item>
            <ion-checkbox
              slot="start"
              [checked]="item.completed"
              (ionChange)="toggleItem(item)"
            />
            <ion-label
              [style.text-decoration]="item.completed ? 'line-through' : 'none'"
            >
              {{ item.text }}
            </ion-label>
            <ion-button fill="clear" slot="end" (click)="deleteItem(item.id)">
              <ion-icon name="trash" slot="icon-only" />
            </ion-button>
          </ion-item>
        } @empty {
          <ion-item>
            <ion-label class="ion-text-center">
              <p>No todos yet. Tap + to add one!</p>
            </ion-label>
          </ion-item>
        }
      </ion-list>

      <ion-fab vertical="bottom" horizontal="end" slot="fixed">
        <ion-fab-button (click)="isAlertOpen = true">
          <ion-icon name="add" />
        </ion-fab-button>
      </ion-fab>

      <ion-alert
        [isOpen]="isAlertOpen"
        header="New Todo"
        [inputs]="alertInputs"
        [buttons]="alertButtons"
        (didDismiss)="isAlertOpen = false"
      />
    </ion-content>
  `,
})
export class HomePage {
  todos = signal<TodoItem[]>([
    { id: 1, text: 'Learn Ionic', completed: false },
    { id: 2, text: 'Build an app', completed: false },
    { id: 3, text: 'Ship it!', completed: false },
  ]);

  isAlertOpen = false;
  private nextId = 4;

  alertInputs = [
    { name: 'text', type: 'text' as const, placeholder: 'What needs to be done?' },
  ];

  alertButtons = [
    { text: 'Cancel', role: 'cancel' },
    {
      text: 'Add',
      handler: (data: { text: string }) => {
        if (data.text?.trim()) {
          this.todos.update((items) => [
            ...items,
            { id: this.nextId++, text: data.text.trim(), completed: false },
          ]);
        }
      },
    },
  ];

  constructor() {
    addIcons({ add, trash });
  }

  toggleItem(item: TodoItem) {
    this.todos.update((items) =>
      items.map((i) => (i.id === item.id ? { ...i, completed: !i.completed } : i))
    );
  }

  deleteItem(id: number) {
    this.todos.update((items) => items.filter((i) => i.id !== id));
  }
}
EOF

# --- src/global.scss ---
write_file_heredoc "src/global.scss" << 'EOF'
/*
 * App Global CSS
 */
@import "@ionic/angular/css/core.css";
@import "@ionic/angular/css/normalize.css";
@import "@ionic/angular/css/structure.css";
@import "@ionic/angular/css/typography.css";
@import "@ionic/angular/css/display.css";

@import "@ionic/angular/css/padding.css";
@import "@ionic/angular/css/float-elements.css";
@import "@ionic/angular/css/text-alignment.css";
@import "@ionic/angular/css/text-transformation.css";
@import "@ionic/angular/css/flex-utils.css";
EOF

# --- src/theme/variables.scss ---
write_file_heredoc "src/theme/variables.scss" << 'EOF'
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

# --- src/assets/ ---
mkdir -p src/assets/icon

# --- src/environments ---
write_file "src/environments/environment.ts" 'export const environment = {
  production: false,
};'

write_file "src/environments/environment.prod.ts" 'export const environment = {
  production: true,
};'

init_git
write_gitignore \
  "www/" \
  "android/" \
  "ios/" \
  ".angular/"
write_editorconfig
write_nvmrc

finish "npm install" "npm start"
