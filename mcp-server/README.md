# Maccy Clipboard MCP Server

A [Model Context Protocol](https://modelcontextprotocol.io/) server that exposes the [Maccy](https://maccy.app) clipboard manager to AI agents. Claude Code, Overlord-v2, and any MCP-compatible client can read clipboard history, search, transform content, and use AI-powered text processing.

## Tools

| Tool | Description |
|------|-------------|
| `clipboard_read` | Read the current system clipboard contents |
| `clipboard_write` | Write text to the system clipboard |
| `clipboard_history` | Get recent clipboard history with metadata (app, category, copy count, timestamps) |
| `clipboard_search` | Search history by text, app name, or content category |
| `clipboard_pinned` | Get all pinned clipboard items |
| `clipboard_stats` | Usage statistics: totals, app breakdown, category distribution, most-copied items |
| `clipboard_transform` | Apply text transforms: `json`, `trim`, `upper`, `lower`, `strip_utm`, `base64_encode`, `url_encode`, `sort_lines`, `unique_lines`, and more |
| `clipboard_ai` | AI-powered transformation via Claude API — summarize, translate, explain, rewrite, etc. |
| `clipboard_context` | Structured context digest from clipboard history for agent work context |
| `clipboard_watch` | Monitor clipboard items copied in the last N minutes |

## Setup

### Prerequisites
- Node.js 20+
- Maccy (this fork) installed and running
- `ANTHROPIC_API_KEY` environment variable (for `clipboard_ai` tool)

### Install

```bash
cd mcp-server
npm install
npm run build
```

### Register with Claude Code

Add to `~/.claude.json`:

```json
{
  "mcpServers": {
    "maccy-clipboard": {
      "command": "node",
      "args": ["/path/to/Maccy/mcp-server/dist/index.js"]
    }
  }
}
```

### Register with Overlord-v2

Add to `mcp-servers.json`:

```json
{
  "name": "maccy_clipboard",
  "description": "Maccy Clipboard MCP: read/write/search clipboard history, apply transforms, AI processing",
  "command": "node",
  "args": ["/path/to/Maccy/mcp-server/dist/index.js"],
  "env": {},
  "enabled": true,
  "builtin": false
}
```

## Architecture

```
AI Agent (Claude Code / Overlord / MCP Client)
  |
  | JSON-RPC 2.0 over stdio
  v
MCP Server (Node.js)
  |
  |-- clipboard_read/write --> /usr/bin/pbpaste, /usr/bin/pbcopy
  |-- clipboard_history/search/stats/pinned --> SQLite (read-only)
  |-- clipboard_ai --> Anthropic API (Claude)
  |-- clipboard_transform --> Local text processing
  v
Maccy SQLite Database (read-only)
  ~/Library/Application Support/Maccy/Storage.sqlite
```

The server reads Maccy's SwiftData database directly in read-only mode. Write operations use macOS system clipboard tools (`pbcopy`/`pbpaste`) via `execFileSync` (no shell, no injection risk).

Handles SwiftData schema detection (Z-prefixed vs plain columns) and NSDate epoch conversion (2001-01-01 reference date).

## Examples

### From Claude Code
```
"What's on my clipboard?" → clipboard_read
"What have I been copying from Chrome?" → clipboard_search("Chrome")
"Show me my clipboard stats" → clipboard_stats
"Summarize what's on my clipboard" → clipboard_ai(instruction: "summarize")
"What's my work context?" → clipboard_context
```

### From Overlord-v2 Agents
Agents in rooms with `mcp_maccy_clipboard_*` tools can:
- Read clipboard context before starting tasks
- Copy results to clipboard for the user
- Search history for relevant code/URLs
- Transform and format text programmatically

## License

MIT
