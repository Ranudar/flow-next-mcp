# RepoPrompt Wrapper Reference

Use `flowctl rp` wrappers only. Do **not** call `rp-cli` directly.

## Primary Command (Ralph mode)

```bash
# Atomic setup: pick-window + ensure-workspace + builder
eval "$($FLOWCTL rp setup-review --repo-root "$REPO_ROOT" --summary "...")"
# Returns: W=<window> T=<tab>
```

This is the **only** way to initialize a review session in Ralph mode. Individual `pick-window`, `ensure-workspace`, and `builder` calls are blocked.

## Post-Setup Commands

After `setup-review`, use these with `$W` and `$T`:

```bash
# Get/modify selection
flowctl rp select-get --window "$W" --tab "$T"
flowctl rp select-add --window "$W" --tab "$T" path/to/file

# Get/set prompt
flowctl rp prompt-get --window "$W" --tab "$T"
flowctl rp prompt-set --window "$W" --tab "$T" --message-file /tmp/prompt.md

# Execute review
flowctl rp chat-send --window "$W" --tab "$T" --message-file /tmp/review.md --new-chat --chat-name "Review: X"

# Export (non-Ralph)
flowctl rp prompt-export --window "$W" --tab "$T" --out ~/Desktop/export.md
```

## Key Rules

1. **Always use setup-review first** - handles window selection atomically
2. **Always pass --window and --tab** - required for all post-setup commands
3. **--window must be numeric** - comes from setup-review output
4. **Use heredoc for prompts** - write to file, pass via --message-file
