# Agent Distribution

RedditReminder ships agent guidance in two layers:

1. `AGENTS.md` for agents already working inside this repository.
2. `skills/redditreminder-agent/` for reusable Codex skill distribution.

## Skill Distribution

Use the repo-local skill when another agent needs to learn how to operate RedditReminder safely through the CLI:

```text
Use $redditreminder-agent from skills/redditreminder-agent to inspect or automate RedditReminder through the CLI.
```

For local Codex discovery outside this checkout, copy or sync the skill folder into the Codex skills directory:

```sh
mkdir -p "${CODEX_HOME:-$HOME/.codex}/skills"
cp -R skills/redditreminder-agent "${CODEX_HOME:-$HOME/.codex}/skills/"
```

Validate before distributing:

```sh
python3 /Users/neonwatty/.codex/skills/.system/skill-creator/scripts/quick_validate.py skills/redditreminder-agent
```

## Plugin Distribution

Use a plugin wrapper later if the team needs installable marketplace-style distribution, bundled MCP/app capabilities, or a single package that includes the skill and support files.

A plugin wrapper should contain:

```text
plugins/redditreminder-agent/
├── .codex-plugin/plugin.json
└── skills/redditreminder-agent/
```

Validate a plugin wrapper with:

```sh
python3 /Users/neonwatty/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py plugins/redditreminder-agent
```

Do not add a personal or team marketplace entry unless that distribution channel is intentionally selected.
