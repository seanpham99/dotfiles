/**
 * repo-guards: run the shared agent guard hooks inside omp.
 *
 * - Every agent: bash, write and edit calls go through the nearest repo guard
 *   above the working directory: `.agents/hooks/guard.sh`, else the legacy
 *   `.claude/hooks/guard.sh` (repo rules such as alpha-lab's prod-path,
 *   generated-file and compose-up guards).
 * - The `scout` agent: bash calls go through ~/.agents/hooks/readonly-shell.sh,
 *   so scout can read git history and GitHub state but cannot change anything.
 *
 * Hooks speak the common PreToolUse contract: JSON on stdin with tool_name
 * (Bash|Write|Edit), tool_input and cwd; exit 2 blocks, stderr is the reason.
 * The hook scripts stay the single source of truth for every agent harness.
 */
import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";

const READONLY_HOOK = join(homedir(), ".agents/hooks/readonly-shell.sh");
const REPO_GUARDS = [".agents/hooks/guard.sh", ".claude/hooks/guard.sh"];
const HOOK_TOOL: Record<string, string> = { bash: "Bash", write: "Write", edit: "Edit" };

function repoGuard(cwd: string): string | undefined {
  for (let dir = resolve(cwd); ; dir = dirname(dir)) {
    for (const rel of REPO_GUARDS) {
      const hook = join(dir, rel);
      if (existsSync(hook)) return hook;
    }
    if (dirname(dir) === dir) return undefined;
  }
}

function runHook(hook: string, payload: object): string | undefined {
  const res = spawnSync("bash", [hook], { input: JSON.stringify(payload), encoding: "utf8", timeout: 10_000 });
  if (res.status === 2) return (res.stderr || `blocked by ${hook}`).trim();
  return undefined;
}

export default function (pi: any) {
  pi.on("tool_call", async (event: any, ctx: any) => {
    const tool = HOOK_TOOL[event.toolName];
    if (!tool) return undefined;
    const agent = ctx?.agent?.name ?? ctx?.agentName ?? ctx?.session?.agent;
    const cwd = ctx?.cwd ?? process.cwd();
    const input = event.input ?? {};
    const toolInput =
      tool === "Bash"
        ? { command: String(input.command ?? "") }
        : { file_path: resolve(cwd, String(input.path ?? input.file_path ?? "")) };

    if (agent === "scout" && tool === "Bash" && existsSync(READONLY_HOOK)) {
      const reason = runHook(READONLY_HOOK, { tool_name: tool, tool_input: toolInput });
      if (reason) return { block: true, reason };
    }

    const guard = repoGuard(cwd);
    if (guard) {
      const reason = runHook(guard, { tool_name: tool, cwd, tool_input: toolInput });
      if (reason) return { block: true, reason };
    }
    return undefined;
  });
}
