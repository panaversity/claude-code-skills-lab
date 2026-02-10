#!/bin/bash
# Fetch raw documentation from Context7 MCP
# Output: JSON response (stays in shell, doesn't enter Claude context)
# Errors: Returns structured error messages for Claude to handle
#
# Retry Policy (respects Context7's 3-call limit):
# - ONLY retry for infrastructure failures (timeout, network) - doesn't count against limit
# - DO NOT retry for API errors (rate limit, auth, empty) - these count against limit
# - Exponential backoff: 2s, 5s, 10s

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load helpers
source "$SCRIPT_DIR/load-api-key.sh"

# Retry configuration
MAX_RETRIES=3
RETRY_DELAYS=(2 5 10)  # seconds - exponential backoff

# Detect Python command
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

LIBRARY_ID="${1:?Error: Library ID required}"
TOPIC="${2:-documentation}"
MODE="${3:-code}"
PAGE="${4:-1}"

# Build MCP command with API key (if available)
MCP_CMD=$(build_mcp_command)

# Build parameters JSON for query-docs
# Required: libraryId and query
PARAMS=$(cat <<JSON
{
  "libraryId": "$LIBRARY_ID",
  "query": "$TOPIC"
}
JSON
)

# Function to check if error is retryable (infrastructure failure)
is_retryable_error() {
  local output="$1"
  # Timeout and connection errors are retryable (infrastructure failures)
  if [[ "$output" == *"Timeout"* ]] || \
     [[ "$output" == *"timeout"* ]] || \
     [[ "$output" == *"ETIMEDOUT"* ]] || \
     [[ "$output" == *"ECONNREFUSED"* ]] || \
     [[ "$output" == *"ECONNRESET"* ]] || \
     [[ "$output" == *"Connection"* ]] || \
     [[ "$output" == *"connection"* ]] || \
     [[ "$output" == *"Network"* ]] || \
     [[ "$output" == *"network"* ]]; then
    return 0  # true - retryable
  fi
  return 1  # false - not retryable
}

# Function to check for API-level errors (NOT retryable - count against limit)
check_api_errors() {
  local output="$1"
  local exit_code="$2"

  # Rate limit error
  if [[ "$output" == *"rate limit"* ]] || [[ "$output" == *"429"* ]] || [[ "$output" == *"Too many requests"* ]]; then
    echo "[RATE_LIMIT_ERROR]"
    echo ""
    echo "Context7 rate limit exceeded."
    echo ""
    echo "Call budget: This counts against your 3-call limit."
    if ! has_api_key; then
      echo ""
      api_key_error_message
    else
      echo "Your API key may have exceeded its quota. Check: https://context7.com/dashboard"
    fi
    exit 1
  fi

  # Auth error
  if [[ "$output" == *"unauthorized"* ]] || [[ "$output" == *"Unauthorized"* ]] || [[ "$output" == *"API key"* ]] || [[ "$output" == *"authentication"* ]]; then
    echo "[AUTH_ERROR]"
    echo ""
    echo "Authentication failed with Context7."
    if ! has_api_key; then
      api_key_error_message
    else
      echo "Your API key may be invalid. Get a new one at: https://context7.com/dashboard"
    fi
    exit 1
  fi

  # No API key check - removed to allow operation without key
}

# Main fetch logic with retry for infrastructure failures
OUTPUT=""
EXIT_CODE=0
ATTEMPT=0
SUCCESS=0

while [ $ATTEMPT -lt $MAX_RETRIES ]; do
  ATTEMPT=$((ATTEMPT + 1))

  # Call MCP server
  OUTPUT=$("$PYTHON_CMD" "$SCRIPT_DIR/mcp-client.py" call \
    -s "$MCP_CMD" \
    -t query-docs \
    -p "$PARAMS" 2>&1) && {
    # Success!
    SUCCESS=1
    break
  }

  EXIT_CODE=$?

  # Check if it's an API-level error (don't retry these)
  check_api_errors "$OUTPUT" "$EXIT_CODE"

  # Check if it's a retryable infrastructure error
  if is_retryable_error "$OUTPUT"; then
    if [ $ATTEMPT -lt $MAX_RETRIES ]; then
      DELAY=${RETRY_DELAYS[$((ATTEMPT - 1))]}
      echo "[RETRY] Attempt $ATTEMPT failed (infrastructure error), retrying in ${DELAY}s..." >&2
      sleep $DELAY
      continue
    fi
  else
    # Non-retryable, non-API error - fail immediately
    break
  fi
done

# Check final result
if [ $SUCCESS -eq 0 ]; then
  # All retries exhausted or non-retryable error
  if is_retryable_error "$OUTPUT"; then
    echo "[FETCH_FAILED_AFTER_RETRIES]"
    echo ""
    echo "MCP call failed after $MAX_RETRIES attempts due to infrastructure issues."
    echo ""
    echo "Last error: $OUTPUT"
    echo ""
    echo "This does NOT count against your Context7 call budget."
    echo "The service may be temporarily unavailable. Try again later."
  else
    echo "[FETCH_ERROR]"
    echo ""
    echo "Failed to fetch documentation from Context7."
    echo ""
    echo "Error details: $OUTPUT"
    echo "Exit code: $EXIT_CODE"
  fi
  exit 1
fi

# Success - output the JSON
echo "$OUTPUT"
