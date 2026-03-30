#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-storybook-ui" "$@"
create_project_dir

# --- package.json ---
write_package_json '{
  "name": "'"$PROJECT_NAME"'",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "storybook dev -p 6006",
    "build": "vite build",
    "build:storybook": "storybook build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^19.1.0",
    "react-dom": "^19.1.0"
  },
  "devDependencies": {
    "@storybook/addon-essentials": "^8.6.0",
    "@storybook/addon-interactions": "^8.6.0",
    "@storybook/addon-links": "^8.6.0",
    "@storybook/blocks": "^8.6.0",
    "@storybook/react": "^8.6.0",
    "@storybook/react-vite": "^8.6.0",
    "@storybook/test": "^8.6.0",
    "@tailwindcss/vite": "^4.1.3",
    "@types/react": "^19.1.0",
    "@types/react-dom": "^19.1.0",
    "@vitejs/plugin-react": "^4.4.0",
    "storybook": "^8.6.0",
    "tailwindcss": "^4.1.3",
    "typescript": "^5.8.3",
    "vite": "^6.3.0"
  }
}'

# --- vite.config.ts ---
write_file "vite.config.ts" 'import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";

export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: {
      "@": new URL("./src", import.meta.url).pathname,
    },
  },
});'

# --- tsconfig.json ---
write_tsconfig '{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["dom", "dom.iterable", "esnext"],
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "jsx": "react-jsx",
    "baseUrl": ".",
    "paths": {
      "@/*": ["src/*"]
    }
  },
  "include": ["src", ".storybook"],
  "exclude": ["node_modules"]
}'

# --- src/index.css ---
write_file "src/index.css" '@import "tailwindcss";'

# --- .storybook/main.ts ---
write_file ".storybook/main.ts" 'import type { StorybookConfig } from "@storybook/react-vite";

const config: StorybookConfig = {
  stories: ["../src/**/*.mdx", "../src/**/*.stories.@(js|jsx|mjs|ts|tsx)"],
  addons: [
    "@storybook/addon-links",
    "@storybook/addon-essentials",
    "@storybook/addon-interactions",
  ],
  framework: {
    name: "@storybook/react-vite",
    options: {},
  },
};

export default config;'

# --- .storybook/preview.ts ---
write_file ".storybook/preview.ts" 'import type { Preview } from "@storybook/react";
import "../src/index.css";

const preview: Preview = {
  parameters: {
    controls: {
      matchers: {
        color: /(background|color)$/i,
        date: /Date$/i,
      },
    },
    layout: "centered",
  },
};

export default preview;'

# --- src/components/Button/Button.tsx ---
write_file "src/components/Button/Button.tsx" 'import { type ButtonHTMLAttributes, forwardRef } from "react";

export interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  /** The visual style variant of the button */
  variant?: "primary" | "secondary" | "outline" | "ghost" | "danger";
  /** The size of the button */
  size?: "sm" | "md" | "lg";
  /** Whether the button is in a loading state */
  loading?: boolean;
}

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  (
    {
      variant = "primary",
      size = "md",
      loading = false,
      disabled,
      className = "",
      children,
      ...props
    },
    ref
  ) => {
    const baseStyles =
      "inline-flex items-center justify-center rounded-lg font-medium transition-colors focus-visible:outline-2 focus-visible:outline-offset-2 disabled:pointer-events-none disabled:opacity-50";

    const variants = {
      primary:
        "bg-blue-600 text-white hover:bg-blue-700 focus-visible:outline-blue-600",
      secondary:
        "bg-gray-100 text-gray-900 hover:bg-gray-200 focus-visible:outline-gray-600",
      outline:
        "border border-gray-300 bg-white text-gray-700 hover:bg-gray-50 focus-visible:outline-gray-600",
      ghost:
        "text-gray-700 hover:bg-gray-100 focus-visible:outline-gray-600",
      danger:
        "bg-red-600 text-white hover:bg-red-700 focus-visible:outline-red-600",
    };

    const sizes = {
      sm: "px-3 py-1.5 text-sm gap-1.5",
      md: "px-4 py-2 text-sm gap-2",
      lg: "px-6 py-3 text-base gap-2",
    };

    return (
      <button
        ref={ref}
        disabled={disabled || loading}
        className={`${baseStyles} ${variants[variant]} ${sizes[size]} ${className}`}
        {...props}
      >
        {loading && (
          <svg
            className="h-4 w-4 animate-spin"
            fill="none"
            viewBox="0 0 24 24"
          >
            <circle
              className="opacity-25"
              cx="12"
              cy="12"
              r="10"
              stroke="currentColor"
              strokeWidth="4"
            />
            <path
              className="opacity-75"
              fill="currentColor"
              d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"
            />
          </svg>
        )}
        {children}
      </button>
    );
  }
);

Button.displayName = "Button";'

# --- src/components/Button/Button.stories.tsx ---
write_file "src/components/Button/Button.stories.tsx" 'import type { Meta, StoryObj } from "@storybook/react";
import { fn } from "@storybook/test";
import { Button } from "./Button";

const meta = {
  title: "Components/Button",
  component: Button,
  parameters: {
    layout: "centered",
  },
  tags: ["autodocs"],
  args: {
    onClick: fn(),
  },
  argTypes: {
    variant: {
      control: "select",
      options: ["primary", "secondary", "outline", "ghost", "danger"],
    },
    size: {
      control: "select",
      options: ["sm", "md", "lg"],
    },
    loading: { control: "boolean" },
    disabled: { control: "boolean" },
  },
} satisfies Meta<typeof Button>;

export default meta;
type Story = StoryObj<typeof meta>;

export const Primary: Story = {
  args: {
    children: "Primary Button",
    variant: "primary",
  },
};

export const Secondary: Story = {
  args: {
    children: "Secondary Button",
    variant: "secondary",
  },
};

export const Outline: Story = {
  args: {
    children: "Outline Button",
    variant: "outline",
  },
};

export const Ghost: Story = {
  args: {
    children: "Ghost Button",
    variant: "ghost",
  },
};

export const Danger: Story = {
  args: {
    children: "Delete",
    variant: "danger",
  },
};

export const Small: Story = {
  args: {
    children: "Small",
    size: "sm",
  },
};

export const Large: Story = {
  args: {
    children: "Large Button",
    size: "lg",
  },
};

export const Loading: Story = {
  args: {
    children: "Loading...",
    loading: true,
  },
};

export const Disabled: Story = {
  args: {
    children: "Disabled",
    disabled: true,
  },
};

export const AllVariants: Story = {
  render: () => (
    <div className="flex flex-wrap items-center gap-4">
      <Button variant="primary">Primary</Button>
      <Button variant="secondary">Secondary</Button>
      <Button variant="outline">Outline</Button>
      <Button variant="ghost">Ghost</Button>
      <Button variant="danger">Danger</Button>
    </div>
  ),
};'

# --- src/components/Button/index.ts ---
write_file "src/components/Button/index.ts" 'export { Button } from "./Button";
export type { ButtonProps } from "./Button";'

# --- src/components/Card/Card.tsx ---
write_file "src/components/Card/Card.tsx" 'import type { HTMLAttributes, ReactNode } from "react";

export interface CardProps extends HTMLAttributes<HTMLDivElement> {
  /** Card variant style */
  variant?: "default" | "outlined" | "elevated";
  /** Optional header content */
  header?: ReactNode;
  /** Optional footer content */
  footer?: ReactNode;
  /** Whether the card has padding */
  padded?: boolean;
}

export function Card({
  variant = "default",
  header,
  footer,
  padded = true,
  className = "",
  children,
  ...props
}: CardProps) {
  const variants = {
    default: "border border-gray-200 bg-white",
    outlined: "border-2 border-gray-300 bg-white",
    elevated: "bg-white shadow-lg",
  };

  return (
    <div
      className={`rounded-xl overflow-hidden ${variants[variant]} ${className}`}
      {...props}
    >
      {header && (
        <div className="border-b border-gray-200 px-6 py-4">{header}</div>
      )}
      <div className={padded ? "p-6" : ""}>{children}</div>
      {footer && (
        <div className="border-t border-gray-200 bg-gray-50 px-6 py-4">
          {footer}
        </div>
      )}
    </div>
  );
}'

# --- src/components/Card/Card.stories.tsx ---
write_file "src/components/Card/Card.stories.tsx" 'import type { Meta, StoryObj } from "@storybook/react";
import { Card } from "./Card";
import { Button } from "../Button";

const meta = {
  title: "Components/Card",
  component: Card,
  parameters: {
    layout: "centered",
  },
  tags: ["autodocs"],
  argTypes: {
    variant: {
      control: "select",
      options: ["default", "outlined", "elevated"],
    },
    padded: { control: "boolean" },
  },
  decorators: [
    (Story) => (
      <div className="w-[400px]">
        <Story />
      </div>
    ),
  ],
} satisfies Meta<typeof Card>;

export default meta;
type Story = StoryObj<typeof meta>;

export const Default: Story = {
  args: {
    children: (
      <div>
        <h3 className="text-lg font-semibold">Card Title</h3>
        <p className="mt-2 text-gray-600">
          This is a default card with some content inside. Cards can be used
          to group related information.
        </p>
      </div>
    ),
  },
};

export const Outlined: Story = {
  args: {
    variant: "outlined",
    children: (
      <div>
        <h3 className="text-lg font-semibold">Outlined Card</h3>
        <p className="mt-2 text-gray-600">
          An outlined card with a thicker border for emphasis.
        </p>
      </div>
    ),
  },
};

export const Elevated: Story = {
  args: {
    variant: "elevated",
    children: (
      <div>
        <h3 className="text-lg font-semibold">Elevated Card</h3>
        <p className="mt-2 text-gray-600">
          An elevated card with a shadow for depth.
        </p>
      </div>
    ),
  },
};

export const WithHeader: Story = {
  args: {
    header: <h3 className="font-semibold">Card Header</h3>,
    children: (
      <p className="text-gray-600">Card content goes here.</p>
    ),
  },
};

export const WithFooter: Story = {
  args: {
    children: (
      <div>
        <h3 className="text-lg font-semibold">Card with Footer</h3>
        <p className="mt-2 text-gray-600">This card has a footer area.</p>
      </div>
    ),
    footer: (
      <div className="flex justify-end gap-2">
        <Button variant="ghost" size="sm">Cancel</Button>
        <Button size="sm">Save</Button>
      </div>
    ),
  },
};

export const WithHeaderAndFooter: Story = {
  args: {
    header: (
      <div className="flex items-center justify-between">
        <h3 className="font-semibold">User Profile</h3>
        <span className="rounded-full bg-green-100 px-2 py-0.5 text-xs font-medium text-green-700">
          Active
        </span>
      </div>
    ),
    children: (
      <div className="space-y-3">
        <div>
          <p className="text-sm text-gray-500">Name</p>
          <p className="font-medium">Jane Doe</p>
        </div>
        <div>
          <p className="text-sm text-gray-500">Email</p>
          <p className="font-medium">jane@example.com</p>
        </div>
        <div>
          <p className="text-sm text-gray-500">Role</p>
          <p className="font-medium">Administrator</p>
        </div>
      </div>
    ),
    footer: (
      <div className="flex justify-end gap-2">
        <Button variant="outline" size="sm">Edit</Button>
        <Button variant="danger" size="sm">Remove</Button>
      </div>
    ),
  },
};'

# --- src/components/Card/index.ts ---
write_file "src/components/Card/index.ts" 'export { Card } from "./Card";
export type { CardProps } from "./Card";'

# --- src/components/index.ts ---
write_file "src/components/index.ts" 'export { Button } from "./Button";
export type { ButtonProps } from "./Button";
export { Card } from "./Card";
export type { CardProps } from "./Card";'

init_git
write_gitignore "storybook-static/"
write_editorconfig
write_nvmrc

finish "npm install" "npm run dev"
