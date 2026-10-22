--!strict
-- Untrusted payload validation and progress persistence.

return function(t: any)
	local ActionGateway = require(t.Server.services.ActionGateway)
	local ProgressService = require(t.Server.services.ProgressService)

	local valid = {
		sessionId = "S1",
		roomId = "glyph_gate",
		actionType = "stepDial",
		controlId = "dial1",
		actionValue = 1,
		expectedRevision = 4,
	}

	local function with(field: string, value: any)
		local copy = table.clone(valid)
		copy[field] = value
		return copy
	end

	t.test("accepts a well-formed action", function()
		local request, err = ActionGateway.parseAction(valid)
		t.eq(err, nil)
		t.deepEq(request, valid)
		t.ok(ActionGateway.parseAction(with("controlId", nil)), "controlId is optional")
		t.ok(ActionGateway.parseAction(with("actionValue", nil)), "actionValue is optional")
	end)

	t.test("rejects malformed actions", function()
		local bad = {
			"not a table",
			42,
			with("sessionId", nil),
			with("sessionId", 5),
			with("sessionId", string.rep("x", 200)),
			with("roomId", "../rooms"),
			with("actionType", "teleport"),
			with("actionType", { "stepDial" }),
			with("controlId", "dial 1"),
			with("actionValue", 0 / 0),
			with("actionValue", math.huge),
			with("actionValue", 1.5),
			with("actionValue", 1000),
			with("actionValue", "1"),
			with("expectedRevision", -1),
			with("expectedRevision", 2.5),
			with("expectedRevision", nil),
		}
		for index, raw in bad do
			local request, err = ActionGateway.parseAction(raw)
			t.eq(request, nil, "case " .. index)
			t.eq(err, "malformed", "case " .. index)
		end
	end)

	t.test("validates ping, hint and lobby requests", function()
		t.ok(ActionGateway.parsePing({ sessionId = "S1", pingId = "g_moon" }))
		t.eq((ActionGateway.parsePing({ sessionId = "S1", pingId = "hello world" })), nil)
		t.eq((ActionGateway.parsePing({ sessionId = "S1" })), nil)
		t.ok(ActionGateway.parseHint({ sessionId = "S1", roomId = "glyph_gate" }))
		t.eq((ActionGateway.parseHint("S1")), nil)
		t.ok(ActionGateway.parseLobby({ action = "queue" }))
		t.eq((ActionGateway.parseLobby({ action = "admin" })), nil)
	end)

	t.test("progress merge sanitizes stored data", function()
		local summary = { reason = "finished", roomsCleared = 5, roomCount = 5, seconds = 300.7, hintsUsed = 2 }
		local fresh = ProgressService.merge(nil, summary)
		t.deepEq(fresh, { runs = 1, finishedRuns = 1, roomsCleared = 5, hintsUsed = 2, bestSeconds = 300 })
		local corrupt = { runs = "lots", roomsCleared = -3, hintsUsed = 0 / 0, bestSeconds = 0 / 0 }
		t.deepEq(
			ProgressService.merge(corrupt, summary),
			{ runs = 1, finishedRuns = 1, roomsCleared = 5, hintsUsed = 2, bestSeconds = 300 }
		)
		local slower = { reason = "finished", roomsCleared = 5, roomCount = 5, seconds = 999, hintsUsed = 0 }
		t.eq(ProgressService.merge(fresh, slower).bestSeconds, 300, "keeps best time")
		local abandoned = { reason = "abandoned", roomsCleared = 2, roomCount = 5, seconds = 50, hintsUsed = 0 }
		local merged = ProgressService.merge(fresh, abandoned)
		t.eq(merged.finishedRuns, 1)
		t.eq(merged.roomsCleared, 7)
	end)

	t.test("progress is written once per player through the store", function()
		local writes = {}
		local store = {
			update = function(key, transform)
				writes[key] = transform(writes[key])
			end,
		}
		local progress = ProgressService.new(store)
		progress:recordRun(
			{ 1, 2 },
			{ reason = "finished", roomsCleared = 5, roomCount = 5, seconds = 100, hintsUsed = 0 }
		)
		t.eq(writes.user_1.runs, 1)
		t.eq(writes.user_2.runs, 1)
		progress:recordRun({ 1 }, { reason = "abandoned", roomsCleared = 0, roomCount = 5, seconds = 5, hintsUsed = 0 })
		t.eq(writes.user_1.runs, 1, "empty runs are not recorded")
	end)
end
