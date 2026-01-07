#!/usr/bin/env bash
#
# Beads (bd) uninstall/cleanup script (macOS/Linux).
# Dry-run by default; pass --apply to actually delete/modify files.
#
# Usage:
#   ./scripts/uninstall.sh            # dry-run (scan $HOME)
#   ./scripts/uninstall.sh --apply    # perform cleanup
#   ./scripts/uninstall.sh --root DIR --apply
#   ./scripts/uninstall.sh --skip-home --skip-binary
#

set -euo pipefail

APPLY=0
SKIP_HOME=0
SKIP_BINARY=0
ROOTS=()

usage() {
  cat <<'EOF'
Beads uninstall/cleanup script

Defaults:
  - dry-run (no changes)
  - scan $HOME for .beads and related files

Options:
  --apply         Actually delete/modify files (otherwise dry-run)
  --root DIR      Add a scan root (repeatable). If none, uses $HOME.
  --skip-home     Do not touch home-level files (~/.beads, ~/.config/bd, ~/.claude, ~/.gemini)
  --skip-binary   Do not remove the bd binary or package installs
  -h, --help      Show this help

Examples:
  ./scripts/uninstall.sh
  ./scripts/uninstall.sh --apply
  ./scripts/uninstall.sh --root ~/src --apply
EOF
}

log() {
  printf '[beads-uninstall] %s\n' "$*"
}

warn() {
  printf '[beads-uninstall] WARN: %s\n' "$*" >&2
}

run() {
  if [[ "$APPLY" -eq 1 ]]; then
    log "+ $*"
    "$@"
  else
    log "[dry-run] $*"
  fi
}

run_rm() {
  local path="$1"
  if [[ "$APPLY" -eq 1 ]]; then
    if [[ -e "$path" ]]; then
      if [[ -w "$(dirname "$path")" ]]; then
        log "+ rm -rf $path"
        rm -rf "$path"
      else
        if command -v sudo >/dev/null 2>&1; then
          log "+ sudo rm -rf $path"
          sudo rm -rf "$path"
        else
          warn "Need permissions to remove $path (run with sudo)"
        fi
      fi
    fi
  else
    log "[dry-run] rm -rf $path"
  fi
}

run_mv() {
  local src="$1"
  local dst="$2"
  if [[ "$APPLY" -eq 1 ]]; then
    log "+ mv $src $dst"
    mv "$src" "$dst"
  else
    log "[dry-run] mv $src $dst"
  fi
}

is_beads_hook() {
  local file="$1"
  [[ -f "$file" ]] || return 1
  grep -Eq 'bd-hooks-version:|bd-shim|bd \(beads\)|bd hooks run' "$file"
}

restore_hook_backup() {
  local hook="$1"
  local restored=0

  if [[ -f "${hook}.old" ]]; then
    if is_beads_hook "${hook}.old"; then
      run_rm "${hook}.old"
    else
      run_mv "${hook}.old" "$hook"
      restored=1
    fi
  fi

  if [[ "$restored" -eq 0 && -f "${hook}.backup" ]]; then
    if is_beads_hook "${hook}.backup"; then
      run_rm "${hook}.backup"
    else
      run_mv "${hook}.backup" "$hook"
      restored=1
    fi
  fi

  if [[ "$restored" -eq 0 ]]; then
    local latest=""
    local backups=()
    local glob="${hook}.backup-"*
    shopt -s nullglob
    backups=($glob)
    shopt -u nullglob
    if [[ "${#backups[@]}" -gt 0 ]]; then
      latest=$(ls -t "${backups[@]}" 2>/dev/null | head -n 1)
    fi
    if [[ -n "$latest" ]]; then
      if is_beads_hook "$latest"; then
        run_rm "$latest"
      else
        run_mv "$latest" "$hook"
      fi
    fi
  fi
}

cleanup_hooks_dir() {
  local hooks_dir="$1"
  [[ -d "$hooks_dir" ]] || return 0

  local hook
  for hook in pre-commit post-merge pre-push post-checkout prepare-commit-msg; do
    local path="$hooks_dir/$hook"
    if [[ -f "$path" ]]; then
      if is_beads_hook "$path"; then
        run_rm "$path"
        restore_hook_backup "$path"
      fi
    fi
  done
}

cleanup_gitattributes() {
  local repo="$1"
  local file="$repo/.gitattributes"
  [[ -f "$file" ]] || return 0

  local tmp
  tmp=$(mktemp)
  awk '!/merge=beads/' "$file" > "$tmp"
  if ! cmp -s "$file" "$tmp"; then
    if [[ -s "$tmp" ]]; then
      run_mv "$tmp" "$file"
    else
      run_rm "$file"
    fi
  fi
  rm -f "$tmp"
}

cleanup_exclude() {
  local git_dir="$1"
  local file="$git_dir/info/exclude"
  [[ -f "$file" ]] || return 0

  local tmp
  tmp=$(mktemp)
  awk '
    function trim(s){sub(/^[ \t\r\n]+/, "", s); sub(/[ \t\r\n]+$/, "", s); return s}
    {
      t = trim($0)
      if (t ~ /^#.*[Bb]eads/) next
      if (t == ".beads/") next
      if (t == ".beads/issues.jsonl") next
      if (t == ".claude/settings.local.json") next
      if (t == "**/RECOVERY*.md") next
      if (t == "**/SESSION*.md") next
      print
    }
  ' "$file" > "$tmp"

  if ! cmp -s "$file" "$tmp"; then
    if [[ -s "$tmp" ]]; then
      run_mv "$tmp" "$file"
    else
      run_rm "$file"
    fi
  fi
  rm -f "$tmp"
}

cleanup_agents_file() {
  local file="$1"
  [[ -f "$file" ]] || return 0

  if ! command -v python3 >/dev/null 2>&1; then
    warn "python3 not found; skipping AGENTS.md cleanup for $file"
    return 0
  fi

  APPLY="$APPLY" python3 - "$file" <<'PY'
import os, re, sys
path = sys.argv[1]
apply = os.environ.get("APPLY") == "1"

with open(path, "r", encoding="utf-8") as f:
    content = f.read()

orig = content

begin = "<!-- BEGIN BEADS INTEGRATION -->"
end = "<!-- END BEADS INTEGRATION -->"
if begin in content and end in content:
    pattern = re.compile(r"\n?\s*<!-- BEGIN BEADS INTEGRATION -->.*?<!-- END BEADS INTEGRATION -->\s*\n?", re.S)
    content = re.sub(pattern, "\n", content)

heading = "## Landing the Plane (Session Completion)"
if heading in content:
    pattern = re.compile(r"\n?## Landing the Plane \(Session Completion\)[\s\S]*?(?=\n## |\Z)")
    m = pattern.search(content)
    if m:
        block = m.group(0)
        if "bd sync" in block or "git pull --rebase" in block:
            content = content[:m.start()] + "\n" + content[m.end():]

content = re.sub(r"\n{3,}", "\n\n", content)
changed = content != orig

if not changed:
    sys.exit(0)

if apply:
    if content.strip() == "":
        os.remove(path)
        print(f"Removed empty AGENTS.md: {path}")
    else:
        mode = os.stat(path).st_mode
        with open(path, "w", encoding="utf-8") as f:
            f.write(content.rstrip() + "\n")
        os.chmod(path, mode)
        print(f"Updated AGENTS.md: {path}")
else:
    print(f"Would update AGENTS.md: {path}")
PY
}

cleanup_settings_json() {
  local file="$1"
  local kind="$2"
  [[ -f "$file" ]] || return 0

  if ! command -v python3 >/dev/null 2>&1; then
    warn "python3 not found; skipping JSON cleanup for $file"
    return 0
  fi

  APPLY="$APPLY" python3 - "$file" "$kind" <<'PY'
import json, os, re, sys

path = sys.argv[1]
kind = sys.argv[2]
apply = os.environ.get("APPLY") == "1"

with open(path, "r", encoding="utf-8") as f:
    try:
        data = json.load(f)
    except Exception as e:
        print(f"Skipping {path}: failed to parse JSON ({e})")
        sys.exit(0)

changed = False

targets = {"bd prime", "bd prime --stealth"}
if kind == "claude":
    events = ["SessionStart", "PreCompact"]
else:
    events = ["SessionStart", "PreCompress"]

hooks = data.get("hooks")
if isinstance(hooks, dict):
    for event in list(events):
        event_hooks = hooks.get(event)
        if not isinstance(event_hooks, list):
            continue
        new_event_hooks = []
        for hook in event_hooks:
            if not isinstance(hook, dict):
                new_event_hooks.append(hook)
                continue
            cmds = hook.get("hooks")
            if not isinstance(cmds, list):
                new_event_hooks.append(hook)
                continue
            new_cmds = []
            removed_any = False
            for cmd in cmds:
                if isinstance(cmd, dict) and cmd.get("command") in targets:
                    removed_any = True
                else:
                    new_cmds.append(cmd)
            if removed_any:
                changed = True
            if new_cmds:
                hook["hooks"] = new_cmds
                new_event_hooks.append(hook)
        if new_event_hooks != event_hooks:
            hooks[event] = new_event_hooks
            changed = True
        if event in hooks and not hooks[event]:
            del hooks[event]
            changed = True
    if not hooks:
        data.pop("hooks", None)

onboard = "Before starting any work, run 'bd onboard' to understand the current project state and available issues."
prompt = data.get("prompt")
if isinstance(prompt, str) and onboard in prompt:
    new_prompt = prompt.replace(onboard, "").strip()
    new_prompt = re.sub(r"\n{3,}", "\n\n", new_prompt).strip()
    if new_prompt:
        data["prompt"] = new_prompt
    else:
        data.pop("prompt", None)
    changed = True

if not changed:
    sys.exit(0)

if apply:
    mode = os.stat(path).st_mode
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=True)
        f.write("\n")
    os.chmod(path, mode)
    print(f"Updated settings: {path}")
else:
    print(f"Would update settings: {path}")
PY
}

rmdir_if_empty() {
  local dir="$1"
  [[ -d "$dir" ]] || return 0
  if [[ -z "$(ls -A "$dir" 2>/dev/null)" ]]; then
    run_rm "$dir"
  fi
}

stop_daemon_pid_file() {
  local pid_file="$1"
  [[ -f "$pid_file" ]] || return 0

  local pid
  pid="$(tr -d '[:space:]' < "$pid_file" 2>/dev/null || true)"
  [[ "$pid" =~ ^[0-9]+$ ]] || return 0

  if ps -p "$pid" >/dev/null 2>&1; then
    local cmd
    cmd="$(ps -p "$pid" -o comm= 2>/dev/null | tr -d '[:space:]' || true)"
    if [[ "$cmd" == *bd* ]]; then
      run kill "$pid"
      if [[ "$APPLY" -eq 1 ]]; then
        sleep 0.2 || true
        if ps -p "$pid" >/dev/null 2>&1; then
          run kill -9 "$pid"
        fi
      fi
    else
      warn "PID $pid from $pid_file does not look like bd; skipping"
    fi
  fi
}

cleanup_repo() {
  local repo="$1"
  [[ -d "$repo" ]] || return 0

  log "Cleaning repo: $repo"

  # Stop daemon if running
  stop_daemon_pid_file "$repo/.beads/daemon.pid"

  # Remove project integration files
  cleanup_agents_file "$repo/AGENTS.md"
  cleanup_settings_json "$repo/.claude/settings.local.json" "claude"
  cleanup_settings_json "$repo/.gemini/settings.json" "gemini"

  if [[ -f "$repo/.cursor/rules/beads.mdc" ]]; then
    run_rm "$repo/.cursor/rules/beads.mdc"
  fi
  if [[ -f "$repo/.aider.conf.yml" ]]; then
    run_rm "$repo/.aider.conf.yml"
  fi
  if [[ -f "$repo/.aider/BEADS.md" ]]; then
    run_rm "$repo/.aider/BEADS.md"
  fi
  if [[ -f "$repo/.aider/README.md" ]]; then
    run_rm "$repo/.aider/README.md"
  fi
  rmdir_if_empty "$repo/.aider"
  rmdir_if_empty "$repo/.cursor/rules"
  rmdir_if_empty "$repo/.cursor"

  # Git-related cleanup
  if command -v git >/dev/null 2>&1; then
    local git_common_dir=""
    git_common_dir="$(git -C "$repo" rev-parse --git-common-dir 2>/dev/null || true)"
    if [[ -n "$git_common_dir" ]]; then
      # hooks
      cleanup_hooks_dir "$git_common_dir/hooks"

      # core.hooksPath -> .beads-hooks
      local hooks_path=""
      hooks_path="$(git -C "$repo" config --get core.hooksPath 2>/dev/null || true)"
      if [[ -n "$hooks_path" ]]; then
        local abs_hooks_path="$hooks_path"
        if [[ "$hooks_path" != /* ]]; then
          abs_hooks_path="$repo/$hooks_path"
        fi
        cleanup_hooks_dir "$abs_hooks_path"
        if [[ "$hooks_path" == ".beads-hooks" || "$hooks_path" == */.beads-hooks ]]; then
          run git -C "$repo" config --unset core.hooksPath
        fi
      fi

      # merge driver config
      if git -C "$repo" config --get merge.beads.driver >/dev/null 2>&1; then
        run git -C "$repo" config --unset merge.beads.driver
        run git -C "$repo" config --unset merge.beads.name || true
      fi

      cleanup_gitattributes "$repo"
      cleanup_exclude "$git_common_dir"

      # sync worktrees
      if [[ -d "$git_common_dir/beads-worktrees" ]]; then
        run_rm "$git_common_dir/beads-worktrees"
      fi
    fi
  fi

  # Remove beads directories
  if [[ -d "$repo/.beads-hooks" ]]; then
    run_rm "$repo/.beads-hooks"
  fi
  if [[ -d "$repo/.beads" ]]; then
    run_rm "$repo/.beads"
  fi
}

cleanup_global_gitignore() {
  local ignore_path=""
  if command -v git >/dev/null 2>&1; then
    ignore_path="$(git config --global core.excludesfile 2>/dev/null || true)"
  fi
  if [[ -n "$ignore_path" ]]; then
    if [[ "$ignore_path" == "~/"* ]]; then
      ignore_path="${HOME}/${ignore_path#~/}"
    fi
  elif [[ -f "$HOME/.config/git/ignore" ]]; then
    ignore_path="$HOME/.config/git/ignore"
  fi

  [[ -f "$ignore_path" ]] || return 0

  local tmp
  tmp=$(mktemp)
  awk '
    function trim(s){sub(/^[ \t\r\n]+/, "", s); sub(/[ \t\r\n]+$/, "", s); return s}
    {
      t = trim($0)
      if (t ~ /Beads stealth mode/) next
      if (t ~ /\/\.beads\/$/) next
      if (t ~ /\/\.claude\/settings\.local\.json$/) next
      print
    }
  ' "$ignore_path" > "$tmp"

  if ! cmp -s "$ignore_path" "$tmp"; then
    if [[ -s "$tmp" ]]; then
      run_mv "$tmp" "$ignore_path"
    else
      run_rm "$ignore_path"
    fi
  fi
  rm -f "$tmp"
}

cleanup_home() {
  if [[ "$SKIP_HOME" -eq 1 ]]; then
    return 0
  fi

  log "Cleaning home-level files"

  cleanup_settings_json "$HOME/.claude/settings.json" "claude"
  cleanup_settings_json "$HOME/.gemini/settings.json" "gemini"
  cleanup_global_gitignore

  if [[ -d "$HOME/.beads" ]]; then
    run_rm "$HOME/.beads"
  fi

  if [[ -d "$HOME/.config/bd" ]]; then
    run_rm "$HOME/.config/bd"
  fi

  # Optional: planning repo (only if it looks like a beads repo)
  if [[ -d "$HOME/.beads-planning/.beads" ]]; then
    run_rm "$HOME/.beads-planning"
  fi
}

cleanup_binaries() {
  if [[ "$SKIP_BINARY" -eq 1 ]]; then
    return 0
  fi

  log "Checking bd binaries"

  local paths_file
  paths_file=$(mktemp)

  if command -v bd >/dev/null 2>&1; then
    if command -v which >/dev/null 2>&1; then
      which -a bd 2>/dev/null | sed '/^$/d' >> "$paths_file" || true
    else
      command -v bd >> "$paths_file" || true
    fi
  fi

  for p in \
    "/usr/local/bin/bd" \
    "/opt/homebrew/bin/bd" \
    "$HOME/.local/bin/bd" \
    "$HOME/go/bin/bd" \
    ; do
    if [[ -x "$p" ]]; then
      printf '%s\n' "$p" >> "$paths_file"
    fi
  done

  sort -u "$paths_file" | while IFS= read -r p; do
    [[ -n "$p" ]] || continue
    if [[ -x "$p" ]]; then
      if "$p" version >/dev/null 2>&1; then
        if "$p" version 2>/dev/null | grep -q "^bd version"; then
          run_rm "$p"
        else
          warn "Skipping $p (not beads)"
        fi
      else
        warn "Skipping $p (cannot execute)"
      fi
    fi
  done

  rm -f "$paths_file"

  # Package managers (best-effort)
  if command -v brew >/dev/null 2>&1; then
    if brew list --formula 2>/dev/null | grep -qx "bd"; then
      run brew uninstall bd
    fi
  fi

  if command -v npm >/dev/null 2>&1; then
    if npm ls -g --depth=0 @beads/bd >/dev/null 2>&1; then
      run npm uninstall -g @beads/bd
    fi
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --apply)
        APPLY=1
        ;;
      --root)
        shift
        [[ $# -gt 0 ]] || { warn "--root requires a directory"; exit 1; }
        ROOTS+=("$1")
        ;;
      --skip-home)
        SKIP_HOME=1
        ;;
      --skip-binary)
        SKIP_BINARY=1
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        warn "Unknown argument: $1"
        usage
        exit 1
        ;;
    esac
    shift
  done
}

add_repo_root() {
  local path="$1"
  local dir="$path"
  if [[ -f "$path" ]]; then
    dir="$(dirname "$path")"
  fi

  local root=""
  if command -v git >/dev/null 2>&1; then
    root="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || true)"
  fi
  if [[ -z "$root" ]]; then
    case "$path" in
      */.beads|*/.beads-hooks)
        root="$(dirname "$path")"
        ;;
      *)
        root="$dir"
        ;;
    esac
  fi

  printf '%s\n' "$root"
}

scan_roots() {
  local roots_file="$1"

  local root
  for root in "${ROOTS[@]}"; do
    [[ -d "$root" ]] || continue
    log "Scanning root: $root"

    # .beads directories
    log "  Looking for .beads directories..."
    { rg --files --hidden --no-ignore --null -g '!.git/**' -g '.beads/**' "$root" 2>/dev/null || true; } | while IFS= read -r -d '' file; do
      case "$file" in
        "$HOME/.beads"/*)
          continue
          ;;
      esac
      add_repo_root "$file" >> "$roots_file"
    done

    # .beads-hooks directories
    log "  Looking for .beads-hooks directories..."
    { rg --files --hidden --no-ignore --null -g '!.git/**' -g '.beads-hooks/**' "$root" 2>/dev/null || true; } | while IFS= read -r -d '' file; do
      add_repo_root "$file" >> "$roots_file"
    done

    # other markers (cursor/aider/claude/gemini)
    log "  Looking for integration markers..."
    { rg --files --hidden --no-ignore --null -g '!.git/**' \
      -g '.aider.conf.yml' \
      -g '.cursor/rules/beads.mdc' \
      -g '.aider/BEADS.md' \
      -g '.aider/README.md' \
      -g '.claude/settings.local.json' \
      -g '.gemini/settings.json' \
      "$root" 2>/dev/null || true; } | while IFS= read -r -d '' file; do
        add_repo_root "$file" >> "$roots_file"
      done

    # AGENTS.md that actually contains beads instructions
    { rg -l --hidden --no-ignore --null -g '!.git/**' -g 'AGENTS.md' \
      -e 'Landing the Plane \(Session Completion\)' \
      -e 'BEGIN BEADS INTEGRATION' \
      "$root" 2>/dev/null || true; } | while IFS= read -r -d '' file; do
        add_repo_root "$file" >> "$roots_file"
      done
  done
}

main() {
  parse_args "$@"

  if [[ "${#ROOTS[@]}" -eq 0 ]]; then
    ROOTS=("$HOME")
  fi

  if [[ "$APPLY" -eq 1 ]]; then
    log "Mode: APPLY (changes will be made)"
  else
    log "Mode: DRY-RUN (no changes will be made)"
  fi
  log "Roots:"
  for r in "${ROOTS[@]}"; do
    log "  - $r"
  done
  log "Scanning for beads modifications (this may take a while on large trees)..."

  local roots_file
  roots_file=$(mktemp)
  scan_roots "$roots_file"

  log "Scan complete. Cleaning detected repositories..."
  sort -u "$roots_file" | while IFS= read -r repo; do
    [[ -n "$repo" ]] || continue
    cleanup_repo "$repo"
  done

  rm -f "$roots_file"

  cleanup_home
  cleanup_binaries

  log "Done. Use --apply to perform changes (this run was dry-run)." || true
  if [[ "$APPLY" -eq 1 ]]; then
    log "Cleanup complete."
  fi
}

main "$@"
