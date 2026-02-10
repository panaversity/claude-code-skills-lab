#!/bin/bash
# Interactive setup script for Context7 API key
#
# Usage: bash setup-api-key.sh [--check | --project | --user | --remove]
#
# Options:
#   --check    Check current API key status
#   --project  Save to project config (.context7.env)
#   --user     Save to user config (~/.context7.env) [default]
#   --remove   Remove saved API key

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/load-api-key.sh"

# Colors for output (if terminal supports it)
if [ -t 1 ]; then
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  RED='\033[0;31m'
  BLUE='\033[0;34m'
  NC='\033[0m' # No Color
else
  GREEN=''
  YELLOW=''
  RED=''
  BLUE=''
  NC=''
fi

print_header() {
  echo ""
  echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║       Context7 API Key Setup for fetch-library-docs        ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
  echo ""
}

print_status() {
  echo -e "${BLUE}Current Status:${NC}"
  echo ""

  local source=$(get_api_key_source)
  local key=$(load_context7_api_key)

  if [ -n "$key" ]; then
    # Mask the API key for display
    local key_len=${#key}
    local masked="${key:0:8}...${key:$((key_len - 4))}"
    echo -e "  ${GREEN}✓${NC} API Key: $masked"
    echo -e "  ${GREEN}✓${NC} Source: $source"
    echo ""
    echo -e "  ${GREEN}You're all set!${NC} The skill will use higher rate limits."
  else
    echo -e "  ${YELLOW}⚠${NC} API Key: Not configured"
    echo -e "  ${YELLOW}⚠${NC} Status: Using low rate limits (may fail)"
    echo ""
    echo -e "  ${YELLOW}Run this script without --check to configure your API key.${NC}"
  fi
  echo ""
}

setup_interactive() {
  local target="${1:-user}"

  print_header

  # Check current status
  local current_key=$(load_context7_api_key)
  if [ -n "$current_key" ]; then
    local source=$(get_api_key_source)
    local masked="${current_key:0:8}...${current_key: -4}"
    echo -e "${GREEN}✓${NC} API key already configured: $masked"
    echo -e "  Source: $source"
    echo ""
    read -p "Do you want to replace it? (y/N): " replace
    if [[ ! "$replace" =~ ^[Yy]$ ]]; then
      echo "Keeping existing configuration."
      exit 0
    fi
    echo ""
  fi

  # Instructions
  echo -e "${BLUE}Step 1:${NC} Get your free API key"
  echo ""
  echo "  1. Visit: https://context7.com/dashboard"
  echo "  2. Sign up or log in"
  echo "  3. Copy your API key (starts with 'ctx7sk_')"
  echo ""

  # Get API key
  echo -e "${BLUE}Step 2:${NC} Enter your API key"
  echo ""
  read -p "  API Key (or press Enter to skip): " api_key

  if [ -z "$api_key" ]; then
    echo ""
    echo -e "${YELLOW}Skipped.${NC} You can run this setup again later."
    echo ""
    echo "Alternative: Set environment variable manually:"
    echo "  export CONTEXT7_API_KEY=your_key_here"
    exit 0
  fi

  # Validate format
  if [[ ! "$api_key" =~ ^ctx7sk_ ]]; then
    echo ""
    echo -e "${YELLOW}Warning:${NC} API key doesn't start with 'ctx7sk_'"
    read -p "  Continue anyway? (y/N): " continue_anyway
    if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
      echo "Setup cancelled."
      exit 1
    fi
  fi

  # Save to appropriate location
  echo ""
  if [ "$target" = "project" ]; then
    local config_file=".context7.env"
    echo "CONTEXT7_API_KEY=$api_key" > "$config_file"
    echo -e "${GREEN}✓${NC} Saved to: $config_file (project-specific)"
    echo ""
    echo -e "${YELLOW}Note:${NC} Add '.context7.env' to your .gitignore to keep it private:"
    echo "  echo '.context7.env' >> .gitignore"
  else
    local config_file="$HOME/.context7.env"
    echo "CONTEXT7_API_KEY=$api_key" > "$config_file"
    # Restrict permissions (skip on Windows where chmod is unsupported)
    if [[ "$OSTYPE" != "msys" && "$OSTYPE" != "mingw"* && "$OSTYPE" != "cygwin" ]]; then
      chmod 600 "$config_file"
    fi
    echo -e "${GREEN}✓${NC} Saved to: $config_file (user-level)"
  fi

  echo ""
  echo -e "${GREEN}Setup complete!${NC} The fetch-library-docs skill will now use your API key."
  echo ""
}

remove_key() {
  print_header
  echo "Removing saved API keys..."
  echo ""

  local removed=0

  if [ -f ".context7.env" ]; then
    rm ".context7.env"
    echo -e "  ${GREEN}✓${NC} Removed: .context7.env (project)"
    removed=1
  fi

  if [ -f "$HOME/.context7.env" ]; then
    rm "$HOME/.context7.env"
    echo -e "  ${GREEN}✓${NC} Removed: ~/.context7.env (user)"
    removed=1
  fi

  if [ $removed -eq 0 ]; then
    echo -e "  ${YELLOW}No config files found to remove.${NC}"
  fi

  if [ -n "${CONTEXT7_API_KEY:-}" ]; then
    echo ""
    echo -e "  ${YELLOW}Note:${NC} CONTEXT7_API_KEY environment variable is still set."
    echo "  To remove it: unset CONTEXT7_API_KEY"
  fi

  echo ""
}

show_help() {
  echo "Context7 API Key Setup"
  echo ""
  echo "Usage: bash setup-api-key.sh [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  (no option)  Interactive setup (saves to ~/.context7.env)"
  echo "  --check      Check current API key status"
  echo "  --project    Save to project config (.context7.env)"
  echo "  --user       Save to user config (~/.context7.env)"
  echo "  --remove     Remove saved API key files"
  echo "  --help       Show this help message"
  echo ""
  echo "Priority order for API key loading:"
  echo "  1. CONTEXT7_API_KEY environment variable"
  echo "  2. .context7.env (project directory)"
  echo "  3. ~/.context7.env (home directory)"
  echo ""
  echo "Get your free API key at: https://context7.com/dashboard"
  echo ""
}

# Main
case "${1:-}" in
  --check)
    print_header
    print_status
    ;;
  --project)
    setup_interactive "project"
    ;;
  --user)
    setup_interactive "user"
    ;;
  --remove)
    remove_key
    ;;
  --help|-h)
    show_help
    ;;
  "")
    setup_interactive "user"
    ;;
  *)
    echo "Unknown option: $1"
    echo "Use --help for usage information."
    exit 1
    ;;
esac
