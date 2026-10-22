--!strict
-- Builds role-specific view models. This is the only place where server
-- state is projected for a client:
--   Seer     -> clue (derived from the secret), no controls, no Tinkerer info
--   Tinkerer -> controls + public puzzle state, never the clue or the secret

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)
local PuzzleTypes = require(script.Parent.Parent.logic.PuzzleTypes)
local Util = require(script.Parent.Parent.logic.Util)

export type ViewContext = {
	sessionId: string,
	status: Types.SessionStatus,
	slot: number,
	roomIndex: number,
	roomCount: number,
	revision: number,
	attempts: number,
	hintsUsed: number,
	partnerConnected: boolean,
	elapsed: number,
}

local RoleViewFactory = {}

local function revealedHints(def: PuzzleTypes.RoomDefinition, hintsUsed: number): { string }
	return table.move(def.hints, 1, math.min(hintsUsed, #def.hints), 1, {})
end

local function baseView(ctx: ViewContext, def: PuzzleTypes.RoomDefinition, role: Types.Role): Types.SessionView
	return {
		sessionId = ctx.sessionId,
		role = role,
		status = ctx.status,
		slot = ctx.slot,
		roomIndex = ctx.roomIndex,
		roomCount = ctx.roomCount,
		roomId = def.id,
		roomTitle = def.title,
		task = if role == "Seer" then def.seerTask else def.tinkererTask,
		revision = ctx.revision,
		attempts = ctx.attempts,
		hints = revealedHints(def, ctx.hintsUsed),
		hintCount = #def.hints,
		partnerConnected = ctx.partnerConnected,
		elapsed = ctx.elapsed,
	}
end

function RoleViewFactory.seerView(
	ctx: ViewContext,
	def: PuzzleTypes.RoomDefinition,
	puzzle: PuzzleTypes.Puzzle
): Types.SessionView
	local view = baseView(ctx, def, "Seer")
	view.clue = Util.deepCopy(def.seerClue(puzzle))
	return view
end

function RoleViewFactory.tinkererView(
	ctx: ViewContext,
	def: PuzzleTypes.RoomDefinition,
	puzzle: PuzzleTypes.Puzzle
): Types.SessionView
	local view = baseView(ctx, def, "Tinkerer")
	local state = puzzle.state
	view.layout = puzzle.layout
	view.submitLabel = def.submitLabel
	view.controls = Util.deepCopy(puzzle.controls)
	view.info = {
		reference = if state.reference then table.clone(state.reference) else nil,
		stage = state.stage,
		stageCount = state.stageCount,
		input = table.clone(state.input),
		inputMax = def.inputMax,
		core = state.core,
	}
	return view
end

function RoleViewFactory.build(
	role: Types.Role,
	ctx: ViewContext,
	def: PuzzleTypes.RoomDefinition,
	puzzle: PuzzleTypes.Puzzle
): Types.SessionView
	if role == "Seer" then
		return RoleViewFactory.seerView(ctx, def, puzzle)
	end
	return RoleViewFactory.tinkererView(ctx, def, puzzle)
end

return RoleViewFactory
