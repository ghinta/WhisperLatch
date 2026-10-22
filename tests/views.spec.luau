--!strict
-- Role isolation of the view models (non-interference):
--   * the Tinkerer view must not change when only the secret changes
--   * the Seer view must not change when only the Tinkerer's state changes

return function(t: any)
	local Rng = require(t.Server.logic.Rng)
	local PuzzleEngine = require(t.Server.logic.PuzzleEngine)
	local Util = require(t.Server.logic.Util)
	local Rooms = require(t.Server.rooms)
	local RoleViewFactory = require(t.Server.services.RoleViewFactory)
	local Solver = require(t.Tests.helpers.Solver)

	local ctx = {
		sessionId = "S1",
		status = "active",
		slot = 1,
		roomIndex = 1,
		roomCount = 5,
		revision = 3,
		attempts = 0,
		hintsUsed = 1,
		partnerConnected = true,
		elapsed = 12,
	}

	for _, def in Rooms do
		t.test(def.id .. ": Seer gets the clue and no controls", function()
			local puzzle = PuzzleEngine.create(def, Rng.new(1))
			local view = RoleViewFactory.seerView(ctx, def, puzzle)
			t.ok(view.clue, "clue present")
			t.eq(view.controls, nil)
			t.eq(view.info, nil)
			t.eq(view.role, "Seer")
		end)

		t.test(def.id .. ": Tinkerer gets controls and no clue", function()
			local puzzle = PuzzleEngine.create(def, Rng.new(1))
			local view = RoleViewFactory.tinkererView(ctx, def, puzzle)
			t.eq(view.clue, nil)
			t.ok(view.controls and #view.controls > 0, "controls present")
			t.eq(view.role, "Tinkerer")
		end)

		t.test(def.id .. ": Tinkerer view is independent of the secret", function()
			for seed = 1, 100 do
				local a = PuzzleEngine.create(def, Rng.new(seed))
				local b = PuzzleEngine.create(def, Rng.new(seed + 1000))
				-- same public state, different secret
				b.controls = Util.deepCopy(a.controls)
				b.state = Util.deepCopy(a.state)
				b.layout = a.layout
				t.deepEq(
					RoleViewFactory.tinkererView(ctx, def, a),
					RoleViewFactory.tinkererView(ctx, def, b),
					"seed " .. seed
				)
			end
		end)

		t.test(def.id .. ": Seer view is independent of the Tinkerer's state", function()
			for seed = 1, 50 do
				local puzzle = PuzzleEngine.create(def, Rng.new(seed))
				local before = RoleViewFactory.seerView(ctx, def, puzzle)
				for _, step in Solver.stageSteps(puzzle) do
					PuzzleEngine.apply(def, puzzle, step.actionType, step.controlId, step.actionValue)
				end
				t.deepEq(RoleViewFactory.seerView(ctx, def, puzzle), before, "seed " .. seed)
			end
		end)

		t.test(def.id .. ": views are copies, not live references", function()
			local puzzle = PuzzleEngine.create(def, Rng.new(2))
			local view = RoleViewFactory.tinkererView(ctx, def, puzzle)
			local controls = view.controls :: { any }
			controls[1].value = 999
			t.neq(puzzle.controls[1].value, 999)
			local seerView = RoleViewFactory.seerView(ctx, def, puzzle)
			local clue = seerView.clue :: any
			clue.heading = "changed"
			t.neq(def.seerClue(puzzle).heading, "changed")
		end)
	end

	t.test("revealed hints follow the hint counter", function()
		local def = Rooms[1]
		local puzzle = PuzzleEngine.create(def, Rng.new(1))
		local view = RoleViewFactory.seerView(ctx, def, puzzle)
		t.eq(#view.hints, 1)
		t.eq(view.hints[1], def.hints[1])
		t.eq(view.hintCount, #def.hints)
	end)
end
