---
name: rp-explorer
description: Token-efficient codebase exploration using RepoPrompt CLI. Triggers on "use rp", "use repoprompt", "rp-cli", or explicit RepoPrompt requests.
---

# RP-Explorer

Token-efficient codebase exploration using RepoPrompt CLI.

## When to Use

- User explicitly asks to use RepoPrompt/rp-cli
- User says "use rp to...", "use repoprompt to..."
- Debugging with token-efficient context gathering

## CLI Reference

Read [cli-reference.md](cli-reference.md) for complete command documentation.

## Quick Start

### Step 1: Get Overview
```bash
rp-cli -e 'tree'
rp-cli -e 'structure .'
```

### Step 2: Find Relevant Files
```bash
rp-cli -e 'search "auth" --context-lines 2'
rp-cli -e 'builder "understand authentication"'
```

### Step 3: Deep Dive
```bash
rp-cli -e 'select set src/auth/'
rp-cli -e 'structure --scope selected'
rp-cli -e 'read src/auth/login.ts'
```

### Step 4: Export Context
```bash
rp-cli -e 'context --all > codebase-map.md'
```

## Token Efficiency

- Use `structure` instead of reading full files (10x fewer tokens)
- Use `builder` for AI-powered file discovery
- Select only relevant files before exporting context

## Requirements

RepoPrompt app with rp-cli installed.
