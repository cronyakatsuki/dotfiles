/**
 * safety-gate — mechanical safety layer for pi
 *
 * Two independent gates, both hooking `tool_call` (covers direct model calls
 * AND nested calls from codemode's tools.*):
 *
 * 1. Destructive bash gate:
 *    If a bash command matches a dangerous pattern (configurable regexes),
 *    ask for confirmation first. Non-interactive sessions are blocked by
 *    default (fail-safe).
 *
 * 2. Path protection (write/edit tools):
 *    - blockedPaths   → hard block, no prompt
 *    - protectedPaths → confirm before proceeding
 *
 * All patterns/paths live in ~/.pi/agent/config/safety-gate.json
 * (falls back to the built-in defaults below). Edit the config and restart
 * pi to apply changes; there is nothing to change in this file.
 *
 * Adapted from /usr/lib/pi/examples/extensions/permission-gate.ts and
 * protected-paths.ts. 2026-11-18.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

interface SafetyGateConfig {
	dangerousPatterns: string[]; // JS regex sources, matched case-insensitively against bash command
	blockedPaths: string[]; // substrings; write/edit to matching paths is hard-blocked
	protectedPaths: string[]; // substrings; write/edit to matching paths asks for confirmation
	blockWhenNoUI: boolean; // non-interactive sessions: block instead of auto-allow
}

const DEFAULT_CONFIG: SafetyGateConfig = {
	dangerousPatterns: [
		// deletion / recursion
		String.raw`\brm\s+(-[a-z]*[rvf]|--recursive)`,
		String.raw`\brmdir\b`,
		// privilege / system modification
		String.raw`\bsudo\b`,
		String.raw`\bdoas\b`,
		// disk destruction
		String.raw`\bdd\b.*\bof=`,
		String.raw`\bmkfs`,
		String.raw`\bshred\b`,
		// dangerous perms
		String.raw`\b(chmod|chown)\b.*\b777\b`,
		// destructive git
		String.raw`\bgit\s+push\b.*(--force|-f)\b`,
		String.raw`\bgit\s+reset\s+--hard\b`,
		String.raw`\bgit\s+clean\s+(-[a-z]*f|--force)`,
		// package removal (installs go through -S without a prompt; removals are riskier)
		String.raw`\b(pacman|-Sapt|dnf|zypper)\b.*\s(-R|--remove)`,
		String.raw`\bpip\s+uninstall\b`,
		String.raw`\bnpm\s+uninstall\b`,
		// service shutdown
		String.raw`\bsystemctl\s+(disable|stop|mask)\b`,
	],
	blockedPaths: [".ssh/", ".gnupg/"],
	protectedPaths: [".env", "node_modules/", "/etc/"],
	blockWhenNoUI: true,
};

function loadConfig(): SafetyGateConfig {
	const configPath = join(homedir(), ".pi/agent/config/safety-gate.json");
	try {
		const raw = JSON.parse(readFileSync(configPath, "utf8"));
		// merge over defaults so a partial config still works
		return { ...DEFAULT_CONFIG, ...raw };
	} catch {
		return DEFAULT_CONFIG; // missing or broken config → defaults
	}
}

export default function (pi: ExtensionAPI) {
	const cfg = loadConfig();
	const patterns = cfg.dangerousPatterns.map((p) => new RegExp(p, "i"));

	pi.on("tool_call", async (event, ctx) => {
		// ---- Gate 1: destructive bash ----
		if (event.toolName === "bash") {
			const command = String(event.input.command ?? "");
			const hit = patterns.find((p) => p.test(command));
			if (!hit) return undefined;

			if (!ctx.hasUI) {
				if (cfg.blockWhenNoUI) {
					return {
						block: true,
						reason: `safety-gate: dangerous command and no UI to confirm: ${command}`,
					};
				}
				return undefined; // non-interactive + allow: proceed silently
			}

			const choice = await ctx.ui.select(
				`⚠️ safety-gate: potentially dangerous command:\n\n  ${command}\n\nAllow?`,
				["Yes", "No"],
			);
			if (choice !== "Yes") {
				return { block: true, reason: `safety-gate: blocked by user (matched ${hit.source})` };
			}
			return undefined; // explicitly allowed this time
		}

		// ---- Gate 2: path protection (write / edit) ----
		if (event.toolName === "write" || event.toolName === "edit") {
			const path = String(event.input.path ?? "");
			if (!path) return undefined;

			if (cfg.blockedPaths.some((p) => path.includes(p))) {
				if (ctx.hasUI) {
					ctx.ui.notify(`safety-gate: blocked write to forbidden path: ${path}`, "warning");
				}
				return { block: true, reason: `safety-gate: path "${path}" is forbidden` };
			}

			if (cfg.protectedPaths.some((p) => path.includes(p))) {
				if (!ctx.hasUI) {
					if (cfg.blockWhenNoUI) {
						return { block: true, reason: `safety-gate: protected path "${path}", no UI to confirm` };
					}
					return undefined;
				}
				const choice = await ctx.ui.select(
					`⚠️ safety-gate: write to protected path:\n\n  ${path}\n\nAllow?`,
					["Yes", "No"],
				);
				if (choice !== "Yes") {
					return { block: true, reason: `safety-gate: protected path "${path}" — blocked by user` };
				}
			}
		}

		return undefined;
	});
}
