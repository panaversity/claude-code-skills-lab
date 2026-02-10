#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Platform-agnostic documentation fetcher using Context7 MCP.

Replaces the bash orchestration (fetch-docs.sh + fetch-raw.sh + filter-by-type.sh
+ extract-*.sh) with a single Python script that works on Windows, macOS, Linux, WSL.

Token savings: Fetches raw docs via MCP, then filters locally (0 LLM tokens)
to return only the content types Claude needs.

Context7 API Limits: Max 3 calls per question.
This skill uses max 2 calls (resolve + query), leaving 1 for retry.
"""

import argparse
import json
import os
import re
import sys
import time

# Import mcp-client.py from same directory
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)
from importlib import import_module

# We need to import mcp-client.py which has a hyphen in the name
import importlib.util
_spec = importlib.util.spec_from_file_location("mcp_client", os.path.join(SCRIPT_DIR, "mcp-client.py"))
_mcp_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_mcp_mod)
StdioTransport = _mcp_mod.StdioTransport
MCPClient = _mcp_mod.MCPClient
MCPClientError = _mcp_mod.MCPClientError


# ─── MINGW Path Fixup ───────────────────────────────────────────────────────
# MINGW/Git Bash on Windows silently converts /foo/bar to C:/Program Files/Git/foo/bar
# This breaks library IDs like /reactjs/react.dev

def fix_mingw_path(value: str) -> str:
    """Reverse MINGW path expansion on library IDs."""
    if not value:
        return value
    # Detect MINGW-expanded paths: C:/Program Files/Git/org/project
    m = re.match(r"^[A-Z]:[/\\].*?[/\\]Git[/\\](.+)$", value, re.IGNORECASE)
    if m:
        return "/" + m.group(1).replace("\\", "/")
    # Also handle MSYS paths: /c/Program Files/Git/org/project
    m2 = re.match(r"^/[a-z]/.*?/Git/(.+)$", value, re.IGNORECASE)
    if m2:
        return "/" + m2.group(1)
    return value


# ─── API Key Loading ────────────────────────────────────────────────────────

def load_api_key() -> str:
    """Load Context7 API key from multiple sources.
    Priority: env var > project config > user config > empty
    """
    # 1. Environment variable
    key = os.environ.get("CONTEXT7_API_KEY", "")
    if key:
        return key

    # 2. Project config
    if os.path.isfile(".context7.env"):
        key = _read_key_from_file(".context7.env")
        if key:
            return key

    # 3. User config
    home_config = os.path.join(os.path.expanduser("~"), ".context7.env")
    if os.path.isfile(home_config):
        key = _read_key_from_file(home_config)
        if key:
            return key

    return ""


def _read_key_from_file(filepath: str) -> str:
    try:
        with open(filepath, "r") as f:
            for line in f:
                line = line.strip()
                if line.startswith("CONTEXT7_API_KEY="):
                    val = line.split("=", 1)[1].strip().strip("'\"")
                    if val:
                        return val
    except OSError:
        pass
    return ""


def get_api_key_source() -> str:
    if os.environ.get("CONTEXT7_API_KEY"):
        return "environment variable"
    if os.path.isfile(".context7.env"):
        if _read_key_from_file(".context7.env"):
            return "project config (.context7.env)"
    home_config = os.path.join(os.path.expanduser("~"), ".context7.env")
    if os.path.isfile(home_config):
        if _read_key_from_file(home_config):
            return "user config (~/.context7.env)"
    return "none"


def build_mcp_command() -> str:
    api_key = load_api_key()
    if api_key:
        return f"npx -y @upstash/context7-mcp --api-key {api_key}"
    return "npx -y @upstash/context7-mcp"


# ─── Content Extractors (replaces extract-*.sh) ─────────────────────────────

def extract_code_blocks(text: str, max_items: int = 5) -> str:
    """Extract code blocks between ``` markers."""
    blocks = []
    lines = text.split("\n")
    in_block = False
    block_lines = []
    lang = ""

    for line in lines:
        if line.startswith("```"):
            if in_block:
                content = "\n".join(block_lines)
                if len(content) > 20 and len(blocks) < max_items:
                    blocks.append((lang, content))
                block_lines = []
                lang = ""
                in_block = False
            else:
                in_block = True
                lang = line[3:].strip()
        elif in_block:
            block_lines.append(line)

    if not blocks:
        return ""

    parts = []
    for i, (lang, content) in enumerate(blocks, 1):
        parts.append(f"### Example {i}")
        fence = f"```{lang}" if lang else "```"
        parts.append(fence)
        parts.append(content)
        parts.append("```")
        parts.append("")
    return "\n".join(parts)


def extract_apidoc(text: str, max_items: int = 3) -> str:
    """Extract APIDOC blocks (```APIDOC ... ```)."""
    blocks = []
    lines = text.split("\n")
    in_block = False
    block_lines = []

    for line in lines:
        if line.startswith("```APIDOC"):
            in_block = True
            block_lines = []
        elif line.strip() == "```" and in_block:
            content = "\n".join(block_lines)
            if len(content) > 50 and len(blocks) < max_items:
                blocks.append(content)
            in_block = False
            block_lines = []
        elif in_block:
            block_lines.append(line)

    if not blocks:
        return ""

    parts = []
    for i, content in enumerate(blocks, 1):
        parts.append(f"### API Reference {i}")
        parts.append("")
        parts.append(content)
        parts.append("")
    return "\n".join(parts)


def extract_terminal_blocks(text: str, max_items: int = 5) -> str:
    """Extract bash/terminal/shell code blocks."""
    terminal_langs = {"bash", "terminal", "shell", "sh", "zsh", "console"}
    blocks = []
    lines = text.split("\n")
    in_block = False
    block_lines = []

    for line in lines:
        if line.startswith("```") and not in_block:
            lang = line[3:].strip().lower()
            if lang in terminal_langs:
                in_block = True
                block_lines = []
        elif line.strip() == "```" and in_block:
            content = "\n".join(block_lines)
            if len(content) > 10 and len(blocks) < max_items:
                blocks.append(content)
            in_block = False
            block_lines = []
        elif in_block:
            block_lines.append(line)

    if not blocks:
        return ""

    parts = []
    for i, content in enumerate(blocks, 1):
        parts.append(f"### Command {i}")
        parts.append("```bash")
        parts.append(content)
        parts.append("```")
        parts.append("")
    return "\n".join(parts)


def extract_prose(text: str, max_items: int = 5) -> str:
    """Extract conceptual prose paragraphs, skipping code blocks."""
    paragraphs = []
    lines = text.split("\n")
    in_code = False
    current_para = []
    output_parts = []

    for line in lines:
        if line.startswith("```"):
            in_code = not in_code
            if current_para:
                para_text = " ".join(current_para)
                if len(para_text) > 100 and len(paragraphs) < max_items:
                    paragraphs.append(para_text)
                current_para = []
            continue

        if in_code:
            continue

        # Skip rules, source lines
        if re.match(r"^---+$", line) or re.match(r"^===+$", line):
            continue
        if line.startswith("Source:"):
            continue

        # Empty line ends paragraph
        if not line.strip():
            if current_para:
                para_text = " ".join(current_para)
                if len(para_text) > 100 and len(paragraphs) < max_items:
                    paragraphs.append(para_text)
                current_para = []
            continue

        # Keep headers as context markers
        if line.startswith("###"):
            if current_para:
                para_text = " ".join(current_para)
                if len(para_text) > 100 and len(paragraphs) < max_items:
                    paragraphs.append(para_text)
                current_para = []
            if len(paragraphs) < max_items:
                output_parts.append(line)
                output_parts.append("")
            continue

        # Skip list items
        if re.match(r"^[*-] ", line) or re.match(r"^\*\*[a-zA-Z]", line):
            continue

        current_para.append(line)

    # Last paragraph
    if current_para:
        para_text = " ".join(current_para)
        if len(para_text) > 100 and len(paragraphs) < max_items:
            paragraphs.append(para_text)

    for p in paragraphs:
        output_parts.append(p)
        output_parts.append("")

    return "\n".join(output_parts)


def extract_signatures(text: str, max_items: int = 3) -> str:
    """Extract API signatures: function declarations, interfaces, types."""
    sigs = []
    for line in text.split("\n"):
        if len(sigs) >= max_items:
            break
        # Function declarations
        if re.match(r"^(export )?(async )?(function|const|let|var) [a-zA-Z_$][a-zA-Z0-9_$]*.*\(", line):
            sigs.append(f"- `{line}`")
        # Interface definitions
        elif re.match(r"^(export )?interface [a-zA-Z_$]", line):
            sigs.append(f"- `{line}`")
        # Type definitions
        elif re.match(r"^(export )?type [a-zA-Z_$][a-zA-Z0-9_$]* =", line):
            sigs.append(f"- `{line}`")

    return "\n".join(sigs)


def _extract_keyword_sections(text: str, patterns: list, max_items: int, header_prefix: str) -> str:
    """Generic extractor for keyword-triggered sections."""
    sections = []
    lines = text.split("\n")
    in_code = False
    in_section = False
    section_lines = []
    section_header = ""

    combined_pattern = re.compile("|".join(patterns), re.IGNORECASE)

    for line in lines:
        if line.startswith("```"):
            in_code = not in_code
            if in_section:
                section_lines.append(line)
            continue

        if not in_code and combined_pattern.search(line):
            # Save previous section
            if in_section and len(sections) < max_items:
                content = "\n".join(section_lines)
                if len(content) > 50:
                    sections.append((section_header, content))
            # Start new section
            section_header = re.sub(r"^#+\s*", "", line)
            section_lines = []
            in_section = True
        elif in_section:
            section_lines.append(line)

    # Last section
    if in_section and len(sections) < max_items:
        content = "\n".join(section_lines)
        if len(content) > 50:
            sections.append((section_header, content))

    if not sections:
        return ""

    parts = []
    for i, (header, content) in enumerate(sections, 1):
        parts.append(f"### {header_prefix} {i}")
        if header:
            parts.append(f"**{header}**")
            parts.append("")
        parts.append(content)
        parts.append("")
        parts.append("---")
        parts.append("")
    return "\n".join(parts)


def extract_patterns(text: str, max_items: int = 5) -> str:
    """Extract best practices and design pattern sections."""
    keywords = [
        r"[Bb]est [Pp]ractice", r"[Pp]attern", r"[Rr]ecommend",
        r"[Ss]hould [Nn]ot", r"[Aa]void", r"[Pp]refer",
        r"[Ii]diomatic", r"[Cc]onvention", r"[Gg]uideline",
    ]
    return _extract_keyword_sections(text, keywords, max_items, "Pattern")


def extract_migration(text: str, max_items: int = 5) -> str:
    """Extract migration-related content."""
    keywords = [
        r"[Bb]reaking [Cc]hange", r"[Mm]igrat", r"[Uu]pgrad", r"[Vv]ersion [0-9]",
    ]
    return _extract_keyword_sections(text, keywords, max_items, "Migration")


def extract_troubleshooting(text: str, max_items: int = 5) -> str:
    """Extract troubleshooting content."""
    keywords = [
        r"[Ww]orkaround", r"[Tt]emporary", r"[Dd]ebug", r"[Tt]roubleshoot",
        r"[Ff]ix(?:ing)?\s", r"[Ee]rror\s", r"[Ww]arning",
        r"[Ii]ssue", r"[Pp]roblem", r"[Ss]olution",
    ]
    return _extract_keyword_sections(text, keywords, max_items, "Troubleshooting")


def extract_notes(text: str, max_items: int = 3) -> str:
    """Extract important notes and warnings."""
    pattern = re.compile(
        r"(important|note:|warning:|caution:|tip:|remember:|must|should not|deprecated|breaking change)",
        re.IGNORECASE,
    )
    notes = []
    for line in text.split("\n"):
        if len(notes) >= max_items:
            break
        if pattern.search(line):
            notes.append(f"- {line.strip()}")

    return "\n".join(notes) if notes else ""


# ─── Content Filter Orchestrator (replaces filter-by-type.sh) ────────────────

def filter_by_type(text: str, content_types: str, max_items: int = 5) -> str:
    """Route content through appropriate extractors based on content types."""
    if not text:
        return "# No content to filter"

    if content_types == "all":
        return text

    output_parts = []
    types = [t.strip() for t in content_types.split(",")]

    extractors = {
        "examples": ("## Code Examples", extract_code_blocks, "# No code blocks found"),
        "api-ref": None,  # Special handling below
        "setup": ("## Setup & Installation", extract_terminal_blocks, "# No terminal blocks found"),
        "concepts": ("## Concepts", extract_prose, None),
        "migration": ("## Migration Guide", extract_migration, None),
        "troubleshooting": ("## Troubleshooting", extract_troubleshooting, None),
        "patterns": ("## Best Practices", extract_patterns, None),
        "notes": ("## Important Notes", extract_notes, "- No important notes found"),
    }

    for ctype in types:
        if ctype == "api-ref":
            # Special: APIDOC blocks + signatures
            apidoc = extract_apidoc(text, max_items)
            if apidoc:
                output_parts.append("## API Documentation\n")
                output_parts.append(apidoc)
                output_parts.append("")
            sigs = extract_signatures(text, max_items)
            if sigs:
                output_parts.append("## API Signatures\n")
                output_parts.append(sigs)
                output_parts.append("")
        elif ctype in extractors:
            heading, extractor, empty_marker = extractors[ctype]
            result = extractor(text, max_items)
            if result and result != empty_marker:
                output_parts.append(f"{heading}\n")
                output_parts.append(result)
                output_parts.append("")
        else:
            print(f"[WARNING] Unknown content type: {ctype}", file=sys.stderr)

    if not output_parts:
        return f"[CONTENT_TYPE_EMPTY]\n\nNo content found for requested types: {content_types}\n\nAvailable types: examples, api-ref, setup, concepts, migration, troubleshooting, patterns, notes, all"

    return "\n".join(output_parts)


# ─── MCP Fetch with Retry (replaces fetch-raw.sh) ───────────────────────────

RETRYABLE_PATTERNS = [
    "Timeout", "timeout", "ETIMEDOUT", "ECONNREFUSED", "ECONNRESET",
    "Connection", "connection", "Network", "network",
]

RETRY_DELAYS = [2, 5, 10]


def is_retryable(error_msg: str) -> bool:
    return any(p in error_msg for p in RETRYABLE_PATTERNS)


def check_api_errors(error_msg: str, has_key: bool) -> str:
    """Check for non-retryable API errors. Returns error message or empty string."""
    if any(p in error_msg for p in ["rate limit", "429", "Too many requests"]):
        msg = "[RATE_LIMIT_ERROR]\n\nContext7 rate limit exceeded.\n\nCall budget: This counts against your 3-call limit."
        if not has_key:
            msg += "\n\n" + API_KEY_MISSING_MSG
        else:
            msg += "\nYour API key may have exceeded its quota. Check: https://context7.com/dashboard"
        return msg

    if any(p in error_msg for p in ["unauthorized", "Unauthorized", "API key", "authentication"]):
        msg = "[AUTH_ERROR]\n\nAuthentication failed with Context7."
        if not has_key:
            msg += "\n\n" + API_KEY_MISSING_MSG
        else:
            msg += "\nYour API key may be invalid. Get a new one at: https://context7.com/dashboard"
        return msg

    return ""


API_KEY_MISSING_MSG = """[CONTEXT7_API_KEY_MISSING]

Context7 API key is not configured.

## How to Fix

Save your API key using one of these methods:

**Option 1:** Save to config file
```bash
echo "CONTEXT7_API_KEY=<your_key>" > ~/.context7.env
```

**Option 2:** Set environment variable (temporary)
```bash
export CONTEXT7_API_KEY=<your_key>
```

Get a free API key at: https://context7.com/dashboard
The API key starts with `ctx7sk_` or `ctx7sk-`"""


def fetch_raw(mcp_cmd: str, library_id: str, topic: str, has_key: bool) -> str:
    """Fetch raw documentation from Context7 MCP with retry logic."""
    params = {"libraryId": library_id, "query": topic}

    last_error = ""
    for attempt in range(len(RETRY_DELAYS)):
        try:
            transport = StdioTransport(mcp_cmd)
            client = MCPClient(transport)
            result = client.call_tool("query-docs", params)
            if hasattr(transport, "close"):
                transport.close()
            return json.dumps(result)
        except MCPClientError as e:
            last_error = str(e)
            if hasattr(transport, "close"):
                transport.close()
        except Exception as e:
            last_error = str(e)
            try:
                transport.close()
            except Exception:
                pass

        # Check for non-retryable API errors
        api_err = check_api_errors(last_error, has_key)
        if api_err:
            print(api_err)
            sys.exit(1)

        # Only retry infrastructure failures
        if is_retryable(last_error) and attempt < len(RETRY_DELAYS) - 1:
            delay = RETRY_DELAYS[attempt]
            print(f"[RETRY] Attempt {attempt + 1} failed (infrastructure error), retrying in {delay}s...", file=sys.stderr)
            time.sleep(delay)
        elif not is_retryable(last_error):
            break

    # All retries exhausted
    if is_retryable(last_error):
        print(f"[FETCH_FAILED_AFTER_RETRIES]\n\nMCP call failed after {len(RETRY_DELAYS)} attempts.\n\nLast error: {last_error}\n\nThis does NOT count against your Context7 call budget.")
    else:
        print(f"[FETCH_ERROR]\n\nFailed to fetch documentation from Context7.\n\nError details: {last_error}")
    sys.exit(1)


# ─── Library Resolution ─────────────────────────────────────────────────────

def resolve_library(mcp_cmd: str, library_name: str, topic: str) -> tuple:
    """Resolve library name to Context7 ID. Returns (library_id, library_title)."""
    params = {"query": topic or "documentation", "libraryName": library_name}

    try:
        transport = StdioTransport(mcp_cmd)
        client = MCPClient(transport)
        result = client.call_tool("resolve-library-id", params)
        if hasattr(transport, "close"):
            transport.close()
    except MCPClientError as e:
        print(f"[RESOLVE_ERROR]\n\nFailed to resolve library name: {library_name}\n\nError: {e}")
        sys.exit(1)

    # Extract text from result
    resolve_text = ""
    try:
        content = result.get("content", [{}])
        if content:
            resolve_text = content[0].get("text", "")
    except (IndexError, AttributeError):
        pass

    # Extract library ID
    m = re.search(r"Context7-compatible library ID:\s*([/\w.-]+)", resolve_text)
    library_id = m.group(1) if m else ""

    # Extract title
    m2 = re.search(r"^\d+\.\s*(.+)", resolve_text, re.MULTILINE)
    library_title = m2.group(1) if m2 else ""

    return library_id, library_title


def validate_library_match(library_name: str, library_id: str, library_title: str) -> bool:
    """Check if resolved library matches user's intent."""
    name_lower = library_name.lower()
    id_lower = library_id.lower()
    title_lower = library_title.lower()

    if name_lower in id_lower or name_lower in title_lower:
        return True

    # Check variations (strip punctuation)
    name_clean = re.sub(r"[.\-_ ]", "", name_lower)
    id_clean = re.sub(r"[.\-_ ]", "", id_lower)
    if name_clean in id_clean:
        return True

    return False


# ─── Main ────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Token-efficient documentation fetcher using Context7 MCP",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Content Type Examples:
  --content-type examples              Code examples only
  --content-type api-ref               API signatures and documentation
  --content-type examples,api-ref      Both code examples AND API reference
  --content-type setup                 Installation/terminal commands
  --content-type concepts,examples     Explanations with code examples
  --content-type migration             Before/after, breaking changes
  --content-type troubleshooting       Workarounds, debugging tips
  --content-type all                   No filtering, return everything

Usage Examples:
  %(prog)s --library react --topic useState --content-type examples
  %(prog)s --library-id /vercel/next.js --topic routing --content-type examples,api-ref
  %(prog)s --library prisma --topic "getting started" --content-type setup
""",
    )

    group = parser.add_mutually_exclusive_group()
    group.add_argument("--library-id", help="Context7 library ID (e.g., /reactjs/react.dev) - saves 1 API call")
    group.add_argument("--library", help="Library name (will resolve to ID) - uses 1 extra API call")

    parser.add_argument("--topic", default="", help="Topic to focus on (e.g., hooks, routing)")
    parser.add_argument("--content-type", default="examples", help="Content types (comma-separated, default: examples)")
    parser.add_argument("--max-items", type=int, default=5, help="Max items per content type (default: 5)")
    parser.add_argument("--mode", default="", help="Legacy mode: code -> examples, info -> concepts,examples")
    parser.add_argument("-v", "--verbose", action="store_true", help="Show token statistics")
    parser.add_argument("--api-status", action="store_true", help="Check API key configuration status")

    args = parser.parse_args()

    # --- API status ---
    if args.api_status:
        print("Context7 API Key Status")
        print("=======================")
        print()
        api_key = load_api_key()
        if api_key:
            masked = api_key[:12] + "..." + api_key[-4:]
            print(f"Status: CONFIGURED")
            print(f"Key: {masked}")
            print(f"Source: {get_api_key_source()}")
        else:
            print("Status: NOT CONFIGURED")
            print()
            print('To configure, save your API key:')
            print('  echo "CONTEXT7_API_KEY=your_key" > ~/.context7.env')
            print()
            print("Get a free API key at: https://context7.com/dashboard")
        return

    # --- Build MCP command ---
    mcp_cmd = build_mcp_command()
    has_key = bool(load_api_key())
    content_type = args.content_type
    content_type_set = args.content_type != "examples"

    # Legacy --mode mapping
    if args.mode and not content_type_set:
        if args.mode == "code":
            content_type = "examples,api-ref"
        elif args.mode == "info":
            content_type = "concepts,examples"

    if args.verbose:
        src = get_api_key_source()
        if has_key:
            print(f"[INFO] API Key: configured ({src})", file=sys.stderr)
        else:
            print("[WARNING] API Key: not configured", file=sys.stderr)

    # --- Resolve library name ---
    library_id = fix_mingw_path(args.library_id or "")
    library_name = args.library or ""

    if library_name and not library_id:
        if args.verbose:
            print(f"[INFO] Resolving library: {library_name}", file=sys.stderr)

        library_id, library_title = resolve_library(mcp_cmd, library_name, args.topic)

        if not library_id:
            print("[LIBRARY_NOT_FOUND]")
            print()
            print(f"Could not find library: {library_name}")
            print()
            print("Call budget: 1 of 3 calls used (resolution attempt)")
            print()
            print("Try:")
            print("  - Different spelling (e.g., 'nextjs' instead of 'next.js')")
            print("  - Using --library-id with exact ID")
            print()
            print("Common library IDs:")
            print("  React:    /reactjs/react.dev")
            print("  Next.js:  /vercel/next.js")
            print("  Express:  /expressjs/express")
            print("  Prisma:   /prisma/docs")
            sys.exit(1)

        if not validate_library_match(library_name, library_id, library_title):
            print("[LIBRARY_MISMATCH]")
            print()
            print(f"Warning: '{library_name}' resolved to an unexpected library.")
            print()
            print(f"Resolved library: {library_title}")
            print(f"Library ID: {library_id}")
            print()
            print("This may not be what you're looking for.")
            print()
            print("Call budget: 1 of 3 calls used")
            print()
            print("Options:")
            print("  1. Try a different spelling of the library name")
            print("  2. Use --library-id with the exact ID if this is correct")
            print("  3. Check common library IDs below")
            print()
            print("Common library IDs:")
            print("  React:     /reactjs/react.dev")
            print("  Next.js:   /vercel/next.js")
            print("  Express:   /expressjs/express")
            print("  Prisma:    /prisma/docs")
            print("  FastAPI:   /fastapi/fastapi")
            print("  LangChain: /langchain-ai/langchainjs")
            sys.exit(1)

        if args.verbose:
            print(f"[INFO] Resolved to: {library_id} ({library_title})", file=sys.stderr)

    # --- Validate library ID ---
    if not library_id:
        print("[MISSING_ARGUMENT]")
        print()
        print("Must specify --library-id or --library")
        print()
        print("Examples:")
        print("  --library react --topic hooks")
        print("  --library-id /reactjs/react.dev --topic useState")
        sys.exit(1)

    # Validate format if provided directly (not resolved)
    if not library_name:
        if not re.match(r"^/[a-zA-Z0-9_-]+/[a-zA-Z0-9_.-]+(/[a-zA-Z0-9_.-]+)?$", library_id):
            print("[INVALID_LIBRARY_ID]")
            print()
            print(f"Invalid library ID format: {library_id}")
            print()
            print("Library ID must be in format: /org/project or /org/project/version")
            print()
            print("Examples:")
            print("  /reactjs/react.dev")
            print("  /vercel/next.js")
            print("  /vercel/next.js/v14.3.0")
            print()
            print("Call budget: 0 calls used (validation failed before API call)")
            print("Use --library <name> to auto-resolve, or correct the ID format.")
            sys.exit(1)
        if args.verbose:
            print(f"[INFO] Using provided library ID: {library_id} (saves 1 API call)", file=sys.stderr)

    # --- Fetch raw documentation ---
    if args.verbose:
        print("[INFO] Fetching documentation...", file=sys.stderr)

    raw_json = fetch_raw(mcp_cmd, library_id, args.topic or "documentation", has_key)

    # Extract text from JSON
    raw_text = ""
    try:
        data = json.loads(raw_json)
        content = data.get("content", [{}])
        if content:
            raw_text = content[0].get("text", "")
    except (json.JSONDecodeError, IndexError, AttributeError):
        pass

    if not raw_text:
        print("[EMPTY_RESULTS]")
        print()
        print("No documentation found for this query.")
        print()
        print(f"Library ID: {library_id}")
        print(f"Topic: {args.topic}")
        print()
        print("Call budget: 2 of 3 calls used (resolution + query)")
        print("You have 1 call remaining for this question.")
        print()
        print("Suggestions:")
        print("  1. Try a broader topic (e.g., 'hooks' instead of 'useCustomHook')")
        print("  2. Try different content-type (e.g., --content-type all)")
        print("  3. Verify the library ID is correct")
        print("  4. Use the remaining call budget wisely")
        sys.exit(1)

    # --- Token stats ---
    raw_tokens = 0
    if args.verbose:
        raw_words = len(raw_text.split())
        raw_tokens = int(raw_words * 1.3)
        print(f"[INFO] Raw response: ~{raw_words} words (~{raw_tokens} tokens)", file=sys.stderr)
        print(f"[INFO] Content type: {content_type}", file=sys.stderr)
        print(f"[INFO] Max items per type: {args.max_items}", file=sys.stderr)

    # --- Filter content ---
    output = filter_by_type(raw_text, content_type, args.max_items)

    # Auto-fallback to 'all' if specific type returned empty
    if output.startswith("[CONTENT_TYPE_EMPTY]") and content_type != "all":
        if args.verbose:
            print(f"[INFO] No content found for '{content_type}', auto-retrying with 'all'...", file=sys.stderr)
        output = filter_by_type(raw_text, "all", args.max_items)

        if output.startswith("[CONTENT_TYPE_EMPTY]") or not output:
            print("[CONTENT_TYPE_EMPTY]")
            print()
            print(f"No content found for requested types: {content_type}")
            print("Fallback to 'all' also returned no results.")
            print()
            print(f"Library ID: {library_id}")
            print(f"Topic: {args.topic}")
            print()
            print("Call budget: 1-2 of 3 calls used")
            print("Try a broader topic or different library.")
            return

        if args.verbose:
            print("[INFO] Fallback to 'all' succeeded", file=sys.stderr)
        content_type = f"all (fallback from {content_type})"

    # Fallback if no content extracted
    if not output:
        output = raw_text[:1500]
        output += "\n\n[Content truncated - no matching content types found]"
        output += "\nTry --content-type all for unfiltered output"

    # --- Output ---
    print(output)

    # Token savings
    if args.verbose:
        filtered_words = len(output.split())
        filtered_tokens = int(filtered_words * 1.3)
        savings = ((raw_tokens - filtered_tokens) * 100 // raw_tokens) if raw_tokens > 0 else 0
        print(file=sys.stderr)
        print(f"[INFO] Filtered output: ~{filtered_words} words (~{filtered_tokens} tokens)", file=sys.stderr)
        print(f"[INFO] Token savings: {savings}%", file=sys.stderr)
        print(f"[INFO] Content types requested: {content_type}", file=sys.stderr)


if __name__ == "__main__":
    main()
