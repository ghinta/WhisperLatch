--!strict
-- Reference solver for tests: reads the server-side secret and returns the
-- control actions that solve the current stage of a puzzle.

local Server = game:GetService("ServerScriptService").Server
local Controls = require(Server.logic.Controls)
local PuzzleTypes = require(Server.logic.PuzzleTypes)

export type Step = { actionType: string, controlId: string?, actionValue: number? }

local Solver = {}

local function controlWithGlyph(puzzle: PuzzleTypes.Puzzle, glyph: string): PuzzleTypes.Control
	for _, control in puzzle.controls do
		if control.glyph == glyph then
			return control
		end
	end
	error("no control with glyph " .. glyph)
end

local function setDials(puzzle: PuzzleTypes.Puzzle, targets: { string }): { Step }
	local steps = {}
	for i, control in puzzle.controls do
		local index = Controls.indexOf(control.options :: { string }, targets[i])
		table.insert(steps, { actionType = "setDial", controlId = control.id, actionValue = index })
	end
	return steps
end

-- Steps for the current stage, excluding the final submit.
function Solver.stageSteps(puzzle: PuzzleTypes.Puzzle): { Step }
	local secret = puzzle.secret
	local roomId = puzzle.roomId
	if roomId == "glyph_gate" or roomId == "pattern_relay" then
		return setDials(puzzle, secret.target)
	elseif roomId == "mirror_clocks" then
		local steps = {}
		for i, control in puzzle.controls do
			table.insert(steps, { actionType = "setDial", controlId = control.id, actionValue = secret.target[i] })
		end
		return steps
	elseif roomId == "circuit_split" then
		local steps = {}
		for _, control in puzzle.controls do
			if control.value ~= secret.target[control.glyph :: string] then
				table.insert(steps, { actionType = "toggle", controlId = control.id })
			end
		end
		return steps
	elseif roomId == "dual_reactor" then
		local sequence = secret.ignition
		if puzzle.state.stage == 2 then
			for _, entry in secret.cores do
				if entry.core == secret.active then
					sequence = entry.sequence
				end
			end
		end
		local steps = {}
		for _, glyph in sequence do
			table.insert(steps, { actionType = "press", controlId = controlWithGlyph(puzzle, glyph).id })
		end
		return steps
	end
	error("no solver for room " .. roomId)
end

return Solver
