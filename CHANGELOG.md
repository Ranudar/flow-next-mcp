# Changelog

All notable changes to the gmickel-claude-marketplace.

## [0.5.15] - 2025-12-29

### Fixed
- Made review-fix-review loop fully automated (no human gates)
  - flow-work Phase 7: explicit "do NOT ask for confirmation"
  - flow-plan Step 5: same fix
  - Removed "ask before closing final tasks" ambiguity
  - Reviews now auto-fix and re-run until "Ship"

## [0.5.14] - 2025-12-29

### Fixed
- Removed redundant "Go ahead to start?" confirmation in flow-work
  - User already consented via setup questions
  - Only ask if something is actually unclear or blocking

## [0.5.13] - 2025-12-29

### Changed
- Replaced AskUserQuestion with text-based questions in flow-plan and flow-work
  - Better for voice dictation users
  - Supports terse replies ("1a 2b") and natural language rambling
  - All questions visible at once
  - Explicit "do NOT use AskUserQuestion tool" instruction

## [0.5.12] - 2025-12-29

### Added
- Issue quality guidelines in review prompts (inspired by OpenAI Codex)
  - impl-review: only flag issues **introduced by this change**
  - Both: cite **actual affected code** (no speculation)
  - Both: specify **trigger conditions** (inputs, edge cases)

## [0.5.11] - 2025-12-29

### Fixed
- Restructured chat command examples so `--new-chat` flags aren't buried

## [0.5.10] - 2025-12-29

### Added
- Chat session targeting for re-reviews
  - `chats list` → get chat IDs and names
  - `--chat-id <id>` → continue specific chat

## [0.5.9] - 2025-12-29

### Fixed
- Clarified new-chat behavior in review workflows

## [0.5.8] - 2025-12-29

### Fixed
- Added prominent "CRITICAL" instruction for chat management in review workflows

## [0.5.7] - 2025-12-29

### Changed
- Merged redundant verify phases in review workflows
  - `flow-plan-review`: Phase 2+3 → "Build Context & Verify Selection"
  - `flow-impl-review`: Phase 3+4 → "Build Context & Verify Selection"
  - Agent now adds all supporting docs found in earlier phases after builder runs
  - Eliminates duplicate "check for PRD" instructions

## [0.5.6] - 2025-12-29

### Changed
- Improved skill descriptions to explicitly mention Beads issue ID support
  - `flow-plan`: now triggers on issue IDs (e.g., bd-123, gno-45)
  - `flow-work`: now triggers on epic/issue IDs for execution

## [0.5.4] - 2025-12-28

### Added
- **New skill: `rp-explorer`** - Token-efficient codebase exploration via rp-cli
  - Deliberate activation: triggers on "use rp", "use repoprompt", explicit requests
  - Includes full rp-cli command reference (progressive disclosure)

### Changed
- `/flow:plan` now asks two setup questions when rp-cli detected:
  - Q1: Research approach (context-scout vs repo-scout)
  - Q2: Auto-review preference
- Updated README with comparison table and SETUP phase diagram

## [0.5.3] - 2025-12-28

### Changed
- Documented cross-model review benefit (GPT-5.2 High, o3 for validation)

## [0.5.2] - 2025-12-28

### Added
- **New agent: `context-scout`** - Token-efficient codebase exploration using RepoPrompt's rp-cli
  - Uses `structure` for code signatures (10x fewer tokens than full files)
  - Uses `builder` for AI-powered file discovery
  - Comprehensive workflow: window setup → explore → summarize

### Changed
- **Improved all 6 agents** with proper configuration and detailed prompts:
  - Added `tools` field - each agent now has only the tools it needs
  - Added `model` field - scouts use `haiku` (fast), analysts use `sonnet` (reasoning)
  - Detailed search/analysis methodologies
  - Structured output formats for consistent, actionable results
  - Clear rules on what to focus on and what to skip

### Technical
- All 6 agents use opus model with full research toolkit: Read/Grep/Glob/Bash/WebSearch/WebFetch
- Explicitly excludes Edit/Write (read-only), Task (no sub-agents), TodoWrite/AskUserQuestion (parent manages)

## [0.5.0] - 2025-12-28

### Added
- **Auto-offer review**: Both `flow-plan` and `flow-work` now detect if rp-cli is installed and offer Carmack-level review
  - `flow-plan`: After writing plan, offers `/flow:plan-review` before next steps
  - `flow-work`: After shipping, offers `/flow:impl-review` with fix-and-iterate loop
- Eliminates need for manual chaining like "then review with /flow:impl-review"

### Changed
- `flow-work`: Branch setup question now in SKILL.md (first thing shown, cannot be skipped)
- Explicit examples of chained instructions in skill inputs

### Fixed
- Review commands now have explicit wait instructions for rp-cli chat responses (1-5+ min timeout)

## [0.4.0] - 2025-12-27

### Added
- **Beads integration**: Optional Beads (`bd`) support for flow skills
  - `flow-plan`: Can create Beads epics/tasks instead of markdown plans
  - `flow-work`: Can accept Beads IDs/titles, track via `bd ready`/`bd update`/`bd close`
  - `flow-plan-review`: Can accept Beads IDs/titles as input
  - `flow-impl-review`: Looks for Beads context during code review
- Graceful fallback to markdown/TodoWrite when `bd` unavailable
- Context recovery guidance per Anthropic's long-running agent best practices

### Technical
- Agent-first design: no rigid detection gates, uses judgment based on context
- Validated against bd v0.38.0
- CLI behavior documented in plan (ID formats, parent linking, scoped ready)

## [0.3.0] - 2024-12-27

### Added
- `/flow:plan-review` command: Carmack-level plan review via rp-cli context builder + chat
- `/flow:impl-review` command: Carmack-level implementation review of current branch changes
- `flow-plan-review` skill: progressive disclosure with workflow.md + rp-cli-reference.md
- `flow-impl-review` skill: progressive disclosure with workflow.md + rp-cli-reference.md

### Technical
- Both review skills use rp-cli for context building and chat-based review
- Shared rp-cli-reference.md for CLI command reference
- Commands are thin wrappers (~15 lines) invoking skills

## [0.2.3] - 2024-12-27

### Fixed
- Use "subagent" terminology consistently (official Claude Code term)

## [0.2.2] - 2024-12-27

### Fixed
- Use namespaced agent names (`flow:repo-scout`, `flow:practice-scout`, etc.) in skill reference files
- Make workflow file references directive ("Read and follow" instead of passive links)

## [0.2.1] - 2024-12-27

### Changed
- **Progressive disclosure for Skills**: SKILL.md files now contain only overview + links to reference files
- `flow-plan`: 117 → 30 lines in SKILL.md, detailed steps moved to `steps.md` and `examples.md`
- `flow-work`: 95 → 27 lines in SKILL.md, phases moved to `phases.md`
- Context usage reduced: ~100-150 tokens per skill at startup instead of 400-700

## [0.2.0] - 2024-12-27

### Added
- `flow-plan` skill: planning workflow logic extracted from command
- `flow-work` skill: execution workflow logic extracted from command

### Changed
- **Commands → Skills refactor**: `/flow:plan` and `/flow:work` are now thin wrappers (~15 lines each) that invoke Skills
- Skills enable auto-triggering based on description matching (e.g., "plan out adding OAuth" triggers `flow-plan`)
- Updated manifests: 1 skill → 3 skills

### Technical
- Commands reduced from ~2.1k and ~2.4k tokens to ~36 and ~38 tokens
- Full logic loads on-demand when skill is triggered

## [0.1.1] - 2024-12-26

### Changed
- Moved commands to `commands/flow/` subdirectory for prefixed naming (`/flow:plan`, `/flow:work`)
- Renamed commands for clarity
- Updated argument hints

### Added
- Semver bump script for version management

## [0.1.0] - 2024-12-26

### Added
- Initial release of Flow plugin
- `/flow:plan` command: research + produce `plans/<slug>.md`
- `/flow:work` command: execute a plan end-to-end
- 5 agents: `repo-scout`, `practice-scout`, `docs-scout`, `flow-gap-analyst`, `quality-auditor`
- `worktree-kit` skill for safe parallel git workspaces
- Issue creation integration (GitHub, Linear, Beads)
- Marketplace structure with plugin manifest
