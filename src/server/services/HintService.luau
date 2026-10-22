--!strict
-- Finite, progressive hints per room. Hints are generic strategy text and
-- never contain parts of the solution, so both roles may receive them.

local PuzzleTypes = require(script.Parent.Parent.logic.PuzzleTypes)

local HINT_COOLDOWN = 5

export type HintState = {
	hintsUsed: number,
	totalHints: number,
	lastHintAt: number,
}

local HintService = {}

HintService.COOLDOWN = HINT_COOLDOWN

function HintService.request(state: HintState, def: PuzzleTypes.RoomDefinition, now: number): (boolean, string?)
	if state.hintsUsed >= #def.hints then
		return false, "noHintsLeft"
	end
	if now - state.lastHintAt < HINT_COOLDOWN then
		return false, "cooldown"
	end
	state.hintsUsed += 1
	state.totalHints += 1
	state.lastHintAt = now
	return true, nil
end

return HintService
