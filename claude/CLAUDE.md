# Claude Code — global rules

## Model roles

Sonnet builds, Opus plans and reviews, Haiku scouts. The main model is `opusplan` (Opus in plan mode, Sonnet executing), the advisor is Opus, and subagents default to Sonnet unless their frontmatter pins a model.

- **Plan gate** — call `EnterPlanMode` as your first action (load it with ToolSearch `select:EnterPlanMode` if it is deferred) when the task will edit 3+ files, or is an audit, migration, refactor or cleanup sweep. Outside plan mode you are Sonnet: the plan gate is the only path to an Opus plan. Already in plan mode, or the user said to skip planning → proceed.
- **Scout** — discovery goes to the `Explore` subagent (Haiku): locating code across more than a couple of files, and fact checks against git history and GitHub (`git log/grep`, `gh pr|issue|label view/list`). Its Bash is hook-limited to read-only commands. Keep its conclusion, leave the dumps in its context. Independent scouts go out in one message; judgement on what the scouts found stays with you or a Sonnet subagent.
- **Design** — frontend UI/UX work (designing, redesigning, polishing or auditing a page, component, design system or tokens) goes to the `ui-designer` subagent. It reads the repo's house style first and returns changed files plus screenshots.
- **Noise** — slow, noisy runs (test suites, log trawls, crawls) go to a subagent that returns only failures and findings.
- **Advisor** — consult it at three checkpoints, and stay with your own judgement on routine edits and shell runs:
  1. Before a multi-file plan locks: missed invariants, schema contracts, ADR conflicts.
  2. When the same test or compiler error fails twice: root cause, or a rabbit hole?
  3. Before declaring done or committing: the full diff against the repo's pre-commit rules.

  When the advice contradicts evidence you hold (a failed step, the file contents), surface the conflict.

## Done

Done means evidence: the command you ran and its output, for each claim. A step you could not run is reported as unverified.

## Skills

`~/.agents/skills/` is canonical: `npx skills` manages it, and Hermes and opencode read it. Each `~/.claude/skills/<name>` is the relative symlink `../../.agents/skills/<name>`. Install a new skill into `~/.agents/skills/` and link it back. `~/.claude/skills/synced` is runtime-managed; it stays a real directory.

## Web

`crawl-router` (in `~/.local/bin`) is the first choice to scrape, search, crawl or research; it picks the backend. Fall back to WebFetch when it returns empty. X/Twitter posts read through `https://api.fxtwitter.com/<user>/status/<id>`.

<!-- agentmemory:start -->
## Agent memory (agentmemory)

You have persistent long-term memory via the agentmemory MCP server. Tools: `memory_recall`, `memory_smart_search`, `memory_save`, `memory_sessions`.

- At the START of a task, call `memory_recall` (or `memory_smart_search`) with the task context to load relevant past decisions, fixes, and preferences before asking the user to repeat anything.
- When you learn something durable (a decision, a fix, a gotcha, a user preference, a project convention), call `memory_save` to persist it.
- Prefer recalling over re-deriving, and save concise reusable facts rather than transcripts.
<!-- agentmemory:end -->
