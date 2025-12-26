<div align="center">

# gmickel claude marketplace

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude_Code-Plugin_Marketplace-blueviolet)](https://claude.ai/code)
[![Author](https://img.shields.io/badge/Author-Gordon_Mickel-orange)](https://mickel.tech)

**Focused workflows, minimal bloat.**

[Install](#install) · [Plugins](#plugins) · [Contributing](#contributing)

</div>

---

## Install

```bash
/plugin marketplace add https://github.com/gmickel/gmickel-claude-marketplace
```

## Plugins

### Flow

Two‑step workflow: **plan first, work second.**

```bash
/plugin install flow
```

```bash
/flow:plan Add OAuth login for users
/flow:work plans/add-oauth-login.md
```

📖 **[Full documentation →](plugins/flow/README.md)**

---

## Contributing

1. Create `plugins/<name>/` with `.claude-plugin/plugin.json`
2. Add commands/agents/skills under that plugin root
3. Update `.claude-plugin/marketplace.json`
4. Validate:

```bash
jq . .claude-plugin/marketplace.json
jq . plugins/<name>/.claude-plugin/plugin.json
```

---

<div align="center">

Made by [Gordon Mickel](https://mickel.tech) · [gordon@mickel.tech](mailto:gordon@mickel.tech)

</div>
