/**
 * safe-edit-backup — Automatic file backups and git integration for edit/write tools
 *
 * Hooks into built-in edit and write tool calls to:
 * 1. Create timestamped backups before any modification
 * 2. Rotate backups (keep max 5 per file)
 * 3. Auto-commit changes if file is in a git repo
 *
 * DOTFILES CONVENTION:
 * - Managed via GNU Stow at ~/dotfiles/
 * - Each config is its own stow package (one dir = one package)
 * - Package structure: <name>/.config/<name>/<file>
 * - Install all: cd ~/dotfiles && stow */
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
} from "@earendil-works/pi-coding-agent";
import { execSync } from "node:child_process";
import { existsSync, mkdirSync, copyFileSync, readFileSync, writeFileSync, realpathSync } from "node:fs";
import { dirname, basename, resolve } from "node:path";

const MAX_BACKUPS = 5;

// ---- Helpers ----

function getBackupDir(file: string): string {
  const absFile = resolve(file);
  const dir = dirname(absFile);
  const home = process.env.HOME || "/home/crony";

  // For system/home config files, use XDG data home
  if (dir === home || dir.startsWith(`${home}/.config`) || dir.startsWith("/etc")) {
    const dataHome = process.env.XDG_DATA_HOME || `${home}/.local/share`;
    const safeName = absFile.replace(/^\//, "").replace(/\//g, "_");
    return `${dataHome}/safe-edit/backups/${safeName}`;
  }

  // For project files, use local .backups dir
  return `${dir}/.backups`;
}

function createBackup(file: string): string | null {
  if (file.startsWith("/") === false) {
    file = resolve(file);
  }
  // Resolve through symlinks (for Stow-managed files)
  try {
    file = realpathSync(file);
  } catch {}
  if (!existsSync(file)) return null;

  const bdir = getBackupDir(file);
  mkdirSync(bdir, { recursive: true });

  const ts = Date.now();
  const base = basename(file);
  const backupFile = `${bdir}/${base}.${ts}`;

  copyFileSync(file, backupFile);
  try {
    // Make backup read-only for user to prevent accidental edits
    const { chmodSync } = require("node:fs");
    chmodSync(backupFile, 0o600);
  } catch {}

  return backupFile;
}

function rotateBackups(file: string): void {
  // Resolve through symlinks
  try {
    file = realpathSync(file);
  } catch {}
  const bdir = getBackupDir(file);
  if (!existsSync(bdir)) return;

  const base = basename(file);
  const backups: string[] = [];

  try {
    const { readdirSync } = require("node:fs");
    const files = readdirSync(bdir).filter((f: string) => f.startsWith(base + "."));
    files.sort((a: string, b: string) => {
      const ta = parseInt(a.split(".").pop() || "0", 10);
      const tb = parseInt(b.split(".").pop() || "0", 10);
      return ta - tb;
    });

    if (files.length > MAX_BACKUPS) {
      const toDelete = files.slice(0, files.length - MAX_BACKUPS);
      for (const f of toDelete) {
        try {
          const { unlinkSync } = require("node:fs");
          unlinkSync(`${bdir}/${f}`);
        } catch {}
      }
    }
  } catch {}
}

function isInGitRepo(file: string): string | null {
  let dir = dirname(resolve(file));
  while (dir !== "/") {
    if (existsSync(`${dir}/.git`)) return dir;
    dir = dirname(dir);
  }
  return null;
}

function generateCommitMessage(file: string, gitRoot: string): string {
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
  } catch {}
  return `update: ${base}`;
}

function gitCommitIfNeeded(file: string): void {
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
    const status = execSync(`git status --porcelain "${realFile}"`, {
      cwd: gitRoot,
      encoding: "utf-8",
      stdio: ["pipe", "pipe", "pipe"],
    }).trim();

    if (!status) return;

    const msg = generateCommitMessage(realFile, gitRoot);

    // Stage and commit (only this file, not other pre-staged files)
    execSync(`git add "${realFile}"`, {
      cwd: gitRoot,
      stdio: ["pipe", "pipe", "pipe"],
    });

    execSync(`git commit -m "${msg.replace(/"/g, '\\"')}" --no-gpg-sign -- "${realFile}" 2>/dev/null`, {
      cwd: gitRoot,
      stdio: ["pipe", "pipe", "pipe"],
    });
  } catch {}
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
    execSync(`yadm add "${file}" 2>/dev/null && yadm commit -m "${msg}" 2>/dev/null`, {
      stdio: ["pipe", "pipe", "pipe"],
    });
  } catch {}
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
    execSync(`git add "${src}" 2>/dev/null && git commit -m "${msg}" --no-gpg-sign 2>/dev/null`, {
      cwd: gitRoot,
      stdio: ["pipe", "pipe", "pipe"],
    });
  } catch {}
}

function commitIfManaged(file: string): void {
  gitCommitIfNeeded(file);
  if (isYadmManaged(file)) yadmCommit(file);
  if (isChezmoiManaged(file)) chezmoiCommit(file);
}

// ---- Extension ----

export default function (pi: ExtensionAPI) {
  // Intercept tool calls to create backups BEFORE the tool runs
  pi.on("tool_call", async (event, _ctx) => {
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
  pi.on("tool_result", async (event, _ctx) => {
    if (event.toolName === "edit" || event.toolName === "write") {
      const input = event.input as { path?: string };
      if (input?.path) {
        commitIfManaged(input.path);
      }
    }
  });
}
