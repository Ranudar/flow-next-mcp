# fn-17-wti.3 Remove runtime detection from flow-next-impl-review

## Description
Remove runtime `which rp-cli` / `which codex` detection from impl-review skill files.

## Files to modify

1. `plugins/flow-next/skills/flow-next-impl-review/SKILL.md`
2. `plugins/flow-next/skills/flow-next-impl-review/workflow.md`

## Changes to SKILL.md

### Remove detection block (lines ~43-52)

Delete:
```bash
HAVE_RP=$(which rp-cli >/dev/null 2>&1 && echo 1 || echo 0)
HAVE_CODEX=$(which codex >/dev/null 2>&1 && echo 1 || echo 0)

# Check configured backend (priority: env > config)
CONFIGURED_BACKEND="${FLOW_REVIEW_BACKEND:-}"
if [[ -z "$CONFIGURED_BACKEND" ]]; then
  CONFIGURED_BACKEND="$($FLOWCTL config get review.backend 2>/dev/null | jq -r '.value // empty')"
fi
```

Replace with simpler config-only read:
```bash
# Priority: --review flag > env > config
BACKEND="${FLOW_REVIEW_BACKEND:-}"
if [[ -z "$BACKEND" ]]; then
  BACKEND="$($FLOWCTL config get review.backend 2>/dev/null | jq -r '.value // empty')"
fi
```

### Remove fallback detection (lines ~75-78)

Delete:
```bash
if [[ -z "$BACKEND" ]]; then
  if [[ "$HAVE_RP" == "1" ]]; then BACKEND="rp"
  elif [[ "$HAVE_CODEX" == "1" ]]; then BACKEND="codex"
  else BACKEND="none"; fi
fi
```

Replace with error:
```bash
if [[ -z "$BACKEND" || "$BACKEND" == "null" ]]; then
  echo "Error: No review backend configured."
  echo "Run /flow-next:setup to configure, or pass --review=rp|codex|none"
  exit 1
fi
```

### Update "If no backend configured" section (lines ~53-68)

Remove the interactive question that asks user to choose backend.
Replace with: error message telling user to run setup or pass flag.

## Changes to workflow.md

### Remove Phase 0 detection (lines ~21-35)

Same pattern as SKILL.md:
- Remove `HAVE_RP`, `HAVE_CODEX` detection
- Remove fallback logic
- Add error when no backend configured
## Acceptance
- [ ] No `which rp-cli` or `which codex` in SKILL.md
- [ ] No `which rp-cli` or `which codex` in workflow.md
- [ ] No `HAVE_RP` or `HAVE_CODEX` variables
- [ ] Priority order: --review flag > FLOW_REVIEW_BACKEND env > config
- [ ] Clear error message when no backend configured
- [ ] Error message mentions both /flow-next:setup and --review flag
- [ ] Smoke tests pass
## Done summary
TBD

## Evidence
- Commits:
- Tests:
- PRs:
