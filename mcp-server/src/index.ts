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

import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { z } from 'zod';
import { execFileSync } from 'child_process';
import Anthropic from '@anthropic-ai/sdk';
import { ClipboardDB } from './clipboard-db.js';

const db = new ClipboardDB();
const anthropic = new Anthropic();

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

// ── Tool: clipboard_ai ──

server.tool(
  'clipboard_ai',
  `AI-powered clipboard transformation using Claude. Transforms the given text according to a natural language instruction.
Examples:
  - "summarize in 3 bullet points"
  - "translate to Spanish"
  - "explain this code"
  - "rewrite as a professional email"
  - "convert to a bash script"
  - "extract all URLs"
  - "fix the grammar"
  - "add TypeScript types"`,
  {
    text: z
      .string()
      .describe('Text to transform (or omit to use current clipboard)'),
    instruction: z
      .string()
      .describe(
        'What to do with the text — natural language instruction'
      ),
    copy_result: z
      .boolean()
      .optional()
      .default(false)
      .describe('Copy the result back to clipboard after transforming'),
  },
  async ({ text, instruction, copy_result }) => {
    try {
      // If no text provided, read from clipboard
      let inputText = text;
      if (!inputText || inputText.trim() === '') {
        try {
          inputText = execFileSync('/usr/bin/pbpaste', [], {
            encoding: 'utf-8',
            timeout: 5000,
          });
        } catch {
          return {
            content: [
              { type: 'text', text: 'Clipboard is empty and no text provided' },
            ],
            isError: true,
          };
        }
      }

      const response = await anthropic.messages.create({
        model: 'claude-sonnet-4-20250514',
        max_tokens: 4096,
        messages: [
          {
            role: 'user',
            content: `${instruction}\n\nHere is the text to work with:\n\n${inputText}`,
          },
        ],
        system:
          'You are a clipboard text transformer. Apply the user\'s instruction to the provided text. Return ONLY the transformed result — no preamble, no explanation, no markdown fences unless the content itself is code. Be precise and concise.',
      });

      const result =
        response.content[0].type === 'text' ? response.content[0].text : '';

      if (copy_result) {
        execFileSync('/usr/bin/pbcopy', [], {
          input: result,
          timeout: 5000,
        });
      }

      return {
        content: [
          {
            type: 'text',
            text: copy_result
              ? `${result}\n\n(Result copied to clipboard)`
              : result,
          },
        ],
      };
    } catch (e) {
      return {
        content: [
          {
            type: 'text',
            text: `AI transform failed: ${e instanceof Error ? e.message : String(e)}`,
          },
        ],
        isError: true,
      };
    }
  }
);

// ── Tool: clipboard_context ──

server.tool(
  'clipboard_context',
  `Build a structured context summary from clipboard history for AI agents.
Returns a digest of recent clipboard activity: what the user has been copying,
from which apps, content patterns, and frequently used items.
Useful for agents that need to understand the user's current work context.`,
  {
    window_minutes: z
      .number()
      .optional()
      .default(60)
      .describe('Look back window in minutes (default 60)'),
  },
  async ({ window_minutes }) => {
    try {
      const items = db.getHistory(100, 0);
      const cutoff = new Date(Date.now() - window_minutes * 60 * 1000);

      const recentItems = items.filter(
        (item) => item.lastCopiedAt >= cutoff
      );
      const stats = db.getStats();

      // Build structured context
      const sections: string[] = [
        `=== Clipboard Context (last ${window_minutes} min) ===`,
        ``,
        `Recent activity: ${recentItems.length} items copied`,
        ``,
      ];

      // Group by app
      const byApp: Record<string, string[]> = {};
      for (const item of recentItems) {
        const app = item.application ?? 'Unknown';
        if (!byApp[app]) byApp[app] = [];
        byApp[app].push(item.title.substring(0, 100));
      }

      if (Object.keys(byApp).length > 0) {
        sections.push('-- By Source App --');
        for (const [app, titles] of Object.entries(byApp)) {
          sections.push(`  ${app} (${titles.length} items):`);
          for (const title of titles.slice(0, 5)) {
            sections.push(`    - "${title}"`);
          }
          if (titles.length > 5) {
            sections.push(`    ... and ${titles.length - 5} more`);
          }
        }
        sections.push('');
      }

      // Group by category
      const byCat: Record<string, number> = {};
      for (const item of recentItems) {
        const cat = item.category || 'Text';
        byCat[cat] = (byCat[cat] || 0) + 1;
      }

      if (Object.keys(byCat).length > 0) {
        sections.push('-- Content Types --');
        for (const [cat, count] of Object.entries(byCat).sort(
          (a, b) => b[1] - a[1]
        )) {
          sections.push(`  ${cat}: ${count}`);
        }
        sections.push('');
      }

      // Frequently copied (cross-session)
      if (stats.topCopied.length > 0) {
        sections.push('-- Most Frequently Copied (all time) --');
        for (const item of stats.topCopied.slice(0, 5)) {
          sections.push(`  "${item.title}" (${item.count}x)`);
        }
        sections.push('');
      }

      // Pinned items
      const pinned = db.getPinned();
      if (pinned.length > 0) {
        sections.push('-- Pinned Items (user-saved) --');
        for (const item of pinned) {
          sections.push(`  [${item.pin}] "${item.title.substring(0, 100)}"`);
        }
      }

      return {
        content: [{ type: 'text', text: sections.join('\n') }],
      };
    } catch (e) {
      return {
        content: [{ type: 'text', text: `Error building context: ${e}` }],
        isError: true,
      };
    }
  }
);

// ── Tool: clipboard_watch ──

server.tool(
  'clipboard_watch',
  'Get clipboard items copied since a given timestamp. Useful for monitoring what the user copies during a work session.',
  {
    since_minutes_ago: z
      .number()
      .optional()
      .default(5)
      .describe('Get items from the last N minutes (default 5)'),
  },
  async ({ since_minutes_ago }) => {
    try {
      const items = db.getHistory(50, 0);
      const cutoff = new Date(Date.now() - since_minutes_ago * 60 * 1000);
      const recent = items.filter((item) => item.lastCopiedAt >= cutoff);

      if (recent.length === 0) {
        return {
          content: [
            {
              type: 'text',
              text: `No new clipboard items in the last ${since_minutes_ago} minutes`,
            },
          ],
        };
      }

      const formatted = recent.map((item) => {
        const ago = Math.round(
          (Date.now() - item.lastCopiedAt.getTime()) / 1000
        );
        const agoStr =
          ago < 60 ? `${ago}s ago` : `${Math.round(ago / 60)}m ago`;
        return `[${agoStr}] ${item.category || 'Text'} from ${item.application || 'Unknown'}: "${item.title.substring(0, 150)}"`;
      });

      return {
        content: [
          {
            type: 'text',
            text: `${recent.length} items in last ${since_minutes_ago}m:\n\n${formatted.join('\n')}`,
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

// ── Start Server ──

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((error) => {
  console.error('MCP server error:', error);
  process.exit(1);
});
