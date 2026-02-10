#!/bin/bash
# Start Context7 MCP server for fetch-library-docs skill
# Usage: ./start-server.sh [port]
# Cross-platform: Works on Windows (MINGW/Git Bash), macOS, Linux, WSL

PORT=${1:-8809}

# Cross-platform temp directory
TEMP_DIR="${TMPDIR:-${TMP:-${TEMP:-/tmp}}}"
PID_FILE="${TEMP_DIR}/context7-mcp-${PORT}.pid"

# Cross-platform process check
is_process_running() {
    local pid="$1"
    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "mingw"* || "$OSTYPE" == "cygwin" ]]; then
        tasklist //FI "PID eq $pid" 2>/dev/null | grep -q "$pid" 2>/dev/null
    else
        kill -0 "$pid" 2>/dev/null
    fi
}

# Check if already running
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE" 2>/dev/null)
    if [ -n "$OLD_PID" ] && is_process_running "$OLD_PID"; then
        echo "Context7 MCP already running on port $PORT (PID: $OLD_PID)"
        exit 0
    fi
fi

# Start server
npx -y @upstash/context7-mcp --port "$PORT" &
echo $! > "$PID_FILE"

sleep 2

NEW_PID=$(cat "$PID_FILE" 2>/dev/null)
if [ -n "$NEW_PID" ] && is_process_running "$NEW_PID"; then
    echo "Context7 MCP started on port $PORT (PID: $NEW_PID)"
else
    echo "Failed to start Context7 MCP"
    rm -f "$PID_FILE"
    exit 1
fi
