/**
 * Jev router — a virtual model (`jev/auto`) that plans on a strong model and implements on a cheap one.
 *
 * Adapted from /usr/lib/pi/examples/extensions/jev-router.ts to this user's model set:
 *
 * - The Jev classifier (opencode/jev-1.13, fallback opencode/jev-1.13-free) rates the first user
 *   message into one of four tiers:
 *     trivial  -> opencode-go/glm-5.3-flash      (plans AND implements, stays put)
 *     routine  -> opencode-go/mimo-v2.6-pro      (plans AND implements, stays put)
 *     hard     -> opencode-go/kimi-k3.1-pro      (plans AND implements, stays put)
 *     frontier -> opencode/gpt-6.1-sol plans, then after the first successful edit/write the
 *                 rest of the turn switches to opencode-go/kimi-k3.1-pro (single cache miss)
 * - If the classifier is unavailable, falls back to `hard` (kimi-k3.1-pro).
 * - Compaction/summary and other out-of-loop (`direct`) requests go to opencode-go/glm-5.3-flash.
 *
 * The phase is router state: Pi stores it on the session branch, so it follows the session tree
 * and survives compaction. The selected thinking level passes through to the chosen model.
 *
 * Requires opencode credentials (OPENCODE_API_KEY). Select with: --model jev/auto or /model.
 */

import type { Message } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext, ModelRoute, ModelRouteRequest } from "@earendil-works/pi-coding-agent";

/** Providers as they appear in enabledModels (e.g. "opencode/gpt-6.1-sol"). */
const GO = "opencode-go";
const ZEN = "opencode";

const TRIVIAL = "glm-5.3-flash";
const ROUTINE = "mimo-v2.6-pro";
const HARD = "kimi-k3.1-pro";
const FRONTIER = "gpt-6.1-sol";
const CHEAP = "glm-5.3-flash";

/** Tools whose successful result means implementation has started. */
const EDIT_TOOLS = new Set(["edit", "write"]);

type Tier = "trivial" | "routine" | "hard" | "frontier";

interface JevState {
	phase: "plan" | "build";
	/** Model handling the current phase. */
	model: string;
}

type JevRequest = ModelRouteRequest<JevState>;

function routeTo(request: JevRequest, ctx: ExtensionContext, provider: string, id: string, state?: JevState): ModelRoute<JevState> {
	const model = ctx.modelRegistry.find(provider, id);
	if (!model) throw new Error(`Model ${provider}/${id} is not in the catalog`);
	return { model, thinkingLevel: request.thinkingLevel, state };
}

function lastUserText(messages: readonly Message[]): string {
	const content = messages.filter((message) => message.role === "user").at(-1)?.content ?? "";
	if (typeof content === "string") return content;
	return content.flatMap((block) => (block.type === "text" ? [block.text] : [])).join("\n");
}

/** Whether a tool call since the last user message edited a file successfully. */
function editedThisTurn(messages: readonly Message[]): boolean {
	const lastUser = messages.findLastIndex((message) => message.role === "user");
	return messages
		.slice(lastUser + 1)
		.some((message) => message.role === "toolResult" && EDIT_TOOLS.has(message.toolName) && !message.isError);
}

/** Tier for a new session: rated by the Jev classifier, `hard` when Jev is unavailable. */
async function chooseTier(request: JevRequest, ctx: ExtensionContext): Promise<Tier> {
	// Keep a tier model the session already uses, so switching to jev/auto costs no cache miss.
	const previous = request.previous?.model;
	if (previous?.id === TRIVIAL) return "trivial";
	if (previous?.id === ROUTINE) return "routine";
	if (previous?.id === HARD) return "hard";
	if (previous?.id === FRONTIER) return "frontier";

	const jev =
		ctx.modelRegistry.findOfType("classifier", ZEN === "opencode" ? "opencode" : "opencode", "jev-1.13") ??
		ctx.modelRegistry.findOfType("classifier", "opencode", "jev-1.13-free");
	if (!jev) return "hard";
	const result = await ctx.modelRegistry.classify(
		jev,
		{
			state: { prompt: lastUserText(request.messages).slice(0, 16_000) },
			questions: {
				tier: {
					type: "choice",
					instructions: "How demanding is the software engineering work requested in `prompt`?",
					criteria: {
						trivial: "Typos, small config or text edits, quick questions, and simple reviews",
						routine: "Ordinary features and straightforward but non-trivial coding work",
						hard: "Subtle design, cross-cutting changes, or hard debugging and terminal work",
						frontier: "High-stakes architecture or genuinely novel/frontier reasoning",
					},
				},
			},
		},
		{ signal: request.signal },
	);
	const answer = result.stopReason === "stop" ? result.answers.tier : undefined;
	if (answer?.type !== "choice") return "hard";
	const probs = answer.probabilities as Partial<Record<Tier, number>>;
	const ranked = (["frontier", "hard", "routine", "trivial"] as Tier[])
		.map((t) => [t, probs[t] ?? 0] as const)
		.sort((a, b) => b[1] - a[1]);
	return ranked[0][1] >= 0.5 ? ranked[0][0] : "hard";
}

/** Initial router state for a tier. */
function tierState(tier: Tier): JevState {
	if (tier === "trivial") return { phase: "build", model: TRIVIAL };
	if (tier === "routine") return { phase: "build", model: ROUTINE };
	if (tier === "hard") return { phase: "build", model: HARD };
	return { phase: "plan", model: FRONTIER };
}

export default function (pi: ExtensionAPI) {
	pi.registerVirtualModel<JevState>({
		provider: "jev",
		id: "auto",
		name: "Auto (Jev)",
		thinkingLevels: ["off", "low", "medium", "high", "xhigh"],
		async route(request, ctx) {
			// Compaction summaries and other out-of-loop requests go to the cheap model.
			if (request.reason === "direct") return routeTo(request, ctx, GO, CHEAP);

			const state = request.state;
			if (!state) {
				const tier = await chooseTier(request, ctx);
				return routeTo(request, ctx, tier === "frontier" ? ZEN : GO, tierState(tier).model, tierState(tier));
			}

			// Frontier planning model made the first edit: hand the rest of the turn to kimi.
			if (state.phase === "plan" && state.model === FRONTIER && editedThisTurn(request.messages)) {
				return routeTo(request, ctx, GO, HARD, { phase: "build", model: HARD });
			}
			const provider = state.model === FRONTIER ? ZEN : GO;
			return routeTo(request, ctx, provider, state.model, state);
		},
	});
}
