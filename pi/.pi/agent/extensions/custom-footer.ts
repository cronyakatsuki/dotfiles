/**
 * Custom Footer Extension (powerline-inspired)
 *
 * Layout (bottom line):  ~shortdir on branch  ...  model • thinking · ctx% · $cost · git extras · env · ⏱duration · HH:MM
 * Above it: extension statuses (shift-router, pi-lens) - word-wrapped, never truncated.
 *
 * Uses only the public ExtensionContext API.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { visibleWidth, truncateToWidth } from "@earendil-works/pi-tui";
import { exec } from "node:child_process";

export default function (pi: ExtensionAPI) {
	pi.on("session_start", (_event, ctx) => {
		ctx.ui.setFooter((tui, theme, footerData) => {
			const sessionStart = Date.now();
			const cwd = ctx.cwd;
			let lastMinute = -1;

			// Git worktree state, refreshed asynchronously every 10s.
			const gitExtras = { value: "" };
			const fetchGit = () => {
				if (!footerData.getGitBranch()) {
					gitExtras.value = "";
					return;
				}
				exec(
					"git --no-optional-locks status --porcelain",
					{ encoding: "utf8", cwd },
					(err, stdout) => {
						if (err) return;
						const staged = (stdout.match(/^[AMDRC]/gm) || []).length;
						const unstaged = (stdout.match(/^.[MD]/gm) || []).length;
						const untracked = (stdout.match(/^\?\?/gm) || []).length;
						exec(
							"git --no-optional-locks rev-list --count --left-right @{u}...HEAD",
							{ encoding: "utf8", cwd },
							(err2, out2) => {
								let ahead = 0;
								let behind = 0;
								if (!err2 && out2 && out2.includes("\t")) {
									const [b, a] = out2.trim().split("\t");
									behind = parseInt(b, 10) || 0;
									ahead = parseInt(a, 10) || 0;
								}
								let s = "";
								if (staged > 0) s += `+${staged}`;
								if (unstaged > 0) s += `!${unstaged}`;
								if (untracked > 0) s += `?${untracked}`;
								if (ahead > 0) s += `⇡${ahead}`;
								if (behind > 0) s += `⇣${behind}`;
								if (s !== gitExtras.value) {
									gitExtras.value = s;
									tui.requestRender();
								}
							},
						);
					},
				);
			};

			// Refresh once a minute (clock/duration) and every 10s (git status).
			const clockTimer = setInterval(() => {
				const m = new Date().getMinutes();
				if (m !== lastMinute) {
					lastMinute = m;
					tui.requestRender();
				}
				fetchGit();
			}, 10_000);

			const unsubBranch = footerData.onBranchChange(() => {
				fetchGit();
				tui.requestRender();
			});

			fetchGit();

			const fmt = (n: number): string => {
				if (n < 1000) return `${n}`;
				if (n < 10000) return `${(n / 1000).toFixed(1)}k`;
				if (n < 1_000_000) return `${Math.round(n / 1000)}k`;
				if (n < 10_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
				return `${Math.round(n / 1_000_000)}M`;
			};

			const fmtDuration = (ms: number): string => {
				const s = Math.floor(ms / 1000);
				if (s >= 3600)
					return `${Math.floor(s / 3600)}h${Math.floor((s % 3600) / 60)}m`;
				if (s >= 60) return `${Math.floor(s / 60)}m`;
				return `${s}s`;
			};

			const shortDir = (): string => {
				const home = process.env.HOME || process.env.USERPROFILE || "";
				let d = cwd;
				if (home && d.startsWith(home)) d = "~" + d.slice(home.length);
				const parts = d.split("/");
				if (parts.length > 4) d = parts.slice(parts.length - 4).join("/");
				return d;
			};

			// nix / direnv environment indicator.
			const envStatus = (): string => {
				const nix = process.env.IN_NIX_SHELL;
				const envrc = process.env.DIRENV_FILE;
				const parts: string[] = [];
				if (nix) parts.push("nix");
				if (envrc) {
					const project = envrc.split("/").filter(Boolean).slice(-2, -1)[0];
					parts.push(project ? `direnv:${project}` : "direnv");
				}
				return parts.join("+");
			};

			// Cost across the whole session (assistant + tool results + compaction).
			const totalCost = (): number => {
				let cost = 0;
				for (const e of ctx.sessionManager.getEntries()) {
					if (e.type !== "message") continue;
					const msg = e.message as {
						role?: string;
						usage?: { cost?: { total?: number } };
					};
					if (msg?.role === "assistant") cost += msg.usage?.cost?.total ?? 0;
				}
				return cost;
			};

			return {
				dispose() {
					clearInterval(clockTimer);
					unsubBranch();
				},
				invalidate() {},
				render(width: number): string[] {
					const RESET = "\x1b[0m";
					const BOLD = "\x1b[1m";
					// Raw ANSI 256 palette (same hues powerline-footer used) so we don't
					// depend on theme token names that may not exist (e.g. "peach").
					const red = "\x1b[38;5;211m";
					const yellow = "\x1b[38;5;222m";
					const green = "\x1b[38;5;150m";
					const peach = "\x1b[38;5;216m";
					const mauve = "\x1b[38;5;183m";
					const blue = "\x1b[38;5;111m";
					const sky = "\x1b[38;5;117m";
					const overlay = "\x1b[38;5;103m";

					// Context usage
					const cu = ctx.getContextUsage();
					const window = cu?.contextWindow ?? ctx.model?.contextWindow ?? 0;
					const pct = cu?.percent;
					const used = cu?.tokens;

					let ctxInfo = "?";
					if (
						pct !== null &&
						pct !== undefined &&
						used !== null &&
						used !== undefined
					) {
						const remaining = 100 - pct;
						let color = green;
						if (remaining < 20) color = red;
						else if (remaining < 50) color = yellow;
						const pctS = pct % 1 === 0 ? pct.toFixed(0) : pct.toFixed(1);
						ctxInfo = `${color}${fmt(used)}/${fmt(window)} (${pctS}%)${RESET}`;
					}

					const cost = totalCost();
					const usingSub = ctx.model
						? ctx.modelRegistry.isUsingOAuth(ctx.model)
						: false;
					const costInfo =
						cost > 0 || usingSub
							? `${peach}$${cost.toFixed(3)}${usingSub ? " (sub)" : ""}${RESET}`
							: "";

					// Model + thinking
					const modelName = ctx.model?.name || ctx.model?.id || "no-model";
					let modelThinking = `${overlay}${modelName}${RESET}`;
					if (ctx.model?.reasoning) {
						const lvl = ctx.thinkingLevel || "off";
						modelThinking += ` • ${overlay}${lvl === "off" ? "thinking off" : lvl}${RESET}`;
					}

					// Git extras (staged/unstaged/untracked/ahead/behind)
					const gitInfo = gitExtras.value ? `${red}${gitExtras.value}${RESET}` : "";

					// nix / direnv indicator
					const env = envStatus();
					const envInfo = env ? `${sky}(${env})${RESET}` : "";

					// Duration + clock
					const duration = `${overlay}${fmtDuration(Date.now() - sessionStart)}${RESET}`;
					const now = new Date();
					const clock = `${overlay}${String(now.getHours()).padStart(2, "0")}:${String(
						now.getMinutes(),
					).padStart(2, "0")}${RESET}`;

					const branch = footerData.getGitBranch();
					const branchInfo = branch ? `${overlay} on ${branch}${RESET}` : "";
					const sessionName = ctx.sessionManager.getSessionName();
					const sessionBadge = sessionName
						? `${mauve}[${sessionName}]${RESET} `
						: "";
					const left = `${sessionBadge}${BOLD}${blue}${shortDir()}${RESET}${branchInfo}`;

					const rightParts = [modelThinking, ctxInfo];
					if (costInfo) rightParts.push(costInfo);
					if (gitInfo) rightParts.push(gitInfo);
					if (envInfo) rightParts.push(envInfo);
					rightParts.push(duration, clock);
					const right = rightParts.filter(Boolean).join(" · ");

					const leftW = visibleWidth(left);
					const rightW = visibleWidth(right);
					const minPad = 2;
					let statsLine: string;
					if (leftW + minPad + rightW <= width) {
						statsLine = left + " ".repeat(width - leftW - rightW) + right;
					} else {
						const avail = Math.max(0, width - rightW - minPad);
						if (avail > 0) {
							const tLeft = truncateToWidth(left, avail, "");
							const tLeftW = visibleWidth(tLeft);
							statsLine =
								tLeft + " ".repeat(Math.max(minPad, width - tLeftW - rightW)) + right;
						} else {
							statsLine = truncateToWidth(right, width, "");
						}
					}

					const lines: string[] = [];

					// Extension statuses — wrapped, never truncated.
					const statuses = footerData.getExtensionStatuses();
					if (statuses.size > 0) {
						const parts = Array.from(statuses.entries())
							.sort(([a], [b]) => a.localeCompare(b))
							.map(([, t]) =>
								t
									.replace(/[\r\n\t]/g, " ")
									.replace(/ +/g, " ")
									.trim(),
							)
							.filter(Boolean);
						const combined = parts.join("  •  ");
						if (combined) {
							const words = combined.split(" ");
							let cur = "";
							for (const w of words) {
								const test = cur ? `${cur} ${w}` : w;
								if (visibleWidth(test) <= width) {
									cur = test;
								} else {
									if (cur) lines.push(theme.fg("dim", cur));
									cur = w;
								}
							}
							if (cur) lines.push(theme.fg("dim", cur));
						}
					}

					// Stats line is always closest to the editor.
					lines.push(statsLine);
					return lines;
				},
			};
		});
	});
}
