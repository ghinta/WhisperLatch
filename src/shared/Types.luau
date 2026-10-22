--!strict
-- Network contract shared by server and client.
-- Views are least-privilege projections: a Tinkerer view never carries `clue`,
-- a Seer view never carries `controls` or `info`.

export type Role = "Seer" | "Tinkerer"
export type SessionStatus = "waiting" | "active" | "solved" | "paused" | "ended"
export type ControlKind = "dial" | "toggle" | "button"
export type ControlDisplay = "glyph" | "clock" | "tile" | "switch" | "button"

export type ControlView = {
	id: string,
	kind: ControlKind,
	display: ControlDisplay,
	label: string,
	glyph: string?,
	options: { string }?,
	value: number,
}

-- One token of a clue line: either plain text or a glyph chip.
export type ClueToken = {
	text: string?,
	glyph: string?,
}

export type SeerClue = {
	heading: string,
	sequence: { string }?,
	clocks: { number }?,
	lines: { { ClueToken } }?,
}

export type TinkererInfo = {
	reference: { string }?,
	stage: number,
	stageCount: number,
	input: { string },
	inputMax: number,
	core: string?,
}

export type SessionView = {
	sessionId: string,
	role: Role,
	status: SessionStatus,
	slot: number,
	roomIndex: number,
	roomCount: number,
	roomId: string,
	roomTitle: string,
	task: string,
	revision: number,
	attempts: number,
	hints: { string },
	hintCount: number,
	partnerConnected: boolean,
	elapsed: number,
	-- Seer only
	clue: SeerClue?,
	-- Tinkerer only
	layout: string?,
	controls: { ControlView }?,
	info: TinkererInfo?,
	submitLabel: string?,
}

export type EndReason = "finished" | "abandoned" | "timeout"

export type RunSummary = {
	reason: EndReason,
	roomsCleared: number,
	roomCount: number,
	seconds: number,
	hintsUsed: number,
}

export type LobbyStateName = "idle" | "queued" | "inSession"

export type LobbyState = {
	state: LobbyStateName,
	lastRun: RunSummary?,
}

export type NoticeKind =
	"wrong"
	| "stage"
	| "solved"
	| "advanced"
	| "reset"
	| "hint"
	| "partnerLeft"
	| "partnerBack"
	| "ended"
	| "rejected"

export type Notice = {
	kind: NoticeKind,
	reason: string?,
	summary: RunSummary?,
}

export type PingMessage = {
	from: "self" | "partner",
	pingId: string,
}

-- Client -> server requests
export type ActionRequest = {
	sessionId: string,
	roomId: string,
	actionType: string,
	controlId: string?,
	actionValue: number?,
	expectedRevision: number,
}

export type PingRequest = {
	sessionId: string,
	pingId: string,
}

export type HintRequest = {
	sessionId: string,
	roomId: string,
}

export type LobbyRequest = {
	action: string,
}

return {}
