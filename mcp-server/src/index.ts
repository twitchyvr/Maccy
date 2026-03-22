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
 */

import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { z } from 'zod';
import { execFileSync } from 'child_process';
import { ClipboardDB } from './clipboard-db.js';

const db = new ClipboardDB();

// ── Paste Transforms (mirrored from Swift PasteTransform.swift) ──

const transforms: Record<string, (text: string) => string> = {
  json: (text) => {
    try {
      return JSON.stringify(JSON.parse(text), null, 2);
    } catch {
      return text;
    }
  },
  json_compact: (text) => {
    try {
      return JSON.stringify(JSON.parse(text));
    } catch {
      return text;
    }
  },
  upper: (text) => text.toUpperCase(),
  lower: (text) => text.toLowerCase(),
  title: (text) =>
    text.replace(
      /\w\S*/g,
      (t) => t.charAt(0).toUpperCase() + t.slice(1).toLowerCase()
    ),
  trim: (text) =>
    text
      .split('\n')
      .map((l) => l.trim())
      .filter((l) => l.length > 0)
      .join('\n'),
  single_line: (text) =>
    text
      .split('\n')
      .map((l) => l.trim())
      .filter((l) => l.length > 0)
      .join(' '),
  strip_utm: (text) => {
    try {
      const url = new URL(text.trim());
      const trackingPrefixes = [
        'utm_',
        'fbclid',
        'gclid',
        'mc_',
        'ref',
        'source',
        'campaign',
      ];
      for (const key of [...url.searchParams.keys()]) {
        if (trackingPrefixes.some((p) => key.startsWith(p))) {
          url.searchParams.delete(key);
        }
      }
      return url.toString();
    } catch {
      return text;
    }
  },
  base64_encode: (text) => Buffer.from(text).toString('base64'),
  base64_decode: (text) => {
    try {
      return Buffer.from(text.trim(), 'base64').toString('utf-8');
    } catch {
      return text;
    }
  },
  url_encode: (text) => encodeURIComponent(text),
  url_decode: (text) => {
    try {
      return decodeURIComponent(text);
    } catch {
      return text;
    }
  },
  escape: (text) =>
    text
      .replace(/\\/g, '\\\\')
      .replace(/"/g, '\\"')
      .replace(/\n/g, '\\n')
      .replace(/\t/g, '\\t'),
  unescape: (text) =>
    text
      .replace(/\\n/g, '\n')
      .replace(/\\t/g, '\t')
      .replace(/\\"/g, '"')
      .replace(/\\\\/g, '\\'),
  sort_lines: (text) => text.split('\n').sort().join('\n'),
  unique_lines: (text) => [...new Set(text.split('\n'))].join('\n'),
  reverse: (text) => text.split('').reverse().join(''),
  count: (text) => {
    const chars = text.length;
    const words = text.split(/\s+/).filter((w) => w.length > 0).length;
    const lines = text.split('\n').length;
    return `${chars} chars, ${words} words, ${lines} lines`;
  },
  strip_markdown: (text) =>
    text
      .replace(/#{1,6}\s+/g, '')
      .replace(/[*_]{1,3}([^*_]+)[*_]{1,3}/g, '$1')
      .replace(/`([^`]+)`/g, '$1')
      .replace(/\[([^\]]+)\]\([^)]+\)/g, '$1')
      .replace(/!\[([^\]]*)\]\([^)]+\)/g, '$1'),
};

// ── MCP Server Setup ──

const server = new McpServer({
  name: 'maccy-clipboard',
  version: '1.0.0',
});

// ── Tool: clipboard_read ──

server.tool(
  'clipboard_read',
  'Read the current system clipboard contents',
  {},
  async () => {
    try {
      // execFileSync with no shell — safe, no injection possible
      const content = execFileSync('/usr/bin/pbpaste', [], {
        encoding: 'utf-8',
        timeout: 5000,
      });
      return {
        content: [{ type: 'text', text: content }],
      };
    } catch {
      return {
        content: [
          {
            type: 'text',
            text: '(clipboard is empty or contains non-text data)',
          },
        ],
      };
    }
  }
);

// ── Tool: clipboard_write ──

server.tool(
  'clipboard_write',
  'Write text to the system clipboard',
  { text: z.string().describe('Text to copy to clipboard') },
  async ({ text }) => {
    try {
      // execFileSync with no shell — text passed via stdin, safe
      execFileSync('/usr/bin/pbcopy', [], {
        input: text,
        timeout: 5000,
      });
      return {
        content: [
          {
            type: 'text',
            text: `Copied ${text.length} characters to clipboard`,
          },
        ],
      };
    } catch (e) {
      return {
        content: [
          { type: 'text', text: `Failed to write to clipboard: ${e}` },
        ],
        isError: true,
      };
    }
  }
);

// ── Tool: clipboard_history ──

server.tool(
  'clipboard_history',
  'Get recent clipboard history from Maccy. Returns titles, apps, categories, copy counts, and timestamps.',
  {
    limit: z
      .number()
      .optional()
      .default(20)
      .describe('Max items to return (default 20)'),
    offset: z
      .number()
      .optional()
      .default(0)
      .describe('Skip first N items for pagination'),
  },
  async ({ limit, offset }) => {
    try {
      const items = db.getHistory(limit, offset);
      const formatted = items.map((item, i) => {
        const parts = [
          `${offset + i + 1}. "${item.title.substring(0, 200)}"`,
          item.application ? `   App: ${item.application}` : null,
          item.category ? `   Category: ${item.category}` : null,
          item.numberOfCopies > 1
            ? `   Copied ${item.numberOfCopies} times`
            : null,
          `   Last: ${item.lastCopiedAt.toLocaleString()}`,
          item.pin ? `   Pinned (${item.pin})` : null,
        ];
        return parts.filter(Boolean).join('\n');
      });

      return {
        content: [
          {
            type: 'text',
            text:
              formatted.length > 0
                ? formatted.join('\n\n')
                : 'No clipboard history found. Is Maccy running?',
          },
        ],
      };
    } catch (e) {
      return {
        content: [{ type: 'text', text: `Error reading history: ${e}` }],
        isError: true,
      };
    }
  }
);

// ── Tool: clipboard_search ──

server.tool(
  'clipboard_search',
  'Search Maccy clipboard history by text, app name, or category (URL, Code, Email, etc.)',
  {
    query: z
      .string()
      .describe('Search query — matches title, app name, or category'),
    limit: z
      .number()
      .optional()
      .default(10)
      .describe('Max results (default 10)'),
  },
  async ({ query, limit }) => {
    try {
      const items = db.search(query, limit);
      const formatted = items.map((item, i) => {
        const parts = [
          `${i + 1}. "${item.title.substring(0, 200)}"`,
          item.application ? `   App: ${item.application}` : null,
          item.category ? `   Category: ${item.category}` : null,
          `   Copied ${item.numberOfCopies}x | Last: ${item.lastCopiedAt.toLocaleString()}`,
        ];
        return parts.filter(Boolean).join('\n');
      });

      return {
        content: [
          {
            type: 'text',
            text:
              formatted.length > 0
                ? `Found ${items.length} results for "${query}":\n\n${formatted.join('\n\n')}`
                : `No results for "${query}"`,
          },
        ],
      };
    } catch (e) {
      return {
        content: [{ type: 'text', text: `Search error: ${e}` }],
        isError: true,
      };
    }
  }
);

// ── Tool: clipboard_pinned ──

server.tool(
  'clipboard_pinned',
  'Get all pinned clipboard items from Maccy',
  {},
  async () => {
    try {
      const items = db.getPinned();
      const formatted = items.map((item) => {
        return `[${item.pin}] "${item.title.substring(0, 200)}" (${item.numberOfCopies}x)`;
      });

      return {
        content: [
          {
            type: 'text',
            text: formatted.length > 0 ? formatted.join('\n') : 'No pinned items',
          },
        ],
      };
    } catch (e) {
      return {
        content: [{ type: 'text', text: `Error: ${e}` }],
        isError: true,
      };
    }
  }
);

// ── Tool: clipboard_stats ──

server.tool(
  'clipboard_stats',
  'Get clipboard usage statistics — total items, copy counts, app breakdown, category distribution, most-copied items',
  {},
  async () => {
    try {
      const stats = db.getStats();
      const duplicateRate =
        stats.totalCopies > 0
          ? (
              ((stats.totalCopies - stats.totalItems) / stats.totalCopies) *
              100
            ).toFixed(1)
          : '0';

      const lines = [
        `Clipboard Statistics`,
        ``,
        `Total items: ${stats.totalItems}`,
        `Total copies: ${stats.totalCopies}`,
        `Duplicate rate: ${duplicateRate}%`,
        `Unique apps: ${stats.uniqueApps}`,
        ``,
        `-- Content Types --`,
        ...Object.entries(stats.categoryBreakdown).map(
          ([cat, count]) => `  ${cat}: ${count}`
        ),
        ``,
        `-- Top Apps --`,
        ...Object.entries(stats.appBreakdown).map(
          ([app, count]) => `  ${app}: ${count}`
        ),
        ``,
        `-- Most Copied --`,
        ...stats.topCopied.map(
          (item, i) => `  ${i + 1}. "${item.title}" (${item.count}x)`
        ),
      ];

      return {
        content: [{ type: 'text', text: lines.join('\n') }],
      };
    } catch (e) {
      return {
        content: [{ type: 'text', text: `Error: ${e}` }],
        isError: true,
      };
    }
  }
);

// ── Tool: clipboard_transform ──

server.tool(
  'clipboard_transform',
  `Apply a paste transform to text. Available transforms: ${Object.keys(transforms).join(', ')}`,
  {
    text: z.string().describe('Text to transform'),
    transform: z
      .string()
      .describe(
        `Transform name: ${Object.keys(transforms).join(', ')}`
      ),
  },
  async ({ text, transform: name }) => {
    const fn = transforms[name];
    if (!fn) {
      return {
        content: [
          {
            type: 'text',
            text: `Unknown transform "${name}". Available: ${Object.keys(transforms).join(', ')}`,
          },
        ],
        isError: true,
      };
    }

    const result = fn(text);
    return {
      content: [{ type: 'text', text: result }],
    };
  }
);

// ── Start Server ──

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((error) => {
  console.error('MCP server error:', error);
  process.exit(1);
});
