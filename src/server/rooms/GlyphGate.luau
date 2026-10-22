--!strict
-- Room 1 - Glyph Gate
-- Seer sees an ordered 3-glyph sequence. Tinkerer turns 3 glyph dials.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Glyphs = require(ReplicatedStorage.Shared.Glyphs)
local Controls = require(script.Parent.Parent.logic.Controls)
local PuzzleTypes = require(script.Parent.Parent.logic.PuzzleTypes)

local DIAL_COUNT = 3

type Secret = { target: { string } }

local GlyphGate: PuzzleTypes.RoomDefinition = {
	id = "glyph_gate",
	title = "Glyphentor",
	seerTask = "Du siehst die geheime Reihenfolge. Beschreibe sie deinem Partner – öffnen kann nur er.",
	tinkererTask = "Stelle die drei Drehscheiben so ein, wie dein Partner es beschreibt.",
	submitLabel = "Lösung prüfen",
	inputMax = 0,
	hints = {
		"Nennt die Symbole beim Namen (Mond, Stern …) – die Farbe hilft zusätzlich.",
		"Die Reihenfolge zählt: Scheibe 1 ist ganz links.",
		"Der Seher kann jedes Symbol als Ping schicken: Ping-Rad → Symbole.",
	},
	create = function(rng)
		local target = rng:sample(Glyphs.ids, DIAL_COUNT)
		-- start positions are independent of the target (no hint for the
		-- Tinkerer); only an already solved start is re-rolled
		local count = #Glyphs.ids
		local start: { number } = {}
		repeat
			local solved = true
			for i = 1, DIAL_COUNT do
				start[i] = rng:integer(1, count)
				solved = solved and Glyphs.ids[start[i]] == target[i]
			end
		until not solved
		local controls = {}
		for i = 1, DIAL_COUNT do
			table.insert(controls, Controls.dial("dial" .. i, "Scheibe " .. i, "glyph", Glyphs.ids, start[i]))
		end
		local secret: Secret = { target = target }
		return {
			roomId = "glyph_gate",
			layout = "row",
			controls = controls,
			state = Controls.newState(),
			secret = secret,
		}
	end,
	seerClue = function(puzzle)
		local secret: Secret = puzzle.secret
		return {
			heading = "Geheime Reihenfolge",
			sequence = table.clone(secret.target),
			lines = {
				{ { text = "Von links nach rechts: Scheibe 1, 2, 3." } },
			},
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

return GlyphGate
