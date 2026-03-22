#!/usr/bin/env node
/**
 * Maccy Clipboard MCP Server
 *
 * Exposes the Maccy clipboard manager as an MCP tool server.
 * AI agents (Claude Code, Overlord-v2, etc.) can read clipboard
 * history, search, get stats, and copy/paste programmatically.
 *
 * Transport: stdio (JSON-RPC 2.0)
 *
 * Tools exposed:
 *   - clipboard_read       — Get current system clipboard contents
 *   - clipboard_write      — Write text to system clipboard
 *   - clipboard_history    — Get recent clipboard history from Maccy
 *   - clipboard_search     — Search clipboard history
 *   - clipboard_pinned     — Get pinned clipboard items
 *   - clipboard_stats      — Get clipboard usage statistics
 *   - clipboard_transform  — Apply a paste transform to text
 *   - clipboard_ai         — AI-powered clipboard transformation (Claude)
 *   - clipboard_context    — Get clipboard as structured context for agents
 *   - clipboard_watch      — Get items copied since a timestamp
 */
export {};
