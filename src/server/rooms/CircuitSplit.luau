--!strict
-- Room 2 - Circuit Split
-- Seer sees a small rule diagram; Tinkerer flips 4 glyph-labelled switches.
-- The rules are one anchor plus a spanning tree of same/differs relations,
-- which pins down exactly one switch combination.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Glyphs = require(ReplicatedStorage.Shared.Glyphs)
local Types = require(ReplicatedStorage.Shared.Types)
local Controls = require(script.Parent.Parent.logic.Controls)
local PuzzleTypes = require(script.Parent.Parent.logic.PuzzleTypes)

local SWITCH_COUNT = 4

export type RuleKind = "on" | "off" | "same" | "differs"
export type Rule = { a: string, kind: RuleKind, b: string? }
type Secret = { target: { [string]: number }, rules: { Rule } }

local RULE_TEXT: { [RuleKind]: string } = {
	on = "ist AN",
	off = "ist AUS",
	same = "steht genauso wie",
	differs = "steht anders als",
}

local CircuitSplit: PuzzleTypes.RoomDefinition = {
	id = "circuit_split",
	title = "Schaltkreis",
	seerTask = "Du siehst den Schaltplan. Finde heraus, welche Schalter AN sein müssen, und sag es deinem Partner.",
	tinkererTask = "Lege die vier Schalter so um, wie dein Partner es beschreibt.",
	submitLabel = "Strom einschalten",
	inputMax = 0,
	hints = {
		"Beginnt mit der Regel, die einen Schalter direkt AN oder AUS setzt.",
		"„Genauso wie“ heißt: gleiche Stellung. „Anders als“ heißt: Gegenteil.",
		"Die Schalter erkennt ihr am Symbol, nicht an der Position.",
	},
	create = function(rng)
		local glyphs = rng:sample(Glyphs.ids, SWITCH_COUNT)
		local bits: { number } = {}
		repeat
			for i = 1, SWITCH_COUNT do
				bits[i] = rng:integer(0, 1)
			end
		until table.find(bits, 1) ~= nil -- all switches start AUS, so never all-off

		local order = rng:shuffle({ 1, 2, 3, 4 })
		local anchor = order[1]
		local anchorKind: RuleKind = if bits[anchor] == 1 then "on" else "off"
		local rules: { Rule } = { { a = glyphs[anchor], kind = anchorKind } }
		for k = 2, SWITCH_COUNT do
			local i = order[k]
			local j = order[rng:integer(1, k - 1)]
			local kind: RuleKind = if bits[i] == bits[j] then "same" else "differs"
			table.insert(rules, { a = glyphs[i], kind = kind, b = glyphs[j] })
		end

		local target: { [string]: number } = {}
		for i, glyph in glyphs do
			target[glyph] = bits[i]
		end

		local controls = {}
		for i, glyph in rng:shuffle(glyphs) do
			table.insert(controls, Controls.toggle("sw" .. i, Glyphs.byId[glyph].name, glyph))
		end

		local secret: Secret = { target = target, rules = rng:shuffle(rules) }
		return {
			roomId = "circuit_split",
			layout = "row",
			controls = controls,
			state = Controls.newState(),
			secret = secret,
		}
	end,
	seerClue = function(puzzle)
		local secret: Secret = puzzle.secret
		local lines: { { Types.ClueToken } } = {
			{ { text = "Strom fließt nur, wenn alle Regeln stimmen:" } },
		}
		for _, rule in secret.rules do
			local line: { Types.ClueToken } = { { glyph = rule.a }, { text = RULE_TEXT[rule.kind] } }
			if rule.b then
				table.insert(line, { glyph = rule.b })
			end
			table.insert(lines, line)
		end
		return {
			heading = "Schaltplan",
			lines = lines,
		}
	end,
	evaluate = function(puzzle)
		local secret: Secret = puzzle.secret
		for _, control in puzzle.controls do
			if control.value ~= secret.target[control.glyph :: string] then
				return "wrong"
			end
		end
		return "solved"
	end,
}

return CircuitSplit
