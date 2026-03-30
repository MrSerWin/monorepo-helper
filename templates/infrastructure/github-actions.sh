#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-github-project" "$@"
header "GitHub Actions CI/CD Pipelines"

create_project_dir

# ── CI Workflow ──────────────────────────────────────────────
section "CI workflow"
mkdir -p .github/workflows

write_file_heredoc .github/workflows/ci.yml << 'EOF'
name: CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  lint:
    name: Lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version-file: ".nvmrc"
          cache: "npm"

      - run: npm ci
      - run: npm run lint

  test:
    name: Test
    runs-on: ubuntu-latest
    needs: lint
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version-file: ".nvmrc"
          cache: "npm"

      - run: npm ci
      - run: npm run test -- --coverage

      - name: Upload coverage
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: coverage-report
          path: coverage/
          retention-days: 7

  build:
    name: Build
    runs-on: ubuntu-latest
    needs: test
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version-file: ".nvmrc"
          cache: "npm"

      - run: npm ci
      - run: npm run build

      - name: Upload build artifact
        uses: actions/upload-artifact@v4
        with:
          name: build-output
          path: dist/
          retention-days: 7
EOF
success "Created .github/workflows/ci.yml"

# ── Deploy Workflow ──────────────────────────────────────────
section "Deploy workflow"
write_file_heredoc .github/workflows/deploy.yml << 'EOF'
name: Deploy

on:
  push:
    branches: [main]

concurrency:
  group: deploy-${{ github.ref }}
  cancel-in-progress: false

jobs:
  deploy-staging:
    name: Deploy to Staging
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version-file: ".nvmrc"
          cache: "npm"

      - run: npm ci
      - run: npm run build

      - name: Deploy to staging
        run: |
          echo "Deploy to staging environment"
          # Replace with your deployment command:
          # npx vercel --prod --token=${{ secrets.VERCEL_TOKEN }}
          # aws s3 sync dist/ s3://${{ vars.S3_BUCKET_STAGING }}
          # ssh deploy@staging "cd /app && git pull && npm ci && pm2 reload all"
        env:
          NODE_ENV: production

  deploy-production:
    name: Deploy to Production
    runs-on: ubuntu-latest
    needs: deploy-staging
    environment: production
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version-file: ".nvmrc"
          cache: "npm"

      - run: npm ci
      - run: npm run build

      - name: Deploy to production
        run: |
          echo "Deploy to production environment"
          # Replace with your deployment command
        env:
          NODE_ENV: production
EOF
success "Created .github/workflows/deploy.yml"

# ── Release Workflow ─────────────────────────────────────────
section "Release workflow"
write_file_heredoc .github/workflows/release.yml << 'EOF'
name: Release

on:
  push:
    branches: [main]

permissions:
  contents: write
  pull-requests: write

jobs:
  release:
    name: Semantic Release
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
          token: ${{ secrets.GITHUB_TOKEN }}

      - uses: actions/setup-node@v4
        with:
          node-version-file: ".nvmrc"
          cache: "npm"

      - run: npm ci

      - name: Create release
        uses: google-github-actions/release-please-action@v4
        with:
          release-type: node
          token: ${{ secrets.GITHUB_TOKEN }}
EOF
success "Created .github/workflows/release.yml"

# ── Dependabot ───────────────────────────────────────────────
section "Dependabot configuration"
write_file_heredoc .github/dependabot.yml << 'EOF'
version: 2
updates:
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
    open-pull-requests-limit: 10
    reviewers:
      - "your-username"
    labels:
      - "dependencies"
    groups:
      dev-dependencies:
        dependency-type: "development"
        update-types:
          - "minor"
          - "patch"
      production-dependencies:
        dependency-type: "production"
        update-types:
          - "patch"

  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
    labels:
      - "ci"
EOF
success "Created .github/dependabot.yml"

# ── PR Template ──────────────────────────────────────────────
section "Pull request template"
write_file_heredoc .github/PULL_REQUEST_TEMPLATE.md << 'EOF'
## Description

<!-- Briefly describe what this PR does -->

## Type of Change

- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Breaking change (fix or feature causing existing functionality to change)
- [ ] Documentation update
- [ ] Refactoring (no functional changes)

## How Has This Been Tested?

<!-- Describe the tests you ran -->

- [ ] Unit tests
- [ ] Integration tests
- [ ] Manual testing

## Checklist

- [ ] My code follows the project's style guidelines
- [ ] I have performed a self-review of my code
- [ ] I have added tests that prove my fix/feature works
- [ ] New and existing tests pass locally
- [ ] I have updated the documentation accordingly
EOF
success "Created .github/PULL_REQUEST_TEMPLATE.md"

# ── Issue Templates ──────────────────────────────────────────
section "Issue templates"
mkdir -p .github/ISSUE_TEMPLATE

write_file_heredoc .github/ISSUE_TEMPLATE/bug_report.yml << 'EOF'
name: Bug Report
description: File a bug report to help us improve
title: "[Bug]: "
labels: ["bug", "triage"]
body:
  - type: markdown
    attributes:
      value: |
        Thanks for taking the time to fill out this bug report!

  - type: textarea
    id: description
    attributes:
      label: Describe the bug
      description: A clear and concise description of what the bug is.
    validations:
      required: true

  - type: textarea
    id: reproduction
    attributes:
      label: Steps to reproduce
      description: Steps to reproduce the behavior.
      placeholder: |
        1. Go to '...'
        2. Click on '...'
        3. See error
    validations:
      required: true

  - type: textarea
    id: expected
    attributes:
      label: Expected behavior
      description: What you expected to happen.
    validations:
      required: true

  - type: textarea
    id: screenshots
    attributes:
      label: Screenshots
      description: If applicable, add screenshots to help explain.

  - type: dropdown
    id: severity
    attributes:
      label: Severity
      options:
        - Low
        - Medium
        - High
        - Critical
    validations:
      required: true

  - type: textarea
    id: environment
    attributes:
      label: Environment
      description: |
        Please provide relevant environment details.
      placeholder: |
        - OS: macOS 15.x
        - Node: 22.x
        - Browser: Chrome 130
EOF
success "Created .github/ISSUE_TEMPLATE/bug_report.yml"

write_file_heredoc .github/ISSUE_TEMPLATE/feature_request.yml << 'EOF'
name: Feature Request
description: Suggest an idea for this project
title: "[Feature]: "
labels: ["enhancement"]
body:
  - type: markdown
    attributes:
      value: |
        Thank you for suggesting a feature!

  - type: textarea
    id: problem
    attributes:
      label: Problem statement
      description: A clear description of the problem this feature would solve.
      placeholder: "I'm always frustrated when..."
    validations:
      required: true

  - type: textarea
    id: solution
    attributes:
      label: Proposed solution
      description: Describe the solution you'd like.
    validations:
      required: true

  - type: textarea
    id: alternatives
    attributes:
      label: Alternatives considered
      description: Describe any alternative solutions or features you've considered.

  - type: textarea
    id: context
    attributes:
      label: Additional context
      description: Add any other context or screenshots about the feature request.
EOF
success "Created .github/ISSUE_TEMPLATE/feature_request.yml"

# ── Makefile ─────────────────────────────────────────────────
section "Makefile"
write_file_heredoc Makefile << 'MAKEFILE'
.PHONY: help install lint test build clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

install: ## Install dependencies
	npm ci

lint: ## Run linter
	npm run lint

lint-fix: ## Run linter with auto-fix
	npm run lint -- --fix

test: ## Run tests
	npm run test

test-coverage: ## Run tests with coverage
	npm run test -- --coverage

build: ## Build project
	npm run build

clean: ## Clean build artifacts
	rm -rf dist coverage node_modules

ci: lint test build ## Run full CI pipeline locally
MAKEFILE
success "Created Makefile"

# ── Placeholder project files ────────────────────────────────
section "Placeholder project files"
write_file_heredoc package.json << EOF
{
  "name": "$PROJECT_NAME",
  "version": "0.0.1",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "echo 'Add your dev script'",
    "build": "echo 'Add your build script'",
    "lint": "echo 'Add your lint script'",
    "test": "echo 'Add your test script'"
  }
}
EOF
success "Created package.json"

echo "22" > .nvmrc
success "Created .nvmrc"

# ── Finalize ─────────────────────────────────────────────────
section "Finalizing"
write_gitignore
write_editorconfig
init_git

write_readme "$PROJECT_NAME" \
  "GitHub Actions CI/CD pipelines with issue templates and Dependabot." \
  "npm install" \
  "make ci" \
  "Run \`make help\` to see all available commands."

finish "npm install" "make ci"
