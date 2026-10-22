--!strict
-- Every room: generated puzzles start unsolved, have a confirmed solution
-- and reject wrong answers.

return function(t: any)
	local Rng = require(t.Server.logic.Rng)
	local PuzzleEngine = require(t.Server.logic.PuzzleEngine)
	local Util = require(t.Server.logic.Util)
	local Rooms = require(t.Server.rooms)
	local PatternRelay = require(t.Server.rooms.PatternRelay)
	local Glyphs = require(t.Shared.Glyphs)
	local Solver = require(t.Tests.helpers.Solver)

	local SEEDS = 300

	local function solve(def, puzzle): string
		local result = "wrong"
		for _ = 1, 4 do
			for _, step in Solver.stageSteps(puzzle) do
				local ok, err = PuzzleEngine.apply(def, puzzle, step.actionType, step.controlId, step.actionValue)
				assert(ok, err)
			end
			result = PuzzleEngine.submit(def, puzzle)
			if result ~= "stage" then
				return result
			end
		end
		return result
	end

	t.test("catalog has five distinct rooms", function()
		t.eq(#Rooms, 5)
		local ids = {}
		for _, def in Rooms do
			t.notOk(ids[def.id], "duplicate id " .. def.id)
			ids[def.id] = true
			t.ok(#def.hints > 0, def.id .. " has hints")
		end
	end)

	for _, def in Rooms do
		t.test(def.id .. ": fresh puzzle is not solved", function()
			for seed = 1, SEEDS do
				local puzzle = PuzzleEngine.create(def, Rng.new(seed))
				t.eq(PuzzleEngine.submit(def, puzzle), "wrong", "seed " .. seed)
			end
		end)

		t.test(def.id .. ": reference solution is accepted", function()
			for seed = 1, SEEDS do
				local puzzle = PuzzleEngine.create(def, Rng.new(seed))
				t.eq(solve(def, puzzle), "solved", "seed " .. seed)
			end
		end)

		t.test(def.id .. ": clue only uses known glyphs", function()
			for seed = 1, 50 do
				local clue = def.seerClue(PuzzleEngine.create(def, Rng.new(seed)))
				t.ok(clue.sequence or clue.clocks or clue.lines, "clue has content")
				for _, line in clue.lines or {} do
					for _, token in line do
						t.ok(token.text or (token.glyph and Glyphs.byId[token.glyph]), "bad token")
					end
				end
			end
		end)
	end

	t.test("glyph_gate: one wrong dial fails", function()
		local def = Rooms[1]
		for seed = 1, 50 do
			local puzzle = PuzzleEngine.create(def, Rng.new(seed))
			for _, step in Solver.stageSteps(puzzle) do
				PuzzleEngine.apply(def, puzzle, step.actionType, step.controlId, step.actionValue)
			end
			PuzzleEngine.apply(def, puzzle, "stepDial", "dial2", 1)
			t.eq(PuzzleEngine.submit(def, puzzle), "wrong")
		end
	end)

	t.test("circuit_split: rules allow exactly one switch combination", function()
		local def = Rooms[2]
		for seed = 1, SEEDS do
			local puzzle = PuzzleEngine.create(def, Rng.new(seed))
			local rules = puzzle.secret.rules
			local glyphs = {}
			for _, control in puzzle.controls do
				table.insert(glyphs, control.glyph)
			end
			local matches = 0
			for mask = 0, 15 do
				local state = {}
				for i, glyph in glyphs do
					state[glyph] = bit32.extract(mask, i - 1)
				end
				local function holds(rule): boolean
					local a = state[rule.a]
					if rule.kind == "on" then
						return a == 1
					elseif rule.kind == "off" then
						return a == 0
					elseif rule.kind == "same" then
						return a == state[rule.b]
					end
					return a ~= state[rule.b]
				end
				local valid = true
				for _, rule in rules do
					valid = valid and holds(rule)
				end
				if valid then
					matches += 1
					t.deepEq(state, puzzle.secret.target, "rule solution matches target")
				end
			end
			t.eq(matches, 1, "seed " .. seed)
		end
	end)

	t.test("mirror_clocks: Seer sees reversed, mirrored hours", function()
		local def = Rooms[3]
		for seed = 1, 100 do
			local puzzle = PuzzleEngine.create(def, Rng.new(seed))
			local target, shown = puzzle.secret.target, def.seerClue(puzzle).clocks
			for i = 1, 3 do
				local real = target[4 - i]
				t.eq((real + shown[i]) % 12, 0, "mirror pair sums to 12")
				t.ok(real ~= 6 and real ~= 12, "no mirror-symmetric targets")
			end
		end
	end)

	t.test("pattern_relay: transformations compose correctly", function()
		local grid = { "sun", "empty", "moon", "empty", "empty", "empty", "moon", "empty", "sun" }
		local function apply(steps)
			return PatternRelay.applySteps(grid, steps)
		end
		t.deepEq(apply({ "rot_cw", "rot_cw", "rot_cw", "rot_cw" }), grid, "4x cw")
		t.deepEq(apply({ "rot_cw", "rot_ccw" }), grid, "cw then ccw")
		t.deepEq(apply({ "rot_cw", "rot_cw" }), apply({ "rot_180" }), "2x cw = 180")
		t.deepEq(apply({ "flip_h", "flip_h" }), grid, "flip twice")
		t.deepEq(apply({ "swap", "swap" }), grid, "swap twice")
		-- top-left corner moves to top-right on a clockwise quarter turn
		local rotated = PatternRelay.transform(
			{ "sun", "empty", "empty", "empty", "empty", "empty", "empty", "empty", "empty" },
			"rot_cw"
		)
		t.eq(rotated[3], "sun")
	end)

	t.test("pattern_relay: target differs from the reference", function()
		local def = PatternRelay.definition
		for seed = 1, SEEDS do
			local puzzle = PuzzleEngine.create(def, Rng.new(seed))
			t.notOk(Util.listEqual(puzzle.secret.target, puzzle.state.reference), "seed " .. seed)
		end
	end)

	t.test("dual_reactor: core is revealed only after stage 1", function()
		local def = Rooms[5]
		local puzzle = PuzzleEngine.create(def, Rng.new(11))
		t.eq(puzzle.state.core, nil)
		for _, step in Solver.stageSteps(puzzle) do
			PuzzleEngine.apply(def, puzzle, step.actionType, step.controlId, step.actionValue)
		end
		t.eq(PuzzleEngine.submit(def, puzzle), "stage")
		t.eq(puzzle.state.stage, 2)
		t.eq(puzzle.state.core, puzzle.secret.active)
		-- a wrong stage-2 sequence keeps the stage and clears the input
		local wrong = puzzle.controls[1].id
		for _ = 1, 3 do
			PuzzleEngine.apply(def, puzzle, "press", wrong)
		end
		local expected = Solver.stageSteps(puzzle)
		local allFirst = true
		for _, step in expected do
			allFirst = allFirst and step.controlId == wrong
		end
		if not allFirst then
			t.eq(PuzzleEngine.submit(def, puzzle), "wrong")
			t.eq(puzzle.state.stage, 2)
			t.eq(#puzzle.state.input, 0)
		end
	end)
end
