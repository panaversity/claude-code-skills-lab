#!/bin/bash
# Stop Context7 MCP server
# Usage: ./stop-server.sh [port]
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

# Cross-platform process kill
kill_process() {
    local pid="$1"
    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "mingw"* || "$OSTYPE" == "cygwin" ]]; then
        taskkill //PID "$pid" //F 2>/dev/null
    else
        kill "$pid" 2>/dev/null
        sleep 1
        # Force kill if still running
        kill -9 "$pid" 2>/dev/null || true
    fi
}

# Cross-platform find-and-kill by name
kill_by_name() {
    local pattern="$1"
    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "mingw"* || "$OSTYPE" == "cygwin" ]]; then
        taskkill //F //IM "node.exe" 2>/dev/null && echo "Context7 MCP stopped" || echo "Context7 MCP not running"
    else
        pkill -f "$pattern" 2>/dev/null && echo "Context7 MCP stopped" || echo "Context7 MCP not running"
    fi
}

if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE" 2>/dev/null)
    if [ -n "$PID" ] && is_process_running "$PID"; then
        kill_process "$PID"
        echo "Context7 MCP stopped (was PID: $PID)"
    else
        echo "Context7 MCP not running (stale PID file)"
    fi
    rm -f "$PID_FILE"
else
    # Try to find and kill by process name
    kill_by_name "context7-mcp.*--port.*${PORT}"
fi
