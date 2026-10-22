--!strict
-- Pure, generic puzzle engine: applies validated control actions to a puzzle
-- instance and delegates solution checks to the room definition.
-- No Roblox APIs, no yielding.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Protocol = require(ReplicatedStorage.Shared.Protocol)
local PuzzleTypes = require(script.Parent.PuzzleTypes)
local Rng = require(script.Parent.Rng)

type Puzzle = PuzzleTypes.Puzzle
type RoomDefinition = PuzzleTypes.RoomDefinition

local ActionType = Protocol.ActionType

local PuzzleEngine = {}

function PuzzleEngine.create(def: RoomDefinition, rng: Rng.Rng): Puzzle
	local puzzle = def.create(rng)
	assert(puzzle.roomId == def.id, "PuzzleEngine.create: room id mismatch")
	return puzzle
end

function PuzzleEngine.findControl(puzzle: Puzzle, controlId: string?): PuzzleTypes.Control?
	if controlId == nil then
		return nil
	end
	for _, control in puzzle.controls do
		if control.id == controlId then
			return control
		end
	end
	return nil
end

-- Applies one control action. Returns false plus a reason when the action is
-- not valid for this puzzle; the puzzle is left untouched in that case.
function PuzzleEngine.apply(
	def: RoomDefinition,
	puzzle: Puzzle,
	actionType: string,
	controlId: string?,
	value: number?
): (boolean, string?)
	if actionType == ActionType.ClearInput then
		if #puzzle.state.input == 0 then
			return false, "nothingToClear"
		end
		table.clear(puzzle.state.input)
		return true, nil
	end

	local control = PuzzleEngine.findControl(puzzle, controlId)
	if not control then
		return false, "unknownControl"
	end

	if actionType == ActionType.StepDial or actionType == ActionType.SetDial then
		local options = control.options
		if control.kind ~= "dial" or not options then
			return false, "wrongControlKind"
		end
		if actionType == ActionType.StepDial then
			if value ~= 1 and value ~= -1 then
				return false, "badValue"
			end
			local step = value :: number
			control.value = (control.value - 1 + step) % #options + 1
		else
			if value == nil or value % 1 ~= 0 or value < 1 or value > #options then
				return false, "badValue"
			end
			control.value = value
		end
		return true, nil
	elseif actionType == ActionType.Toggle then
		if control.kind ~= "toggle" then
			return false, "wrongControlKind"
		end
		control.value = 1 - control.value
		return true, nil
	elseif actionType == ActionType.Press then
		if control.kind ~= "button" then
			return false, "wrongControlKind"
		end
		if #puzzle.state.input >= def.inputMax then
			return false, "inputFull"
		end
		table.insert(puzzle.state.input, control.glyph or control.id)
		return true, nil
	end

	return false, "unknownAction"
end

function PuzzleEngine.submit(def: RoomDefinition, puzzle: Puzzle): PuzzleTypes.EvalResult
	return def.evaluate(puzzle)
end

return PuzzleEngine
