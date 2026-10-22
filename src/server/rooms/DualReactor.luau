--!strict
-- Room 5 - Dual Reactor
-- Two-stage state machine. Stage 1: the Seer knows the ignition sequence.
-- After the gate lever, the reactor shows a core symbol that only the
-- Tinkerer sees; the Seer's table maps that core to the stage-2 sequence.
-- The gate is a lever, not a timer: no time pressure (MVP rule).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Glyphs = require(ReplicatedStorage.Shared.Glyphs)
local Types = require(ReplicatedStorage.Shared.Types)
local Controls = require(script.Parent.Parent.logic.Controls)
local PuzzleTypes = require(script.Parent.Parent.logic.PuzzleTypes)
local Rng = require(script.Parent.Parent.logic.Rng)
local Util = require(script.Parent.Parent.logic.Util)

local BUTTON_COUNT = 4
local SEQUENCE_LENGTH = 3
local CORE_COUNT = 3

type CoreEntry = { core: string, sequence: { string } }
type Secret = { ignition: { string }, cores: { CoreEntry }, active: string }

local function randomSequence(rng: Rng.Rng, buttons: { string }): { string }
	local sequence: { string } = {}
	repeat
		sequence = {}
		for i = 1, SEQUENCE_LENGTH do
			sequence[i] = rng:pick(buttons)
		end
	until not (sequence[1] == sequence[2] and sequence[2] == sequence[3])
	return sequence
end

local function sequenceFor(secret: Secret, core: string): { string }
	for _, entry in secret.cores do
		if entry.core == core then
			return entry.sequence
		end
	end
	error("DualReactor: unknown core " .. core)
end

local DualReactor: PuzzleTypes.RoomDefinition = {
	id = "dual_reactor",
	title = "Doppelreaktor",
	seerTask = "Du hast das Reaktorprotokoll. Für Stufe 2 musst du wissen, welchen Kern dein Partner sieht.",
	tinkererTask = "Drücke die Tasten in der richtigen Folge und lege dann die Schleuse um. Nur du siehst den Kern.",
	submitLabel = "Schleuse umlegen",
	inputMax = SEQUENCE_LENGTH,
	hints = {
		"Stufe 1: Der Seher nennt die Zündfolge, dann Schleuse umlegen.",
		"Nach Stufe 1 zeigt der Reaktor dem Tüftler einen Kern. Sag dem Seher, welches Symbol er hat.",
		"Falsche Eingabe? Mit „Leeren“ fangt ihr die Stufe neu an.",
	},
	create = function(rng)
		local buttons = rng:sample(Glyphs.ids, BUTTON_COUNT)
		local ignition = randomSequence(rng, buttons)
		local cores: { CoreEntry } = {}
		for _, core in rng:sample(Glyphs.ids, CORE_COUNT) do
			local sequence: { string } = {}
			local unique = false
			repeat
				sequence = randomSequence(rng, buttons)
				unique = true
				for _, other in cores do
					if Util.listEqual(other.sequence, sequence) then
						unique = false
					end
				end
			until unique
			table.insert(cores, { core = core, sequence = sequence })
		end

		local controls = {}
		for i, glyph in buttons do
			table.insert(controls, Controls.button("btn" .. i, Glyphs.byId[glyph].name, glyph))
		end

		local secret: Secret = {
			ignition = ignition,
			cores = cores,
			active = rng:pick(cores).core,
		}
		return {
			roomId = "dual_reactor",
			layout = "reactor",
			controls = controls,
			state = Controls.newState(2),
			secret = secret,
		}
	end,
	seerClue = function(puzzle)
		local secret: Secret = puzzle.secret
		local ignitionLine: { Types.ClueToken } = { { text = "Zündfolge:" } }
		for _, glyph in secret.ignition do
			table.insert(ignitionLine, { glyph = glyph })
		end
		local lines: { { Types.ClueToken } } = {
			{ { text = "Stufe 1 – danach die Schleuse umlegen." } },
			ignitionLine,
			{ { text = "Stufe 2 – Stabilisierung je nach Kern:" } },
		}
		for _, entry in secret.cores do
			local line: { Types.ClueToken } = { { text = "Kern" }, { glyph = entry.core }, { text = "→" } }
			for _, glyph in entry.sequence do
				table.insert(line, { glyph = glyph })
			end
			table.insert(lines, line)
		end
		return {
			heading = "Reaktorprotokoll",
			lines = lines,
		}
	end,
	evaluate = function(puzzle)
		local secret: Secret = puzzle.secret
		local state = puzzle.state
		local expected = if state.stage == 1 then secret.ignition else sequenceFor(secret, secret.active)
		local correct = Util.listEqual(state.input, expected)
		table.clear(state.input)
		if not correct then
			return "wrong"
		end
		if state.stage < state.stageCount then
			state.stage += 1
			-- reveal the core to the Tinkerer only (public puzzle state)
			state.core = secret.active
			return "stage"
		end
		return "solved"
	end,
}

return DualReactor
