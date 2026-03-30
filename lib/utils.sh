#!/usr/bin/env bash
# Shared utility functions for template generators

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/colors.sh"

# Default project name if not provided
DEFAULT_PROJECT_NAME=""

# Parse arguments: accepts optional --name flag or positional argument
parse_args() {
  local default_name="$1"
  shift
  DEFAULT_PROJECT_NAME="$default_name"
  PROJECT_NAME=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name|-n)
        PROJECT_NAME="$2"
        shift 2
        ;;
      --help|-h)
        show_template_help
        exit 0
        ;;
      *)
        if [[ -z "$PROJECT_NAME" ]]; then
          PROJECT_NAME="$1"
        fi
        shift
        ;;
    esac
  done

  PROJECT_NAME="${PROJECT_NAME:-$DEFAULT_PROJECT_NAME}"
}

# Show help for a template
show_template_help() {
  echo "Usage: mh generate <template> [project-name] [--name <name>]"
  echo ""
  echo "If no project name is provided, a default name will be used."
}

# Create project directory and cd into it
create_project_dir() {
  if [[ -d "$PROJECT_NAME" ]]; then
    error "Directory '${PROJECT_NAME}' already exists."
    exit 1
  fi
  mkdir -p "$PROJECT_NAME"
  cd "$PROJECT_NAME" || exit 1
  success "Created directory: ${BOLD}${PROJECT_NAME}${NC}"
}

# Initialize git repository
init_git() {
  git init -q
  success "Initialized git repository"
}

# Write .gitignore with common patterns + extras
write_gitignore() {
  local extras=("${@+"$@"}")
  cat > .gitignore << 'GITIGNORE'
# Dependencies
node_modules/
vendor/
.venv/
venv/
__pycache__/

# Build
dist/
build/
.next/
.nuxt/
.output/
.svelte-kit/
*.egg-info/

# Environment
.env
.env.local
.env.*.local

# IDE
.vscode/
.idea/
*.swp
*.swo
*~
.DS_Store
Thumbs.db

# Debug
npm-debug.log*
yarn-debug.log*
yarn-error.log*
pnpm-debug.log*

# Coverage
coverage/
.nyc_output/
htmlcov/

# Temp
*.tmp
*.temp
.cache/
GITIGNORE

  if [[ ${#extras[@]} -gt 0 && -n "${extras[0]}" ]]; then
    for extra in "${extras[@]}"; do
      echo "$extra" >> .gitignore
    done
  fi
  success "Created .gitignore"
}

# Write .editorconfig
write_editorconfig() {
  cat > .editorconfig << 'EOF'
root = true

[*]
indent_style = space
indent_size = 2
end_of_line = lf
charset = utf-8
trim_trailing_whitespace = true
insert_final_newline = true

[*.md]
trim_trailing_whitespace = false

[*.py]
indent_size = 4

[*.go]
indent_style = tab
indent_size = 4

[Makefile]
indent_style = tab
EOF
  success "Created .editorconfig"
}

# Write .nvmrc
write_nvmrc() {
  local version="${1:-22}"
  echo "$version" > .nvmrc
  success "Created .nvmrc (Node ${version})"
}

# Write a basic README
write_readme() {
  local name="$1"
  local description="$2"
  cat > README.md << EOF
# ${name}

${description}

## Getting Started

\`\`\`bash
# Install dependencies
${3:-npm install}

# Start development server
${4:-npm run dev}
\`\`\`

## Scripts

${5:-"See package.json for available scripts."}
EOF
  success "Created README.md"
}

# Write TypeScript config
write_tsconfig() {
  local content="$1"
  echo "$content" > tsconfig.json
  success "Created tsconfig.json"
}

# Write package.json
write_package_json() {
  local content="$1"
  echo "$content" > package.json
  success "Created package.json"
}

# Create a file with content
write_file() {
  local path="$1"
  local content="$2"
  mkdir -p "$(dirname "$path")"
  echo "$content" > "$path"
}

# Create a file from heredoc (for multi-line content)
write_file_heredoc() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
  cat > "$path"
}

# Final message after project creation
finish() {
  echo ""
  echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}${BOLD}  ✔ Project '${PROJECT_NAME}' created!${NC}"
  echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo -e "  ${CYAN}cd ${PROJECT_NAME}${NC}"
  if [[ -n "$1" ]]; then
    echo -e "  ${CYAN}$1${NC}"
  fi
  if [[ -n "$2" ]]; then
    echo -e "  ${CYAN}$2${NC}"
  fi
  echo ""
}

# Check if command exists
require_cmd() {
  if ! command -v "$1" &> /dev/null; then
    error "Required command '$1' not found. Please install it first."
    exit 1
  fi
}

# Detect package manager
detect_pm() {
  if command -v pnpm &> /dev/null; then
    echo "pnpm"
  elif command -v bun &> /dev/null; then
    echo "bun"
  elif command -v yarn &> /dev/null; then
    echo "yarn"
  else
    echo "npm"
  fi
}
