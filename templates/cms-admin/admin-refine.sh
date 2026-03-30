#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-refine-app" "$@"
create_project_dir

# --- package.json ---
write_package_json '{
  "name": "'"$PROJECT_NAME"'",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "preview": "vite preview",
    "lint": "eslint . --ext ts,tsx"
  },
  "dependencies": {
    "@refinedev/antd": "^5.44.0",
    "@refinedev/cli": "^2.16.0",
    "@refinedev/core": "^4.56.0",
    "@refinedev/react-router": "^1.0.0",
    "@refinedev/simple-rest": "^5.0.0",
    "antd": "^5.23.0",
    "react": "^19.1.0",
    "react-dom": "^19.1.0",
    "react-router": "^7.4.0"
  },
  "devDependencies": {
    "@types/react": "^19.1.0",
    "@types/react-dom": "^19.1.0",
    "@vitejs/plugin-react": "^4.4.0",
    "typescript": "^5.8.3",
    "vite": "^6.2.0"
  }
}'

# --- tsconfig.json ---
write_tsconfig '{
  "compilerOptions": {
    "target": "ES2020",
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "moduleResolution": "bundler",
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "allowImportingTsExtensions": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "react-jsx",
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["src"],
  "exclude": ["node_modules"]
}'

# --- vite.config.ts ---
write_file "vite.config.ts" 'import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { resolve } from "path";

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      "@": resolve(__dirname, "src"),
    },
  },
  server: {
    port: 5173,
    open: true,
  },
});'

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

# --- src/main.tsx ---
write_file "src/main.tsx" 'import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import App from "./App";

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <App />
  </StrictMode>
);'

# --- src/App.tsx ---
write_file "src/App.tsx" 'import { Refine } from "@refinedev/core";
import { ThemedLayoutV2, useNotificationProvider, RefineThemes } from "@refinedev/antd";
import { BrowserRouter, Routes, Route, Outlet } from "react-router";
import routerBindings, {
  NavigateToResource,
  UnsavedChangesNotifier,
  DocumentTitleHandler,
} from "@refinedev/react-router";
import { ConfigProvider, App as AntdApp } from "antd";
import "@refinedev/antd/dist/reset.css";

import { dataProvider } from "./providers/data";
import { authProvider } from "./providers/auth";
import { PostList } from "./pages/posts/list";
import { PostCreate } from "./pages/posts/create";
import { PostEdit } from "./pages/posts/edit";
import { PostShow } from "./pages/posts/show";

export default function App() {
  return (
    <BrowserRouter>
      <ConfigProvider theme={RefineThemes.Blue}>
        <AntdApp>
          <Refine
            routerProvider={routerBindings}
            dataProvider={dataProvider}
            authProvider={authProvider}
            notificationProvider={useNotificationProvider}
            resources={[
              {
                name: "posts",
                list: "/posts",
                create: "/posts/create",
                edit: "/posts/edit/:id",
                show: "/posts/show/:id",
                meta: {
                  canDelete: true,
                },
              },
            ]}
            options={{
              syncWithLocation: true,
              warnWhenUnsavedChanges: true,
              useNewQueryKeys: true,
            }}
          >
            <Routes>
              <Route
                element={
                  <ThemedLayoutV2>
                    <Outlet />
                  </ThemedLayoutV2>
                }
              >
                <Route index element={<NavigateToResource resource="posts" />} />
                <Route path="/posts">
                  <Route index element={<PostList />} />
                  <Route path="create" element={<PostCreate />} />
                  <Route path="edit/:id" element={<PostEdit />} />
                  <Route path="show/:id" element={<PostShow />} />
                </Route>
              </Route>
            </Routes>
            <UnsavedChangesNotifier />
            <DocumentTitleHandler />
          </Refine>
        </AntdApp>
      </ConfigProvider>
    </BrowserRouter>
  );
}'

# --- src/providers/data.ts ---
write_file "src/providers/data.ts" 'import simpleRestDataProvider from "@refinedev/simple-rest";

const API_URL = "https://api.fake-rest.refine.dev";

export const dataProvider = simpleRestDataProvider(API_URL);'

# --- src/providers/auth.ts ---
write_file "src/providers/auth.ts" 'import type { AuthProvider } from "@refinedev/core";

export const authProvider: AuthProvider = {
  login: async ({ email, password }) => {
    // Replace with your actual authentication logic
    if (email && password) {
      localStorage.setItem(
        "auth",
        JSON.stringify({ email, name: "Admin User" })
      );
      return { success: true, redirectTo: "/" };
    }
    return {
      success: false,
      error: { name: "LoginError", message: "Invalid credentials" },
    };
  },
  logout: async () => {
    localStorage.removeItem("auth");
    return { success: true, redirectTo: "/login" };
  },
  check: async () => {
    const auth = localStorage.getItem("auth");
    if (auth) {
      return { authenticated: true };
    }
    return { authenticated: false, redirectTo: "/login" };
  },
  getPermissions: async () => null,
  getIdentity: async () => {
    const auth = localStorage.getItem("auth");
    if (auth) {
      const parsed = JSON.parse(auth);
      return { id: 1, name: parsed.name, avatar: "" };
    }
    return null;
  },
  onError: async (error) => {
    if (error?.statusCode === 401) {
      return { logout: true };
    }
    return { error };
  },
};'

# --- src/pages/posts/list.tsx ---
write_file "src/pages/posts/list.tsx" 'import {
  List,
  useTable,
  EditButton,
  ShowButton,
  DeleteButton,
  TagField,
  TextField,
  DateField,
} from "@refinedev/antd";
import { Table, Space } from "antd";

export const PostList = () => {
  const { tableProps } = useTable({ syncWithLocation: true });

  return (
    <List>
      <Table {...tableProps} rowKey="id">
        <Table.Column dataIndex="id" title="ID" sorter />
        <Table.Column dataIndex="title" title="Title" sorter />
        <Table.Column
          dataIndex="status"
          title="Status"
          render={(value: string) => <TagField value={value} />}
        />
        <Table.Column
          dataIndex="createdAt"
          title="Created At"
          render={(value: string) => <DateField value={value} format="YYYY-MM-DD" />}
          sorter
        />
        <Table.Column
          title="Actions"
          dataIndex="actions"
          render={(_, record: { id: number }) => (
            <Space>
              <EditButton hideText size="small" recordItemId={record.id} />
              <ShowButton hideText size="small" recordItemId={record.id} />
              <DeleteButton hideText size="small" recordItemId={record.id} />
            </Space>
          )}
        />
      </Table>
    </List>
  );
};'

# --- src/pages/posts/create.tsx ---
write_file "src/pages/posts/create.tsx" 'import { Create, useForm, useSelect } from "@refinedev/antd";
import { Form, Input, Select } from "antd";

export const PostCreate = () => {
  const { formProps, saveButtonProps } = useForm();

  const { selectProps: categorySelectProps } = useSelect({
    resource: "categories",
    optionLabel: "title",
  });

  return (
    <Create saveButtonProps={saveButtonProps}>
      <Form {...formProps} layout="vertical">
        <Form.Item
          label="Title"
          name="title"
          rules={[{ required: true, message: "Title is required" }]}
        >
          <Input />
        </Form.Item>
        <Form.Item
          label="Status"
          name="status"
          rules={[{ required: true }]}
        >
          <Select
            options={[
              { value: "published", label: "Published" },
              { value: "draft", label: "Draft" },
              { value: "rejected", label: "Rejected" },
            ]}
          />
        </Form.Item>
        <Form.Item label="Category" name={["category", "id"]}>
          <Select {...categorySelectProps} />
        </Form.Item>
        <Form.Item label="Content" name="content">
          <Input.TextArea rows={6} />
        </Form.Item>
      </Form>
    </Create>
  );
};'

# --- src/pages/posts/edit.tsx ---
write_file "src/pages/posts/edit.tsx" 'import { Edit, useForm, useSelect } from "@refinedev/antd";
import { Form, Input, Select } from "antd";

export const PostEdit = () => {
  const { formProps, saveButtonProps } = useForm();

  const { selectProps: categorySelectProps } = useSelect({
    resource: "categories",
    optionLabel: "title",
    defaultValue: formProps?.initialValues?.category?.id,
  });

  return (
    <Edit saveButtonProps={saveButtonProps}>
      <Form {...formProps} layout="vertical">
        <Form.Item
          label="Title"
          name="title"
          rules={[{ required: true, message: "Title is required" }]}
        >
          <Input />
        </Form.Item>
        <Form.Item
          label="Status"
          name="status"
          rules={[{ required: true }]}
        >
          <Select
            options={[
              { value: "published", label: "Published" },
              { value: "draft", label: "Draft" },
              { value: "rejected", label: "Rejected" },
            ]}
          />
        </Form.Item>
        <Form.Item label="Category" name={["category", "id"]}>
          <Select {...categorySelectProps} />
        </Form.Item>
        <Form.Item label="Content" name="content">
          <Input.TextArea rows={6} />
        </Form.Item>
      </Form>
    </Edit>
  );
};'

# --- src/pages/posts/show.tsx ---
write_file "src/pages/posts/show.tsx" 'import { Show, TagField, TextField, DateField } from "@refinedev/antd";
import { useShow } from "@refinedev/core";
import { Typography } from "antd";

const { Title } = Typography;

export const PostShow = () => {
  const { query } = useShow();
  const { data, isLoading } = query;
  const record = data?.data;

  return (
    <Show isLoading={isLoading}>
      <Title level={5}>ID</Title>
      <TextField value={record?.id} />

      <Title level={5}>Title</Title>
      <TextField value={record?.title} />

      <Title level={5}>Status</Title>
      <TagField value={record?.status} />

      <Title level={5}>Content</Title>
      <TextField value={record?.content} />

      <Title level={5}>Created At</Title>
      <DateField value={record?.createdAt} format="YYYY-MM-DD" />
    </Show>
  );
};'

# --- src/vite-env.d.ts ---
write_file "src/vite-env.d.ts" '/// <reference types="vite/client" />'

mkdir -p public

init_git
write_gitignore
write_editorconfig
write_nvmrc

finish "npm install" "npm run dev"
