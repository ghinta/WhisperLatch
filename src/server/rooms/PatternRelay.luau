--!strict
-- Room 4 - Pattern Relay
-- Tinkerer has a 3x3 tile grid that starts as a reference pattern (only the
-- Tinkerer sees it). Seer knows the transformation rule. Only together can
-- they build the resulting pattern.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)
local Controls = require(script.Parent.Parent.logic.Controls)
local PuzzleTypes = require(script.Parent.Parent.logic.PuzzleTypes)
local Util = require(script.Parent.Parent.logic.Util)

local N = 3
local TILE_OPTIONS = { "empty", "sun", "moon" }

export type Step = "rot_cw" | "rot_ccw" | "rot_180" | "flip_h" | "flip_v" | "swap"
type Secret = { steps: { Step }, target: { string } }

local GEOMETRY: { Step } = { "rot_cw", "rot_ccw", "rot_180", "flip_h", "flip_v" }

local STEP_TEXT: { [Step]: string } = {
	rot_cw = "Drehe das Muster eine Vierteldrehung im Uhrzeigersinn ↻",
	rot_ccw = "Drehe das Muster eine Vierteldrehung gegen den Uhrzeigersinn ↺",
	rot_180 = "Drehe das Muster einmal halb herum (auf den Kopf)",
	flip_h = "Spiegle das Muster: links wird rechts ↔",
	flip_v = "Spiegle das Muster: oben wird unten ↕",
	swap = "Tausche danach jede Sonne gegen einen Mond und umgekehrt ⇄",
}

local PatternRelay = {}

-- Applies one transformation step to a row-major N x N grid.
function PatternRelay.transform(grid: { string }, step: Step): { string }
	local out = table.create(N * N, "empty")
	for r = 0, N - 1 do
		for c = 0, N - 1 do
			local sr, sc = r, c
			if step == "rot_cw" then
				sr, sc = N - 1 - c, r
			elseif step == "rot_ccw" then
				sr, sc = c, N - 1 - r
			elseif step == "rot_180" then
				sr, sc = N - 1 - r, N - 1 - c
			elseif step == "flip_h" then
				sr, sc = r, N - 1 - c
			elseif step == "flip_v" then
				sr, sc = N - 1 - r, c
			end
			local value = grid[sr * N + sc + 1]
			if step == "swap" then
				value = if value == "sun" then "moon" elseif value == "moon" then "sun" else value
			end
			out[r * N + c + 1] = value
		end
	end
	return out
end

function PatternRelay.applySteps(grid: { string }, steps: { Step }): { string }
	local result = grid
	for _, step: Step in steps do
		result = PatternRelay.transform(result, step)
	end
	return result
end

local definition: PuzzleTypes.RoomDefinition = {
	id = "pattern_relay",
	title = "Musterfeld",
	seerTask = "Du kennst die Regel, aber nicht das Muster. Lass dir die Vorlage beschreiben.",
	tinkererTask = "Nur du siehst die Vorlage. Verändere das Feld nach der Regel deines Partners.",
	submitLabel = "Muster prüfen",
	inputMax = 0,
	hints = {
		"Der Tüftler beschreibt die Vorlage Feld für Feld (Zeile 1 bis 3, links nach rechts).",
		"Zeichnet das Muster gedanklich und wendet die Regel Schritt für Schritt an.",
		"Bei einer Vierteldrehung im Uhrzeigersinn wird die obere Zeile zur rechten Spalte.",
	},
	create = function(rng)
		local reference: { string } = {}
		local steps: { Step } = {}
		local target: { string } = {}
		for _ = 1, 64 do
			reference = table.create(N * N, "empty")
			local cells = rng:sample({ 1, 2, 3, 4, 5, 6, 7, 8, 9 }, 4)
			reference[cells[1]] = "sun"
			reference[cells[2]] = "sun"
			reference[cells[3]] = "moon"
			reference[cells[4]] = rng:pick({ "sun", "moon" })
			steps = { rng:pick(GEOMETRY) :: Step }
			if rng:integer(0, 1) == 1 then
				table.insert(steps, "swap")
			end
			target = PatternRelay.applySteps(reference, steps)
			if not Util.listEqual(target, reference) then
				break
			end
		end

		local controls = {}
		for i = 1, N * N do
			local value = Controls.indexOf(TILE_OPTIONS, reference[i])
			table.insert(controls, Controls.dial("tile" .. i, "Feld " .. i, "tile", TILE_OPTIONS, value))
		end
		local state = Controls.newState()
		state.reference = table.clone(reference)

		local secret: Secret = { steps = steps, target = target }
		return {
			roomId = "pattern_relay",
			layout = "grid3",
			controls = controls,
			state = state,
			secret = secret,
		}
	end,
	seerClue = function(puzzle)
		local secret: Secret = puzzle.secret
		local lines: { { Types.ClueToken } } = {
			{ { text = "Nimm die Vorlage des Tüftlers und verändere sie:" } },
		}
		for i, step: Step in secret.steps do
			if step == "swap" then
				local swapLine: { Types.ClueToken } = {
					{ text = i .. ". Tausche danach jede" },
					{ glyph = "sun" },
					{ text = "gegen" },
					{ glyph = "moon" },
					{ text = "und umgekehrt ⇄" },
				}
				table.insert(lines, swapLine)
			else
				table.insert(lines, { { text = i .. ". " .. STEP_TEXT[step] } })
			end
		end
		return {
			heading = "Musterregel",
			lines = lines,
		}
	end,
	evaluate = function(puzzle)
		local secret: Secret = puzzle.secret
		for i, control in puzzle.controls do
			if Controls.option(control) ~= secret.target[i] then
				return "wrong"
			end
		end
		return "solved"
	end,
}

PatternRelay.definition = definition
PatternRelay.TILE_OPTIONS = TILE_OPTIONS

return PatternRelay
