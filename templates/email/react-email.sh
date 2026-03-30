#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-react-email" "$@"
create_project_dir

# --- package.json ---
write_package_json '{
  "name": "'"$PROJECT_NAME"'",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "email dev",
    "export": "email export --outDir out",
    "send": "tsx src/send.ts"
  },
  "dependencies": {
    "@react-email/components": "^0.0.36",
    "react": "^19.1.0",
    "react-dom": "^19.1.0",
    "react-email": "^3.0.0",
    "resend": "^4.2.0"
  },
  "devDependencies": {
    "@types/node": "^22.14.0",
    "@types/react": "^19.1.0",
    "@types/react-dom": "^19.1.0",
    "tsx": "^4.19.0",
    "typescript": "^5.8.3"
  }
}'

# --- tsconfig.json ---
write_tsconfig '{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "jsx": "react-jsx",
    "outDir": "dist",
    "rootDir": ".",
    "baseUrl": ".",
    "paths": {
      "@/*": ["./*"]
    }
  },
  "include": ["**/*.ts", "**/*.tsx"],
  "exclude": ["node_modules", "dist", "out"]
}'

# --- .env.example ---
write_file ".env.example" '# Resend API Key - get yours at https://resend.com
RESEND_API_KEY=re_your_api_key_here

# Sender email (must be verified in Resend)
FROM_EMAIL=onboarding@resend.dev'

# --- emails/welcome.tsx ---
write_file "emails/welcome.tsx" 'import {
  Body,
  Button,
  Container,
  Head,
  Heading,
  Hr,
  Html,
  Link,
  Preview,
  Section,
  Text,
} from "@react-email/components";
import * as React from "react";

interface WelcomeEmailProps {
  username?: string;
  loginUrl?: string;
}

export default function WelcomeEmail({
  username = "User",
  loginUrl = "https://example.com/login",
}: WelcomeEmailProps) {
  return (
    <Html>
      <Head />
      <Preview>Welcome to our platform, {username}!</Preview>
      <Body style={main}>
        <Container style={container}>
          <Heading style={h1}>Welcome, {username}!</Heading>
          <Text style={text}>
            We'\''re excited to have you on board. Your account has been created
            successfully and you'\''re ready to get started.
          </Text>
          <Section style={buttonContainer}>
            <Button style={button} href={loginUrl}>
              Get Started
            </Button>
          </Section>
          <Hr style={hr} />
          <Text style={footer}>
            If you didn'\''t create this account, you can safely ignore this email.
          </Text>
          <Text style={footer}>
            <Link href="https://example.com" style={link}>
              Your Company
            </Link>
          </Text>
        </Container>
      </Body>
    </Html>
  );
}

const main = {
  backgroundColor: "#f6f9fc",
  fontFamily:
    '\''-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Ubuntu, sans-serif'\'',
};

const container = {
  backgroundColor: "#ffffff",
  margin: "0 auto",
  padding: "40px 20px",
  maxWidth: "560px",
  borderRadius: "8px",
};

const h1 = {
  color: "#1a1a1a",
  fontSize: "24px",
  fontWeight: "600" as const,
  lineHeight: "32px",
  margin: "0 0 20px",
};

const text = {
  color: "#4a4a4a",
  fontSize: "16px",
  lineHeight: "26px",
  margin: "0 0 20px",
};

const buttonContainer = {
  textAlign: "center" as const,
  margin: "24px 0",
};

const button = {
  backgroundColor: "#3b82f6",
  borderRadius: "6px",
  color: "#ffffff",
  fontSize: "16px",
  fontWeight: "600" as const,
  textDecoration: "none",
  textAlign: "center" as const,
  padding: "12px 24px",
};

const hr = {
  borderColor: "#e6e6e6",
  margin: "24px 0",
};

const footer = {
  color: "#8c8c8c",
  fontSize: "12px",
  lineHeight: "20px",
  margin: "0",
};

const link = {
  color: "#3b82f6",
  textDecoration: "underline",
};'

# --- emails/reset-password.tsx ---
write_file "emails/reset-password.tsx" 'import {
  Body,
  Button,
  Container,
  Head,
  Heading,
  Hr,
  Html,
  Link,
  Preview,
  Section,
  Text,
} from "@react-email/components";
import * as React from "react";

interface ResetPasswordEmailProps {
  username?: string;
  resetUrl?: string;
}

export default function ResetPasswordEmail({
  username = "User",
  resetUrl = "https://example.com/reset?token=abc123",
}: ResetPasswordEmailProps) {
  return (
    <Html>
      <Head />
      <Preview>Reset your password</Preview>
      <Body style={main}>
        <Container style={container}>
          <Heading style={h1}>Reset Your Password</Heading>
          <Text style={text}>Hi {username},</Text>
          <Text style={text}>
            We received a request to reset your password. Click the button below
            to choose a new password. This link will expire in 1 hour.
          </Text>
          <Section style={buttonContainer}>
            <Button style={button} href={resetUrl}>
              Reset Password
            </Button>
          </Section>
          <Text style={text}>
            If you didn'\''t request a password reset, you can safely ignore this
            email. Your password will not be changed.
          </Text>
          <Hr style={hr} />
          <Text style={footer}>
            If the button doesn'\''t work, copy and paste this URL into your browser:
          </Text>
          <Text style={footer}>
            <Link href={resetUrl} style={link}>
              {resetUrl}
            </Link>
          </Text>
        </Container>
      </Body>
    </Html>
  );
}

const main = {
  backgroundColor: "#f6f9fc",
  fontFamily:
    '\''-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Ubuntu, sans-serif'\'',
};

const container = {
  backgroundColor: "#ffffff",
  margin: "0 auto",
  padding: "40px 20px",
  maxWidth: "560px",
  borderRadius: "8px",
};

const h1 = {
  color: "#1a1a1a",
  fontSize: "24px",
  fontWeight: "600" as const,
  lineHeight: "32px",
  margin: "0 0 20px",
};

const text = {
  color: "#4a4a4a",
  fontSize: "16px",
  lineHeight: "26px",
  margin: "0 0 20px",
};

const buttonContainer = {
  textAlign: "center" as const,
  margin: "24px 0",
};

const button = {
  backgroundColor: "#dc2626",
  borderRadius: "6px",
  color: "#ffffff",
  fontSize: "16px",
  fontWeight: "600" as const,
  textDecoration: "none",
  textAlign: "center" as const,
  padding: "12px 24px",
};

const hr = {
  borderColor: "#e6e6e6",
  margin: "24px 0",
};

const footer = {
  color: "#8c8c8c",
  fontSize: "12px",
  lineHeight: "20px",
  margin: "0",
};

const link = {
  color: "#3b82f6",
  textDecoration: "underline",
};'

# --- src/send.ts ---
write_file "src/send.ts" 'import { Resend } from "resend";
import WelcomeEmail from "../emails/welcome.js";

const resend = new Resend(process.env.RESEND_API_KEY);

async function main() {
  const { data, error } = await resend.emails.send({
    from: process.env.FROM_EMAIL || "onboarding@resend.dev",
    to: ["user@example.com"],
    subject: "Welcome!",
    react: WelcomeEmail({ username: "John" }),
  });

  if (error) {
    console.error("Failed to send email:", error);
    process.exit(1);
  }

  console.log("Email sent successfully:", data);
}

main();'

init_git
write_gitignore ".react-email/" "out/"
write_editorconfig
write_nvmrc

finish "npm install" "npm run dev"
