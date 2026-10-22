--!strict
-- Rng, PuzzleEngine and RateLimiter

return function(t: any)
	local Rng = require(t.Server.logic.Rng)
	local PuzzleEngine = require(t.Server.logic.PuzzleEngine)
	local RateLimiter = require(t.Server.logic.RateLimiter)
	local Rooms = require(t.Server.rooms)

	local GlyphGate, CircuitSplit, DualReactor = Rooms[1], Rooms[2], Rooms[5]

	t.test("Rng is deterministic per seed", function()
		local a, b = Rng.new(42), Rng.new(42)
		for _ = 1, 50 do
			t.eq(a:integer(1, 1000), b:integer(1, 1000))
		end
		t.neq(Rng.new(1):integer(1, 1e9), Rng.new(2):integer(1, 1e9), "different seeds")
	end)

	t.test("Rng.integer stays in range and hits both ends", function()
		local rng = Rng.new(5)
		local seen = {}
		for _ = 1, 500 do
			local value = rng:integer(3, 6)
			t.ok(value >= 3 and value <= 6, "out of range: " .. value)
			seen[value] = true
		end
		t.ok(seen[3] and seen[6], "range ends never produced")
	end)

	t.test("Rng.sample returns distinct entries", function()
		local rng = Rng.new(9)
		for _ = 1, 100 do
			local sample = rng:sample({ "a", "b", "c", "d", "e" }, 3)
			t.eq(#sample, 3)
			t.ok(sample[1] ~= sample[2] and sample[2] ~= sample[3] and sample[1] ~= sample[3], "duplicate in sample")
		end
	end)

	t.test("engine steps dials with wrap-around", function()
		local puzzle = PuzzleEngine.create(GlyphGate, Rng.new(3))
		local dial = puzzle.controls[1]
		local count = #(dial.options :: { string })
		local ok = PuzzleEngine.apply(GlyphGate, puzzle, "setDial", dial.id, count)
		t.ok(ok)
		t.ok(PuzzleEngine.apply(GlyphGate, puzzle, "stepDial", dial.id, 1))
		t.eq(dial.value, 1, "wraps forward")
		t.ok(PuzzleEngine.apply(GlyphGate, puzzle, "stepDial", dial.id, -1))
		t.eq(dial.value, count, "wraps backward")
	end)

	t.test("engine rejects malformed control actions without mutating", function()
		local puzzle = PuzzleEngine.create(GlyphGate, Rng.new(3))
		local before = puzzle.controls[1].value
		local cases = {
			{ "stepDial", "dial1", 2, "badValue" },
			{ "stepDial", "dial1", nil, "badValue" },
			{ "setDial", "dial1", 0, "badValue" },
			{ "setDial", "dial1", 99, "badValue" },
			{ "setDial", "dial1", 1.5, "badValue" },
			{ "toggle", "dial1", nil, "wrongControlKind" },
			{ "press", "dial1", nil, "wrongControlKind" },
			{ "setDial", "nope", 1, "unknownControl" },
			{ "setDial", nil, 1, "unknownControl" },
			{ "dance", "dial1", 1, "unknownAction" },
			{ "clearInput", nil, nil, "nothingToClear" },
		}
		for _, case in cases do
			local ok, err = PuzzleEngine.apply(GlyphGate, puzzle, case[1], case[2], case[3])
			t.notOk(ok, case[1])
			t.eq(err, case[4], case[1])
		end
		t.eq(puzzle.controls[1].value, before, "dial unchanged")
	end)

	t.test("toggles flip between 0 and 1", function()
		local puzzle = PuzzleEngine.create(CircuitSplit, Rng.new(4))
		local switch = puzzle.controls[1]
		t.eq(switch.value, 0)
		t.ok(PuzzleEngine.apply(CircuitSplit, puzzle, "toggle", switch.id))
		t.eq(switch.value, 1)
		t.ok(PuzzleEngine.apply(CircuitSplit, puzzle, "toggle", switch.id))
		t.eq(switch.value, 0)
	end)

	t.test("button input is capped and clearable", function()
		local puzzle = PuzzleEngine.create(DualReactor, Rng.new(4))
		local button = puzzle.controls[1]
		for _ = 1, DualReactor.inputMax do
			t.ok(PuzzleEngine.apply(DualReactor, puzzle, "press", button.id))
		end
		local ok, err = PuzzleEngine.apply(DualReactor, puzzle, "press", button.id)
		t.notOk(ok)
		t.eq(err, "inputFull")
		t.ok(PuzzleEngine.apply(DualReactor, puzzle, "clearInput"))
		t.eq(#puzzle.state.input, 0)
	end)

	t.test("rate limiter refills over time", function()
		local clock = 0
		local limiter = RateLimiter.new(function()
			return clock
		end, 2, 1)
		t.ok(limiter:allow(1))
		t.ok(limiter:allow(1))
		t.notOk(limiter:allow(1), "bucket empty")
		t.ok(limiter:allow(2), "buckets are per key")
		clock += 1
		t.ok(limiter:allow(1), "refilled")
	end)
end
