/**
 * safe-edit-backup — Automatic file backups and git integration for edit/write tools
 *
 * Hooks into built-in edit and write tool calls to:
 * 1. Create timestamped backups before any modification
 * 2. Rotate backups (keep max 5 per file)
 * 3. Auto-commit changes if file is in a git repo,
 *    with a short LLM-generated commit message (<= 40 words)
 *
 * BACKUPS: all backups live centrally under
 *   $XDG_DATA_HOME/safe-edit/backups/<encoded-full-path>/
 * (default ~/.local/share/safe-edit/backups) so project dirs and git
 * worktrees never accumulate .backups folders when iterating on files.
 *
 * COMMIT MESSAGES: after each edit/write in a git repo, the diff (or file
 * content for brand-new files) is summarized by the cheapest available model
 * (prefers openrouter deepseek-v4-flash) and committed with that message.
 * If summarization fails or exceeds ~8s, it falls back to the numeric
 * "update: <file> (+n/-n lines)" message. Never breaks the edit/write call.
 *
 * DOTFILES CONVENTION:
 * - Managed via GNU Stow at ~/dotfiles/
 * - Each config is its own stow package (one dir = one package)
 * - Package structure: <name>/.config/<name>/<file>
 * - Install all: cd ~/dotfiles && stow *
 * - Install single: cd ~/dotfiles && stow <package>
 * - See ~/dotfiles/DOTFILES_CONVENTION.md
 *
 * PACKAGE INSTALLATION PREFERENCE:
 * - Always ask user: global (pacman) or nix/home-manager?
 *
 * This extension runs silently in the background. No user interaction needed.
 */

import {
  isToolCallEventType,
  type ExtensionAPI,
  type ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import type {
  Api,
  AssistantMessageEventStream,
  Context,
  Model,
} from "@earendil-works/pi-ai";
import { execSync, execFileSync } from "node:child_process";
import {
  existsSync,
  mkdirSync,
  copyFileSync,
  readFileSync,
  chmodSync,
  readdirSync,
  unlinkSync,
  realpathSync,
} from "node:fs";
import { dirname, basename, resolve } from "node:path";

const MAX_BACKUPS = 5;
const SUMMARY_TIMEOUT_MS = 8000;
const SUMMARY_MAX_WORDS = 40;
const SUMMARY_PAYLOAD_CAP = 8000; // chars of diff/content sent to the model

// ---- Helpers ----

function getBackupDir(file: string): string {
  const absFile = resolve(file);
  const home = process.env.HOME || "/home/crony";
  const dataHome = process.env.XDG_DATA_HOME || `${home}/.local/share`;
  // Encode the full absolute path so every file gets its own unique backup dir
  const safeName = absFile.replace(/^\//, "").replace(/\//g, "_");
  return `${dataHome}/safe-edit/backups/${safeName}`;
}

function createBackup(file: string): string | null {
  if (file.startsWith("/") === false) {
    file = resolve(file);
  }
  // Resolve through symlinks (for Stow-managed files)
  try {
    file = realpathSync(file);
  } catch {
    // path may not exist yet (e.g. a new write) — proceed without a backup
  }
  if (!existsSync(file)) return null;

  const bdir = getBackupDir(file);
  mkdirSync(bdir, { recursive: true });

  const ts = Date.now();
  const base = basename(file);
  const backupFile = `${bdir}/${base}.${ts}`;

  copyFileSync(file, backupFile);
  try {
    // Make backup read-only for user to prevent accidental edits
    chmodSync(backupFile, 0o600);
  } catch {
    // chmod may fail on some filesystems — the backup itself is what matters
  }

  return backupFile;
}

function rotateBackups(file: string): void {
  // Resolve through symlinks
  try {
    file = realpathSync(file);
  } catch {
    // nothing to resolve — use the path as-is
  }
  const bdir = getBackupDir(file);
  if (!existsSync(bdir)) return;

  const base = basename(file);

  try {
    const files = readdirSync(bdir).filter((f: string) =>
      f.startsWith(base + "."),
    );
    files.sort((a: string, b: string) => {
      const ta = parseInt(a.split(".").pop() || "0", 10);
      const tb = parseInt(b.split(".").pop() || "0", 10);
      return ta - tb;
    });

    if (files.length > MAX_BACKUPS) {
      const toDelete = files.slice(0, files.length - MAX_BACKUPS);
      for (const f of toDelete) {
        try {
          unlinkSync(`${bdir}/${f}`);
        } catch {
          // best-effort rotation — ignore individual failures
        }
      }
    }
  } catch {
    // readdir/rotation failure — ignore, backups are best-effort
  }
}

function isInGitRepo(file: string): string | null {
  let dir = dirname(resolve(file));
  while (dir !== "/") {
    if (existsSync(`${dir}/.git`)) return dir;
    dir = dirname(dir);
  }
  return null;
}

// ---- Commit message generation ----

function normalizeSummary(text: string): string {
  let t = text
    .replace(/```[\s\S]+?```/g, " ") // strip code fences
    .replace(/`+/g, " ") // strip inline code ticks
    .replace(/^["'\s]+|["'\s]+$/g, ""); // strip outer quotes
  t = t.replace(/\s+/g, " ").trim(); // single line
  const words = t.split(" ").filter(Boolean);
  if (words.length > SUMMARY_MAX_WORDS) {
    t = words.slice(0, SUMMARY_MAX_WORDS).join(" ");
  }
  return t;
}

function withTimeout<T>(promise: Promise<T>, ms: number): Promise<T> {
  let timer: ReturnType<typeof setTimeout> | undefined;
  const timeout = new Promise<never>((_resolve, reject) => {
    timer = setTimeout(
      () => reject(new Error(`summarize timed out after ${ms}ms`)),
      ms,
    );
  });
  return Promise.race([promise, timeout]).finally(() => {
    if (timer) clearTimeout(timer);
  });
}

function pickSummaryModel(ctx: ExtensionContext): Model<Api> | null {
  // Fast cheap models, provider order matters (openrouter needs no session header)
  const preferred: Array<[string, string]> = [
    ["openrouter", "deepseek/deepseek-v4-flash"],
    ["opencode", "deepseek-v4-flash"],
  ];
  for (const [provider, modelId] of preferred) {
    const model = ctx.modelRegistry.find(provider, modelId);
    if (model && ctx.modelRegistry.hasConfiguredAuth(model)) return model;
  }
  // Last resort: cheapest available text-capable model
  const available = ctx.modelRegistry
    .getAvailable()
    .filter(
      (m) =>
        m.input.includes("text") && ctx.modelRegistry.hasConfiguredAuth(m),
    );
  available.sort(
    (a, b) => a.cost.input + a.cost.output - (b.cost.input + b.cost.output),
  );
  return available[0] ?? null;
}

/**
 * Ask a cheap model to summarize the diff (or the file content, for new
 * files) into a short imperative commit message. Returns null on any failure
 * so the caller can fall back to a numeric "update: <file>" message.
 */
async function summarizeCommit(
  file: string,
  gitRoot: string,
  ctx: ExtensionContext,
): Promise<string | null> {
  const model = pickSummaryModel(ctx);
  if (!model) return null;

  // Detect brand-new (untracked) files
  let untracked = false;
  try {
    const status = execSync(`git status --porcelain -- "${file}"`, {
      cwd: gitRoot,
      encoding: "utf-8",
      stdio: ["pipe", "pipe", "pipe"],
    }).trim();
    untracked = status.startsWith("??");
  } catch {
    return null;
  }

  let payload: string;
  let instruction: string;
  try {
    if (untracked) {
      const content = readFileSync(file, "utf-8").slice(0, SUMMARY_PAYLOAD_CAP);
      if (content.trim().length === 0) return null; // empty new file
      payload = content;
      instruction = "This is a NEW file — describe what it adds or does.";
    } else {
      let diff = "";
      try {
        diff = execSync(`git diff HEAD --no-color -- "${file}"`, {
          cwd: gitRoot,
          encoding: "utf-8",
          stdio: ["pipe", "pipe", "pipe"],
        }).trim();
      } catch {
        // repo may have no commits yet — leave diff empty
      }
      if (!diff) return null; // nothing changed vs HEAD → fall back
      payload = diff.slice(0, SUMMARY_PAYLOAD_CAP);
      instruction = "Describe the change.";
    }
  } catch {
    return null;
  }

  const systemPrompt =
    "You write short git commit messages for a developer's dotfiles and " +
    "personal projects. Reply with ONLY the commit message: one line, " +
    "imperative mood, no quotes, no markdown, no newlines, under " +
    `${SUMMARY_MAX_WORDS} words.`;

  const prompt = `${basename(file)}\n\n${instruction}\n\n---\n${payload}`;

  const context: Context = {
    systemPrompt,
    messages: [{ role: "user", content: prompt, timestamp: Date.now() }],
  };

  try {
    const stream: AssistantMessageEventStream = ctx.modelRegistry.streamSimple(
      model,
      context,
      { maxTokens: 120, temperature: 0.2 },
    );
    const message = await withTimeout(stream.result(), SUMMARY_TIMEOUT_MS);
    if (
      !message ||
      message.stopReason === "error" ||
      message.stopReason === "aborted"
    ) {
      return null;
    }
    const text = message.content
      .filter((part) => part.type === "text")
      .map((part) => part.text)
      .join(" ")
      .trim();
    if (!text) return null;
    return normalizeSummary(text);
  } catch {
    return null;
  }
}

async function generateCommitMessage(
  file: string,
  gitRoot: string,
  ctx: ExtensionContext,
): Promise<string> {
  const summarized = await summarizeCommit(file, gitRoot, ctx);
  if (summarized) return summarized;

  // Fallback: numeric diff summary (or plain update)
  const base = basename(file);
  try {
    const result = execSync(`git diff --numstat "${file}"`, {
      cwd: gitRoot,
      encoding: "utf-8",
      stdio: ["pipe", "pipe", "pipe"],
    }).trim();
    if (result) {
      const [added, deleted] = result.split("\t");
      const a = parseInt(added || "0", 10);
      const d = parseInt(deleted || "0", 10);
      if (a > 0 && d > 0) return `update: ${base} (+${a}, -${d} lines)`;
      if (a > 0) return `update: ${base} (+${a} lines)`;
      if (d > 0) return `update: ${base} (-${d} lines)`;
      return `update: ${base}`;
    }
  } catch {
    // git diff unavailable — fall through to a generic message
  }
  return `update: ${base}`;
}

// ---- Git / yadm / chezmoi commits ----

async function gitCommitIfNeeded(file: string, ctx: ExtensionContext): Promise<void> {
  // Resolve through symlinks (for Stow-managed files)
  let realFile: string;
  try {
    realFile = realpathSync(file);
  } catch {
    realFile = resolve(file);
  }
  const gitRoot = isInGitRepo(realFile);
  if (!gitRoot) return;
  if (!existsSync(realFile)) return;

  try {
    // Check if file has unstaged changes
    const status = execSync(`git status --porcelain -- "${realFile}"`, {
      cwd: gitRoot,
      encoding: "utf-8",
      stdio: ["pipe", "pipe", "pipe"],
    }).trim();

    if (!status) return;

    const msg = await generateCommitMessage(realFile, gitRoot, ctx);

    // Stage and commit (only this file, not other pre-staged files).
    // Use execFileSync with separate args to avoid shell-quoting issues.
    execFileSync("git", ["add", "--", realFile], {
      cwd: gitRoot,
      stdio: "pipe",
    });
    execFileSync(
      "git",
      ["commit", "-m", msg, "--no-gpg-sign", "--", realFile],
      {
        cwd: gitRoot,
        stdio: "pipe",
      },
    );
  } catch {
    // git commit is best-effort — never break the edit/write call
  }
}

function isYadmManaged(file: string): boolean {
  try {
    const result = execSync(`yadm status "${file}" 2>/dev/null`, {
      encoding: "utf-8",
      stdio: ["pipe", "pipe", "pipe"],
    });
    return result.trim().length > 0;
  } catch {
    return false;
  }
}

function yadmCommit(file: string): void {
  if (!isYadmManaged(file)) return;

  try {
    const msg = `update: ${basename(file)}`;
    execSync(
      `yadm add "${file}" 2>/dev/null && yadm commit -m "${msg}" 2>/dev/null`,
      {
        stdio: ["pipe", "pipe", "pipe"],
      },
    );
  } catch {
    // yadm not present or commit failed — ignore, backups are best-effort
  }
}

function isChezmoiManaged(file: string): boolean {
  try {
    const result = execSync(`chezmoi managed "${file}" 2>/dev/null`, {
      encoding: "utf-8",
      stdio: ["pipe", "pipe", "pipe"],
    });
    return result.trim().length > 0;
  } catch {
    return false;
  }
}

function chezmoiCommit(file: string): void {
  try {
    const src = execSync(`chezmoi source-path "${file}" 2>/dev/null`, {
      encoding: "utf-8",
      stdio: ["pipe", "pipe", "pipe"],
    }).trim();
    if (!src || !existsSync(src)) return;

    const gitRoot = isInGitRepo(src);
    if (!gitRoot) return;

    const msg = `update: ${basename(file)}`;
    execSync(
      `git add "${src}" 2>/dev/null && git commit -m "${msg}" --no-gpg-sign 2>/dev/null`,
      {
        cwd: gitRoot,
        stdio: ["pipe", "pipe", "pipe"],
      },
    );
  } catch {
    // chezmoi commit is best-effort — don't block the tool call
  }
}

async function commitIfManaged(
  file: string,
  ctx: ExtensionContext,
): Promise<void> {
  await gitCommitIfNeeded(file, ctx);
  if (isYadmManaged(file)) yadmCommit(file);
  if (isChezmoiManaged(file)) chezmoiCommit(file);
}

// ---- Extension ----

export default function (pi: ExtensionAPI) {
  // Intercept tool calls to create backups BEFORE the tool runs
  pi.on("tool_call", async (event) => {
    // Handle edit tool
    if (isToolCallEventType("edit", event)) {
      const filePath = event.input.path;
      if (filePath) {
        const bak = createBackup(filePath);
        if (bak) {
          rotateBackups(filePath);
        }
      }
    }

    // Handle write tool
    if (isToolCallEventType("write", event)) {
      const filePath = event.input.path;
      if (filePath) {
        // For write, back up existing file if it exists
        const bak = createBackup(filePath);
        if (bak) {
          rotateBackups(filePath);
        }
      }
    }
  });

  // After tool execution, commit changes if managed
  pi.on("tool_result", async (event, ctx) => {
    if (event.toolName === "edit" || event.toolName === "write") {
      const input = event.input as { path?: string };
      if (input?.path) {
        await commitIfManaged(input.path, ctx);
      }
    }
  });
}