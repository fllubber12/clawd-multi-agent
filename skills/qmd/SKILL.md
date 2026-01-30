---
name: qmd
description: Search markdown documents using BM25 + vector similarity + reranking. Use when looking for information in memory/, notes, logs, or any indexed markdown. Triggered by keywords like "search memory", "find in notes", "look up", "what did we learn about", "search for".
---

# qmd - Local Markdown Search

qmd is a local search engine for markdown files using BM25 + vector embeddings + reranking. Use it to find information without loading entire documents into context.

## Binary Location

```bash
~/.bun/bin/qmd
```

## Available Collections

```bash
# List all indexed collections
qmd collection list

# Current collections:
# - clawd-memory: ~/clawd/memory/ (session logs, learnings, tasks)
```

## Key Commands

### Search (Most Common)

```bash
# Full-text BM25 search
qmd search "error handling" -c clawd-memory

# Vector similarity search (semantic)
qmd vsearch "how to handle API failures" -c clawd-memory

# Combined search with reranking (best quality)
qmd query "orchestrator spawn agent" -c clawd-memory
```

### Search Options

```bash
# Get more results
qmd search "query" -n 10 -c clawd-memory

# Get full documents instead of snippets
qmd search "query" --full -c clawd-memory

# Output as JSON (for parsing)
qmd search "query" --json -c clawd-memory

# Output with line numbers
qmd search "query" --line-numbers -c clawd-memory

# Get just file paths and scores
qmd search "query" --files -c clawd-memory
```

### Get Specific Files

```bash
# Get a document
qmd get memory/first-task.md

# Get specific lines
qmd get memory/first-task.md:10 -l 20

# Get multiple files by glob
qmd multi-get "memory/*.md" -l 50
```

### Index Management

```bash
# Check index status
qmd status

# Re-index after changes
qmd update

# Re-index with git pull
qmd update --pull

# Create vector embeddings (for vsearch)
qmd embed
```

### Add New Collections

```bash
# Add a new collection
qmd collection add ~/path/to/docs --name my-docs

# Remove a collection
qmd collection remove my-docs
```

## When to Use Each Search Type

| Command | Use When |
|---------|----------|
| `search` | Looking for exact terms, keywords, function names |
| `vsearch` | Conceptual search, "how to do X", semantic meaning |
| `query` | Best quality results, combines both + reranking |

## Token Efficiency

Instead of loading full documents:

```bash
# Bad: Load entire file (wastes tokens)
cat memory/2026-01-30.md

# Good: Search for specific info (saves tokens)
qmd search "compound review fix" -c clawd-memory --full
```

## Integration with Clawd

The `clawd-memory` collection indexes:
- Session logs (`memory/*.md`)
- Task definitions (`memory/first-task.md`)
- Learnings (`memory/learnings/`)
- Decision logs (`memory/decisions-log.md`)

Search memory before asking the Director to avoid re-learning past lessons.

## Example Workflow

```bash
# 1. User asks: "What did we learn about model context length?"
qmd query "model context length" -c clawd-memory -n 3

# 2. Get full content of relevant file
qmd get memory/learnings/2026-01-15-context-limits.md

# 3. Use the info to answer without guessing
```

## Troubleshooting

```bash
# Check if collection exists
qmd collection list

# Re-index if files changed
qmd update

# Check index size and status
qmd status

# Clean up orphaned data
qmd cleanup
```

## Output Formats

| Flag | Format | Use Case |
|------|--------|----------|
| (none) | Plain text snippets | Human reading |
| `--json` | JSON with snippets | Parsing in scripts |
| `--files` | Paths and scores only | Quick overview |
| `--md` | Markdown formatted | Documentation |
| `--full` | Complete documents | Full context needed |
