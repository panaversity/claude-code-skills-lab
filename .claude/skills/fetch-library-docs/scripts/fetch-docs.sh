#!/bin/bash
# Main orchestrator: Token-efficient documentation fetcher
#
# This script achieves significant token savings by:
# 1. Fetching raw docs (stays in shell subprocess)
# 2. Filtering with content-type-aware extractors (0 LLM tokens!)
# 3. Returning only what Claude needs
#
# Context7 API Limits: Max 3 calls per question
# This skill uses max 2 calls (resolve + query), leaving 1 for Claude's retry
#
# Errors are returned as structured messages for Claude to handle

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load helpers
source "$SCRIPT_DIR/load-api-key.sh"

# Detect Python command early
PYTHON_CMD=$(get_python_cmd)
if [ -z "$PYTHON_CMD" ]; then
  echo "[PYTHON_NOT_FOUND]"
  echo ""
  echo "Python 3 is required but not found on this system."
  echo ""
  echo "Please install Python 3:"
  echo "  Windows: https://www.python.org/downloads/"
  echo "  macOS:   brew install python3"
  echo "  Linux:   sudo apt install python3"
  exit 1
fi

# Build MCP command with API key (if available)
MCP_CMD=$(build_mcp_command)

# Parse arguments
LIBRARY_ID=""
LIBRARY_NAME=""
TOPIC=""
CONTENT_TYPE="examples"  # Default: code examples (comma-separated for multiple)
CONTENT_TYPE_SET=0       # Track if --content-type was explicitly set
MAX_ITEMS=5              # Max items per content type
MODE=""                  # Legacy mode (only set if --mode is used)
PAGE=1                   # Pagination (passed to fetch-raw.sh but not used by API)
VERBOSE=0

usage() {
  cat << USAGE
Usage: $0 [OPTIONS]

Token-efficient documentation fetcher using Context7 MCP

REQUIRED (one of):
  --library-id ID    Context7 library ID (e.g., /reactjs/react.dev) - saves 1 API call
  --library NAME     Library name (will resolve to ID) - uses 1 extra API call

FILTERING OPTIONS:
  --topic TOPIC      Topic to focus on (e.g., hooks, routing)
  --content-type TYPES  Content types to extract (comma-separated, default: examples)
                        Types: examples, api-ref, setup, concepts, migration,
                               troubleshooting, patterns, notes, all
  --max-items NUM    Max items per content type (default: 5)

LEGACY OPTIONS:
  --mode MODE        Legacy mode: code → examples, info → concepts,examples

OTHER OPTIONS:
  --verbose, -v      Show token statistics
  --help, -h         Show this help
  --api-status       Check API key configuration status

CONTENT TYPE EXAMPLES:
  --content-type examples              # Code examples only
  --content-type api-ref               # API signatures and documentation
  --content-type examples,api-ref      # Both code examples AND API reference
  --content-type setup                 # Installation/terminal commands
  --content-type concepts,examples     # Explanations with code examples
  --content-type migration             # Before/after, breaking changes
  --content-type all                   # No filtering, return everything

USAGE EXAMPLES:
  $0 --library react --topic useState --content-type examples
  $0 --library-id /vercel/next.js --topic routing --content-type examples,api-ref
  $0 --library prisma --topic "getting started" --content-type setup
  $0 --library nextjs --topic "upgrade 14 to 15" --content-type migration
USAGE
  exit 0
}

# Show API key status
show_api_status() {
  echo "Context7 API Key Status"
  echo "======================="
  echo ""
  if has_api_key; then
    local key=$(load_context7_api_key)
    local key_len=${#key}
    local masked="${key:0:12}...${key:$((key_len - 4))}"
    echo "Status: CONFIGURED"
    echo "Key: $masked"
    echo "Source: $(get_api_key_source)"
  else
    echo "Status: NOT CONFIGURED"
    echo ""
    echo "To configure, save your API key:"
    echo "  echo \"CONTEXT7_API_KEY=your_key\" > ~/.context7.env"
    echo ""
    echo "Get a free API key at: https://context7.com/dashboard"
  fi
  exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --api-status)
      show_api_status
      ;;
    --library-id)
      LIBRARY_ID="$2"
      shift 2
      ;;
    --library)
      LIBRARY_NAME="$2"
      shift 2
      ;;
    --topic)
      TOPIC="$2"
      shift 2
      ;;
    --content-type)
      CONTENT_TYPE="$2"
      CONTENT_TYPE_SET=1
      shift 2
      ;;
    --max-items)
      MAX_ITEMS="$2"
      shift 2
      ;;
    --mode)
      # Legacy mode support - map to content-type
      MODE="$2"
      shift 2
      ;;
    -v|--verbose)
      VERBOSE=1
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      ;;
  esac
done

# Handle legacy --mode flag by mapping to content-type
# Only apply if --mode was used AND --content-type was NOT explicitly set
if [ -n "$MODE" ] && [ "$CONTENT_TYPE_SET" -eq 0 ]; then
  case "$MODE" in
    code)
      CONTENT_TYPE="examples,api-ref"
      ;;
    info)
      CONTENT_TYPE="concepts,examples"
      ;;
    *)
      echo "[WARNING] Unknown mode '$MODE', using default content-type" >&2
      ;;
  esac
fi

# Show status in verbose mode
if [ $VERBOSE -eq 1 ]; then
  if has_api_key; then
    echo "[INFO] API Key: configured ($(get_api_key_source))" >&2
  else
    echo "[WARNING] API Key: not configured" >&2
  fi
  echo "[INFO] Python: $PYTHON_CMD" >&2
fi

# Resolve library if name provided
if [ -n "${LIBRARY_NAME:-}" ] && [ -z "$LIBRARY_ID" ]; then
  [ $VERBOSE -eq 1 ] && echo "[INFO] Resolving library: $LIBRARY_NAME" >&2

  # Call resolve-library-id (requires both query and libraryName)
  RESOLVE_OUTPUT=$("$PYTHON_CMD" "$SCRIPT_DIR/mcp-client.py" call \
    -s "$MCP_CMD" \
    -t resolve-library-id \
    -p "{\"query\": \"$TOPIC\", \"libraryName\": \"$LIBRARY_NAME\"}" 2>&1) || {

    echo "[RESOLVE_ERROR]"
    echo ""
    echo "Failed to resolve library name: $LIBRARY_NAME"
    echo ""
    echo "Error: $RESOLVE_OUTPUT"
    exit 1
  }

  # Extract text from JSON
  if command -v jq &> /dev/null; then
    RESOLVE_TEXT=$(echo "$RESOLVE_OUTPUT" | jq -r '.content[0].text // empty' 2>/dev/null || echo "")
  else
    RESOLVE_TEXT=$(echo "$RESOLVE_OUTPUT" | "$PYTHON_CMD" -c 'import sys, json; data=json.load(sys.stdin); print(data.get("content", [{}])[0].get("text", ""))' 2>/dev/null || echo "")
  fi

  # Extract first library ID and title (cross-platform: no grep -oP)
  LIBRARY_ID=$(echo "$RESOLVE_TEXT" | "$PYTHON_CMD" -c "
import sys, re
text = sys.stdin.read()
m = re.search(r'Context7-compatible library ID:\s*([/\w.-]+)', text)
print(m.group(1) if m else '')
" 2>/dev/null || echo "")

  LIBRARY_TITLE=$(echo "$RESOLVE_TEXT" | "$PYTHON_CMD" -c "
import sys, re
text = sys.stdin.read()
m = re.search(r'^\d+\.\s*(.+)', text, re.MULTILINE)
print(m.group(1) if m else '')
" 2>/dev/null || echo "")

  if [ -z "$LIBRARY_ID" ]; then
    echo "[LIBRARY_NOT_FOUND]"
    echo ""
    echo "Could not find library: $LIBRARY_NAME"
    echo ""
    echo "Call budget: 1 of 3 calls used (resolution attempt)"
    echo ""
    echo "Try:"
    echo "  - Different spelling (e.g., 'nextjs' instead of 'next.js')"
    echo "  - Using --library-id with exact ID"
    echo ""
    echo "Common library IDs:"
    echo "  React:    /reactjs/react.dev"
    echo "  Next.js:  /vercel/next.js"
    echo "  Express:  /expressjs/express"
    echo "  Prisma:   /prisma/docs"
    exit 1
  fi

  # Validate: Check if resolved library matches user's intent
  # Convert both to lowercase for comparison
  LIBRARY_NAME_LOWER=$(echo "$LIBRARY_NAME" | tr '[:upper:]' '[:lower:]')
  LIBRARY_ID_LOWER=$(echo "$LIBRARY_ID" | tr '[:upper:]' '[:lower:]')
  LIBRARY_TITLE_LOWER=$(echo "$LIBRARY_TITLE" | tr '[:upper:]' '[:lower:]')

  # Check if library name appears in ID or title
  MATCH_FOUND=0
  if [[ "$LIBRARY_ID_LOWER" == *"$LIBRARY_NAME_LOWER"* ]] || \
     [[ "$LIBRARY_TITLE_LOWER" == *"$LIBRARY_NAME_LOWER"* ]]; then
    MATCH_FOUND=1
  fi

  # Also check for common variations
  LIBRARY_NAME_NOSPACE=$(echo "$LIBRARY_NAME_LOWER" | tr -d '.-_ ')
  LIBRARY_ID_NOSPACE=$(echo "$LIBRARY_ID_LOWER" | tr -d '.-_ ')
  if [[ "$LIBRARY_ID_NOSPACE" == *"$LIBRARY_NAME_NOSPACE"* ]]; then
    MATCH_FOUND=1
  fi

  if [ $MATCH_FOUND -eq 0 ]; then
    echo "[LIBRARY_MISMATCH]"
    echo ""
    echo "Warning: '$LIBRARY_NAME' resolved to an unexpected library."
    echo ""
    echo "Resolved library: $LIBRARY_TITLE"
    echo "Library ID: $LIBRARY_ID"
    echo ""
    echo "This may not be what you're looking for."
    echo ""
    echo "Call budget: 1 of 3 calls used"
    echo ""
    echo "Options:"
    echo "  1. Try a different spelling of the library name"
    echo "  2. Use --library-id with the exact ID if this is correct"
    echo "  3. Check common library IDs below"
    echo ""
    echo "Common library IDs:"
    echo "  React:     /reactjs/react.dev"
    echo "  Next.js:   /vercel/next.js"
    echo "  Express:   /expressjs/express"
    echo "  Prisma:    /prisma/docs"
    echo "  FastAPI:   /fastapi/fastapi"
    echo "  LangChain: /langchain-ai/langchainjs"
    exit 1
  fi

  [ $VERBOSE -eq 1 ] && echo "[INFO] Resolved to: $LIBRARY_ID ($LIBRARY_TITLE)" >&2
fi

# Validate library ID
if [ -z "$LIBRARY_ID" ]; then
  echo "[MISSING_ARGUMENT]"
  echo ""
  echo "Must specify --library-id or --library"
  echo ""
  echo "Examples:"
  echo "  --library react --topic hooks"
  echo "  --library-id /reactjs/react.dev --topic useState"
  exit 1
fi

# Validate library ID format when provided directly (skip if resolved)
if [ -z "${LIBRARY_NAME:-}" ]; then
  # User provided --library-id directly, validate format
  if [[ ! "$LIBRARY_ID" =~ ^/[a-zA-Z0-9_-]+/[a-zA-Z0-9_.-]+(/[a-zA-Z0-9_.-]+)?$ ]]; then
    echo "[INVALID_LIBRARY_ID]"
    echo ""
    echo "Invalid library ID format: $LIBRARY_ID"
    echo ""
    echo "Library ID must be in format: /org/project or /org/project/version"
    echo ""
    echo "Examples:"
    echo "  /reactjs/react.dev"
    echo "  /vercel/next.js"
    echo "  /vercel/next.js/v14.3.0"
    echo ""
    echo "Call budget: 0 calls used (validation failed before API call)"
    echo "Use --library <name> to auto-resolve, or correct the ID format."
    exit 1
  fi
  [ $VERBOSE -eq 1 ] && echo "[INFO] Using provided library ID: $LIBRARY_ID (saves 1 API call)" >&2
fi

# Step 1: Fetch raw documentation
[ $VERBOSE -eq 1 ] && echo "[INFO] Fetching documentation..." >&2

RAW_OUTPUT=$("$SCRIPT_DIR/fetch-raw.sh" "$LIBRARY_ID" "$TOPIC" "$MODE" "$PAGE" 2>&1) || {
  # fetch-raw.sh already formats error messages
  echo "$RAW_OUTPUT"
  exit 1
}

# Check if output starts with error marker
if [[ "$RAW_OUTPUT" == "["* ]] && [[ "$RAW_OUTPUT" == *"_ERROR]"* || "$RAW_OUTPUT" == *"_MISSING]"* || "$RAW_OUTPUT" == *"_NOT_FOUND]"* ]]; then
  echo "$RAW_OUTPUT"
  exit 1
fi

# Step 2: Extract text from JSON
if command -v jq &> /dev/null; then
  RAW_TEXT=$(echo "$RAW_OUTPUT" | jq -r '.content[0].text // empty' 2>/dev/null || echo "")
else
  RAW_TEXT=$(echo "$RAW_OUTPUT" | "$PYTHON_CMD" -c 'import sys, json; data=json.load(sys.stdin); print(data.get("content", [{}])[0].get("text", ""))' 2>/dev/null || echo "")
fi

if [ -z "$RAW_TEXT" ]; then
  echo "[EMPTY_RESULTS]"
  echo ""
  echo "No documentation found for this query."
  echo ""
  echo "Library ID: $LIBRARY_ID"
  echo "Topic: $TOPIC"
  echo ""
  echo "Call budget: 2 of 3 calls used (resolution + query)"
  echo "You have 1 call remaining for this question."
  echo ""
  echo "Suggestions:"
  echo "  1. Try a broader topic (e.g., 'hooks' instead of 'useCustomHook')"
  echo "  2. Try different content-type (e.g., --content-type all)"
  echo "  3. Verify the library ID is correct"
  echo "  4. Use the remaining call budget wisely"
  exit 1
fi

# Calculate raw token count (approximate: words * 1.3)
RAW_TOKENS=0
if [ $VERBOSE -eq 1 ]; then
  RAW_WORDS=$(echo "$RAW_TEXT" | wc -w)
  RAW_TOKENS=$((RAW_WORDS * 13 / 10))
  echo "[INFO] Raw response: ~$RAW_WORDS words (~$RAW_TOKENS tokens)" >&2
  echo "[INFO] Content type: $CONTENT_TYPE" >&2
  echo "[INFO] Max items per type: $MAX_ITEMS" >&2
fi

# Step 3: Filter using content-type-aware extractors (0 LLM tokens!)
OUTPUT=$(echo "$RAW_TEXT" | "$SCRIPT_DIR/filter-by-type.sh" "$CONTENT_TYPE" "$MAX_ITEMS" 2>/dev/null || echo "")

# Check if filter returned an error marker - auto-fallback to 'all' if not already
if [[ "$OUTPUT" == "[CONTENT_TYPE_EMPTY]"* ]]; then
  if [[ "$CONTENT_TYPE" != "all" ]]; then
    # Auto-fallback: retry with all content types
    [ $VERBOSE -eq 1 ] && echo "[INFO] No content found for '$CONTENT_TYPE', auto-retrying with 'all'..." >&2
    OUTPUT=$(echo "$RAW_TEXT" | "$SCRIPT_DIR/filter-by-type.sh" "all" "$MAX_ITEMS" 2>/dev/null || echo "")

    # If still empty after fallback, show error
    if [[ "$OUTPUT" == "[CONTENT_TYPE_EMPTY]"* ]] || [ -z "$OUTPUT" ]; then
      echo "[CONTENT_TYPE_EMPTY]"
      echo ""
      echo "No content found for requested types: $CONTENT_TYPE"
      echo "Fallback to 'all' also returned no results."
      echo ""
      echo "Library ID: $LIBRARY_ID"
      echo "Topic: $TOPIC"
      echo ""
      echo "Call budget: 1-2 of 3 calls used"
      echo "Try a broader topic or different library."
      exit 0
    fi

    # Fallback succeeded - add note about it
    [ $VERBOSE -eq 1 ] && echo "[INFO] Fallback to 'all' succeeded" >&2
    CONTENT_TYPE="all (fallback from $CONTENT_TYPE)"
  else
    # Already using 'all', no fallback possible
    echo "$OUTPUT"
    echo ""
    echo "Call budget: 1-2 of 3 calls used"
    echo "You may retry with different content-type or broader query."
    exit 0
  fi
fi

# Fallback if no content extracted
if [ -z "$OUTPUT" ]; then
  OUTPUT=$(echo "$RAW_TEXT" | head -c 1500)
  OUTPUT+="\n\n[Content truncated - no matching content types found]"
  OUTPUT+="\nTry --content-type all for unfiltered output"
fi

# Step 4: Output filtered content
echo -e "$OUTPUT"

# Show token savings in verbose mode
if [ $VERBOSE -eq 1 ]; then
  FILTERED_WORDS=$(echo -e "$OUTPUT" | wc -w)
  FILTERED_TOKENS=$((FILTERED_WORDS * 13 / 10))
  if [ "$RAW_TOKENS" -gt 0 ]; then
    SAVINGS=$(( (RAW_TOKENS - FILTERED_TOKENS) * 100 / RAW_TOKENS ))
  else
    SAVINGS=0
  fi

  echo "" >&2
  echo "[INFO] Filtered output: ~$FILTERED_WORDS words (~$FILTERED_TOKENS tokens)" >&2
  echo "[INFO] Token savings: ${SAVINGS}%" >&2
  echo "[INFO] Content types requested: $CONTENT_TYPE" >&2
fi
