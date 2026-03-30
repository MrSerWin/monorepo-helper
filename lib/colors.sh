#!/usr/bin/env bash
# Color and formatting utilities

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

# Logging functions
info() { echo -e "${BLUE}ℹ${NC} $1"; }
success() { echo -e "${GREEN}✔${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
error() { echo -e "${RED}✖${NC} $1"; }
step() { echo -e "${CYAN}→${NC} $1"; }

# Header with box
header() {
  local text="$1"
  local len=${#text}
  local border=$(printf '─%.0s' $(seq 1 $((len + 2))))
  echo -e "${CYAN}╭${border}╮${NC}"
  echo -e "${CYAN}│${NC} ${BOLD}${text}${NC} ${CYAN}│${NC}"
  echo -e "${CYAN}╰${border}╯${NC}"
}

# Section header
section() {
  echo ""
  echo -e "${MAGENTA}${BOLD}▸ $1${NC}"
  echo -e "${GRAY}$(printf '─%.0s' $(seq 1 50))${NC}"
}
