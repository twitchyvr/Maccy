# Maccy Fork — AI-Enhanced Clipboard Manager

This is a custom fork of [Maccy](https://github.com/p0deje/Maccy) by [@twitchyvr](https://github.com/twitchyvr), adding AI-powered clipboard intelligence, paste transforms, and MCP server integration for AI agents.

**Upstream:** [p0deje/Maccy](https://github.com/p0deje/Maccy) (MIT License)

## What's Different From Upstream

### Performance & Bug Fixes
- **SHA-256 content hashing** for O(1) deduplication (replaces O(n*m) full table scan on every copy)
- **Off-by-one crash fix** in App Intents (Get, Select, Delete)
- **OCR data race fix** — Vision callback dispatched to main queue
- **Graceful database recovery** — corrupt SQLite recreated instead of `fatalError`
- **Regex caching** — compiled patterns cached instead of recompiled every 0.5s
- **Accessibility permission prompt** — users told why paste fails instead of silent no-op

> Bug fixes submitted upstream as [PR #1362](https://github.com/p0deje/Maccy/pull/1362)

### AI-Powered Features

#### Paste Transforms
Type `:` in the search field to access 17 built-in transforms:

| Command | Description |
|---------|-------------|
| `:json` | Pretty-print JSON |
| `:json1` | Compact/minify JSON |
| `:upper` / `:lower` / `:title` | Case conversion |
| `:trim` | Strip whitespace and blank lines |
| `:1line` | Collapse multiline to single line |
| `:noutm` | Strip UTM tracking parameters from URLs |
| `:urlencode` / `:urldecode` | URL encoding |
| `:b64enc` / `:b64dec` | Base64 encode/decode |
| `:escape` / `:unescape` | Escape/unescape special characters |
| `:sort` / `:uniq` | Sort or deduplicate lines |
| `:count` | Character, word, and line count |
| `:rev` | Reverse text |
| `:md2txt` | Strip Markdown formatting |

Press Return to apply the transform to the selected clipboard item and paste.

#### AI Transforms (Claude API)
Type `:ai <instruction>` in the search field for AI-powered transformations:

```
:ai summarize in 3 bullet points
:ai translate to Spanish
:ai explain this code
:ai rewrite as a professional email
:ai fix the grammar
:ai add TypeScript types
:ai convert to a bash script
```

Requires `ANTHROPIC_API_KEY` environment variable or `~/.anthropic/api_key` file.

#### Auto-Categorization
Every clipboard entry is automatically categorized: URL, Code, Email, Color, File Path, Phone Number, Number, Image, File, or Text. Categories are detected via pattern matching and code heuristics.

#### Smart Suggestions
Contextual banners appear when opening Maccy:
- Pin suggestions for frequently copied items
- Tips about transforms, multi-select, and search features

### Enhanced UI

#### Item Metadata
Each clipboard row shows:
- Category icon (link, code brackets, envelope, etc.)
- Copy count badge (`3x`) for items copied more than once
- Relative timestamp (`2m`, `1h`, `3d`)
- Toggleable via Preferences > Appearance > "Show item metadata"

#### Rich Preview
The preview sidebar shows:
- Category badge with icon
- Color swatch for hex/RGB colors
- Content stats (character, word, line counts)

#### Insights Dashboard
New "Insights" tab in Preferences with Swift Charts:
- Content type distribution (donut chart)
- App usage breakdown (bar chart)
- Hourly activity pattern
- Most-copied items with counts
- Duplicate rate statistics

#### Multi-Select & Paste Stack
Cmd+Click to select multiple items, then paste them sequentially. Each Cmd+V pastes the next item in the stack.

#### Search by App & Category
Type an app name ("Chrome", "VS Code") or category ("URL", "Code") to filter clipboard history.

### MCP Server
A Model Context Protocol server exposes Maccy to AI agents. See [`mcp-server/README.md`](mcp-server/README.md) for details.

## Building

```bash
# Clone
git clone https://github.com/twitchyvr/Maccy.git
cd Maccy
git checkout feat/performance-and-dedup

# Build (ad-hoc signing for local use)
xcodebuild -project Maccy.xcodeproj -scheme Maccy \
  -destination 'platform=macOS' build \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# Install
BUILT=$(ls -d ~/Library/Developer/Xcode/DerivedData/Maccy-*/Build/Products/Debug/Maccy.app | head -1)
cp -R "$BUILT" /Applications/Maccy.app

# Launch
open -a Maccy
```

## License

MIT (same as upstream). See [LICENSE](LICENSE).
