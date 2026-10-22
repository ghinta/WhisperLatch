--!strict
-- Types for server-only puzzle instances and room definitions.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)
local Rng = require(script.Parent.Rng)

export type Control = Types.ControlView

-- Public puzzle state the Tinkerer may see (never the solution).
export type PuzzleState = {
	input: { string },
	stage: number,
	stageCount: number,
	reference: { string }?,
	core: string?,
}

export type Puzzle = {
	roomId: string,
	layout: string,
	controls: { Control },
	state: PuzzleState,
	-- Server-only solution data. Only `RoomDefinition.seerClue` may read it
	-- for a view, and that output only ever goes to the Seer.
	secret: any,
}

export type EvalResult = "solved" | "stage" | "wrong"

export type RoomDefinition = {
	id: string,
	title: string,
	seerTask: string,
	tinkererTask: string,
	submitLabel: string,
	hints: { string },
	inputMax: number,
	create: (rng: Rng.Rng) -> Puzzle,
	seerClue: (puzzle: Puzzle) -> Types.SeerClue,
	evaluate: (puzzle: Puzzle) -> EvalResult,
}

return {}
