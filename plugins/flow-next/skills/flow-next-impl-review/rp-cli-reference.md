# RepoPrompt usage (short)

Use `flowctl rp` wrappers only. Do **not** call `rp-cli` directly, especially in Ralph mode.

Common wrappers:

```bash
flowctl rp pick-window --repo-root "$REPO_ROOT"
flowctl rp builder --window "$W" --summary "..."
flowctl rp prompt-get --window "$W" --tab "$T"
flowctl rp select-add --window "$W" --tab "$T" path/to/file
flowctl rp chat-send --window "$W" --tab "$T" --message-file /tmp/review-prompt.md
```
