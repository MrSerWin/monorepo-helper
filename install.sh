#!/usr/bin/env bash
set -euo pipefail

# monorepo-helper (mh) - macOS / Linux installer

REPO_URL="https://github.com/your-username/monorepo-helper.git"
INSTALL_DIR="${MH_INSTALL_DIR:-$HOME/.monorepo-helper}"
BIN_DIR="$INSTALL_DIR/bin"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${CYAN}→${NC} $1"; }
success() { echo -e "${GREEN}✔${NC} $1"; }
warn()    { echo -e "${YELLOW}⚠${NC} $1"; }
error()   { echo -e "${RED}✖${NC} $1"; exit 1; }

echo ""
echo -e "  ${BOLD}${CYAN}monorepo-helper (mh) - Installer${NC}"
echo -e "  ${CYAN}$(printf '─%.0s' {1..40})${NC}"
echo ""

# ─── Prerequisites ────────────────────────────────────────────────────────────
command -v git &>/dev/null || error "git is required. Install it first."

# ─── Clone or update ──────────────────────────────────────────────────────────
if [[ -d "$INSTALL_DIR/.git" ]]; then
  info "Updating existing installation at $INSTALL_DIR ..."
  git -C "$INSTALL_DIR" pull origin main --quiet
  success "Updated to latest version"
else
  info "Installing to $INSTALL_DIR ..."
  git clone --depth 1 "$REPO_URL" "$INSTALL_DIR" --quiet
  success "Cloned repository"
fi

chmod +x "$BIN_DIR/mh"

# ─── Add to PATH ──────────────────────────────────────────────────────────────
SHELL_NAME="$(basename "${SHELL:-bash}")"
RC_FILE=""
case "$SHELL_NAME" in
  zsh)  RC_FILE="$HOME/.zshrc" ;;
  bash) RC_FILE="${BASH_ENV:-$HOME/.bashrc}" ;;
  fish) RC_FILE="$HOME/.config/fish/config.fish" ;;
  *)    RC_FILE="$HOME/.profile" ;;
esac

EXPORT_LINE="export PATH=\"\$PATH:$BIN_DIR\""
FISH_LINE="fish_add_path $BIN_DIR"

if [[ -f "$RC_FILE" ]] && grep -q "monorepo-helper" "$RC_FILE" 2>/dev/null; then
  success "PATH already configured in $RC_FILE"
else
  if [[ "$SHELL_NAME" == "fish" ]]; then
    echo -e "\n# monorepo-helper\n$FISH_LINE" >> "$RC_FILE"
  else
    echo -e "\n# monorepo-helper\n$EXPORT_LINE" >> "$RC_FILE"
  fi
  success "Added $BIN_DIR to PATH in $RC_FILE"
fi

# ─── Symlink to /usr/local/bin (optional) ────────────────────────────────────
if [[ -d "/usr/local/bin" ]] && [[ -w "/usr/local/bin" ]]; then
  ln -sf "$BIN_DIR/mh" /usr/local/bin/mh 2>/dev/null && success "Created symlink: /usr/local/bin/mh"
fi

# ─── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "  ${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${GREEN}${BOLD}  ✔ monorepo-helper installed!${NC}"
echo -e "  ${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Restart your terminal or run:"
echo -e "    ${CYAN}source $RC_FILE${NC}"
echo ""
echo "  Then:"
echo -e "    ${CYAN}mh help${NC}"
echo -e "    ${CYAN}mh generate next-app my-project${NC}"
echo ""
