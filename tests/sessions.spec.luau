--!strict
-- SessionManager: pairing, authorization, role swap, secrecy over the whole
-- message stream, disconnect handling.

return function(t: any)
	local Harness = require(t.Tests.helpers.Harness)
	local PairingService = require(t.Server.services.PairingService)

	local A, B, C = 101, 202, 303

	local function started()
		local h = Harness.new()
		local session = h.manager:start(A, B)
		assert(session, "session did not start")
		return h, session
	end

	-- Asserts that no payload ever sent to `userId` while being Tinkerer
	-- carried a clue.
	local function assertNoClueFor(h, userId: number, fromIndex: number?)
		for index = fromIndex or 1, #h.messages do
			local message = h.messages[index]
			if message.userId == userId and message.channel == "view" and message.payload.role == "Tinkerer" then
				t.eq(message.payload.clue, nil, "clue leaked to Tinkerer")
			end
			if message.userId == userId and message.channel ~= "view" then
				t.eq(type(message.payload) == "table" and message.payload.clue, nil, "clue in " .. message.channel)
			end
		end
	end

	t.test("two players get different roles and their own views", function()
		local h, session = started()
		t.eq(session.status, "active")
		local seer, tinkerer = h:seerAndTinkerer(A)
		t.neq(seer, tinkerer)
		t.ok(h:lastView(seer).clue, "Seer view has clue")
		t.eq(h:lastView(seer).controls, nil)
		t.ok(h:lastView(tinkerer).controls, "Tinkerer view has controls")
		t.eq(h:lastView(tinkerer).clue, nil)
	end)

	t.test("a third user cannot join an existing session", function()
		local h, session = started()
		t.eq(h.manager:start(A, C), nil, "A is taken")
		t.eq(h.manager:start(C, B), nil, "B is taken")
		t.eq(h.manager:sessionOf(C), nil)
		t.eq(#session.playerIds, 2)
		local ok, err = h.manager:handleAction(C, {
			sessionId = session.id,
			roomId = session.puzzle.roomId,
			actionType = "submit",
			expectedRevision = session.revision,
		})
		t.notOk(ok)
		t.eq(err, "notInSession")
	end)

	t.test("pairing queue is FIFO and idempotent", function()
		local pairing = PairingService.new()
		t.ok(pairing:enqueue(A))
		t.notOk(pairing:enqueue(A), "double enqueue")
		t.ok(pairing:enqueue(B))
		t.ok(pairing:enqueue(C))
		t.ok(pairing:cancel(C))
		local first, second = pairing:popPair()
		t.eq(first, A)
		t.eq(second, B)
		t.eq(pairing:size(), 0)
		t.eq((pairing:popPair()), nil)
	end)

	t.test("sessions are limited by chamber slots", function()
		local h = Harness.new({ slotCount = 1 })
		t.ok(h.manager:start(A, B))
		t.eq(h.manager:start(C, 404), nil)
		t.notOk(h.manager:hasCapacity())
		h.manager:leave(A)
		t.ok(h.manager:hasCapacity(), "slot freed")
	end)

	t.test("Seer cannot manipulate controls (spoofed role)", function()
		local h, session = started()
		local seer = h:seerAndTinkerer(A)
		local revision = session.revision
		local ok, err = h:act(seer, "stepDial", "dial1", 1)
		t.notOk(ok)
		t.eq(err, "wrongRole")
		ok, err = h:act(seer, "submit")
		t.notOk(ok)
		t.eq(err, "wrongRole")
		t.eq(session.revision, revision, "no state change")
	end)

	t.test("stale revision, wrong room and wrong session are rejected", function()
		local h, session = started()
		local _, tinkerer = h:seerAndTinkerer(A)
		local base = {
			sessionId = session.id,
			roomId = session.puzzle.roomId,
			actionType = "stepDial",
			controlId = "dial1",
			actionValue = 1,
			expectedRevision = session.revision,
		}
		t.ok(h.manager:handleAction(tinkerer, table.clone(base)))
		-- replaying the same request (duplicate / stale) must not apply twice
		local ok, err = h.manager:handleAction(tinkerer, table.clone(base))
		t.notOk(ok)
		t.eq(err, "staleRevision")

		local wrongRoom = table.clone(base)
		wrongRoom.roomId = "dual_reactor"
		wrongRoom.expectedRevision = session.revision
		ok, err = h.manager:handleAction(tinkerer, wrongRoom)
		t.eq(err, "wrongRoom")

		local wrongSession = table.clone(base)
		wrongSession.sessionId = "S999"
		ok, err = h.manager:handleAction(tinkerer, wrongSession)
		t.eq(err, "notInSession")
	end)

	t.test("wrong answers are rejected and rapid submits are throttled", function()
		local h, session = started()
		local _, tinkerer = h:seerAndTinkerer(A)
		t.ok(h:act(tinkerer, "submit"))
		t.eq(session.status, "active")
		local notices = h:messagesFor(tinkerer, "notice")
		t.eq(notices[#notices].kind, "wrong")
		local ok, err = h:act(tinkerer, "submit")
		t.notOk(ok)
		t.eq(err, "cooldown")
		t.eq(session.attempts, 1)
	end)

	t.test("roles swap exactly once per room", function()
		local h, session = started()
		local seer, tinkerer = h:seerAndTinkerer(A)
		h:solveRoom(A)
		t.eq(session.status, "solved")
		-- actions while solved are rejected (no double solve)
		local ok, err = h:act(tinkerer, "submit")
		t.notOk(ok)
		t.eq(err, "notActive")

		h.manager:tick()
		t.eq(session.roomIndex, 1, "no advance before delay")
		h:advanceTime(10)
		h.manager:tick()
		h.manager:tick()
		t.eq(session.roomIndex, 2)
		t.eq(session.roleByUserId[seer], "Tinkerer")
		t.eq(session.roleByUserId[tinkerer], "Seer")
		h:advanceTime(10)
		h.manager:tick()
		t.eq(session.roomIndex, 2, "still room 2")
		t.eq(session.roleByUserId[seer], "Tinkerer", "no second swap")
	end)

	t.test("full run: all five rooms, clue never reaches a Tinkerer", function()
		local h, session = started()
		for room = 1, 5 do
			t.eq(session.roomIndex, room)
			local seer, tinkerer = h:seerAndTinkerer(A)
			local mark = #h.messages + 1
			t.ok(h.manager:handleHint(seer, { sessionId = session.id, roomId = session.puzzle.roomId }))
			h:solveRoom(A)
			h:advanceTime(10)
			h.manager:tick()
			assertNoClueFor(h, tinkerer, mark)
			if room < 5 then
				-- the new Tinkerer is the previous Seer: nothing about the new room's
				-- clue may have been sent to them
				local _, nextTinkerer = h:seerAndTinkerer(A)
				t.eq(nextTinkerer, seer)
				t.eq(h:lastView(nextTinkerer).clue, nil)
			end
		end
		t.eq(h.manager:sessionOf(A), nil, "membership released")
		t.eq(h.manager:sessionOf(B), nil, "membership released")
		t.eq(h.events[#h.events], "ended:finished")
		local notices = h:messagesFor(A, "notice")
		local summary = notices[#notices].summary
		t.eq(summary.roomsCleared, 5)
		t.eq(summary.hintsUsed, 5)
		t.ok(h.manager:hasCapacity())
	end)

	t.test("hints are progressive, finite and shared with both roles", function()
		local h, session = started()
		local seer, tinkerer = h:seerAndTinkerer(A)
		local request = { sessionId = session.id, roomId = session.puzzle.roomId }
		t.ok(h.manager:handleHint(seer, request))
		local ok, err = h.manager:handleHint(tinkerer, request)
		t.notOk(ok)
		t.eq(err, "cooldown")
		h:advanceTime(10)
		t.ok(h.manager:handleHint(tinkerer, request))
		h:advanceTime(10)
		t.ok(h.manager:handleHint(seer, request))
		h:advanceTime(10)
		ok, err = h.manager:handleHint(seer, request)
		t.eq(err, "noHintsLeft")
		t.eq(#h:lastView(seer).hints, 3)
		t.eq(#h:lastView(tinkerer).hints, 3)
	end)

	t.test("pings reach both players, unknown pings are rejected", function()
		local h, session = started()
		local seer, tinkerer = h:seerAndTinkerer(A)
		t.ok(h.manager:handlePing(seer, { sessionId = session.id, pingId = "g_moon" }))
		local toSeer = h:messagesFor(seer, "ping")
		local toTinkerer = h:messagesFor(tinkerer, "ping")
		t.deepEq(toSeer[#toSeer], { from = "self", pingId = "g_moon" })
		t.deepEq(toTinkerer[#toTinkerer], { from = "partner", pingId = "g_moon" })
		local ok, err = h.manager:handlePing(seer, { sessionId = session.id, pingId = "free_text" })
		t.notOk(ok)
		t.eq(err, "unknownPing")
		ok, err = h.manager:handlePing(C, { sessionId = session.id, pingId = "yes" })
		t.eq(err, "notInSession")
	end)

	t.test("reset gives a new puzzle and both players fresh views", function()
		local h, session = started()
		local seer, tinkerer = h:seerAndTinkerer(A)
		local old = session.puzzle
		t.ok(h:act(seer, "reset"))
		t.neq(session.puzzle, old)
		t.eq(h:lastView(seer).revision, session.revision)
		t.eq(h:lastView(tinkerer).revision, session.revision)
		local ok, err = h:act(tinkerer, "reset")
		t.notOk(ok)
		t.eq(err, "cooldown")
	end)

	t.test("disconnect pauses, reconnect resumes without leaking the clue", function()
		local h, session = started()
		local seer, tinkerer = h:seerAndTinkerer(A)
		h.manager:disconnect(seer)
		t.eq(session.status, "paused")
		local ok, err = h:act(tinkerer, "stepDial", "dial1", 1)
		t.notOk(ok)
		t.eq(err, "notActive")
		local notices = h:messagesFor(tinkerer, "notice")
		t.eq(notices[#notices].kind, "partnerLeft")

		local mark = #h.messages + 1
		h.manager:disconnect(tinkerer)
		t.eq(h.manager:sessionOf(seer), nil, "nobody left: session ended")
		t.eq(h.events[#h.events], "ended:abandoned")

		-- new session: Tinkerer drops and rejoins
		local h2, session2 = started()
		local seer2, tinkerer2 = h2:seerAndTinkerer(A)
		h2.manager:disconnect(tinkerer2)
		mark = #h2.messages + 1
		t.ok(h2.manager:reconnect(tinkerer2))
		t.eq(session2.status, "active")
		t.eq(h2:lastView(tinkerer2).role, "Tinkerer")
		assertNoClueFor(h2, tinkerer2, mark)
		t.ok(h2:lastView(seer2).clue, "Seer still has the clue")
	end)

	t.test("paused sessions time out and late events are ignored", function()
		local h, session = started()
		local seer, tinkerer = h:seerAndTinkerer(A)
		h.manager:disconnect(seer)
		h:advanceTime(200)
		h.manager:tick()
		t.eq(session.status, "ended")
		t.eq(h.events[#h.events], "ended:timeout")
		t.eq(h.manager:sessionOf(tinkerer), nil)
		local ok, err = h.manager:handleAction(tinkerer, {
			sessionId = session.id,
			roomId = session.puzzle.roomId,
			actionType = "submit",
			expectedRevision = session.revision,
		})
		t.notOk(ok)
		t.eq(err, "notInSession")
		t.notOk(h.manager:reconnect(seer), "cannot rejoin an ended session")
	end)

	t.test("a solved room still advances after a pause", function()
		local h, session = started()
		local seer = h:seerAndTinkerer(A)
		h:solveRoom(A)
		h.manager:disconnect(seer)
		h:advanceTime(10)
		h.manager:tick()
		t.eq(session.roomIndex, 1, "frozen while paused")
		t.ok(h.manager:reconnect(seer))
		t.eq(session.status, "solved")
		h:advanceTime(10)
		h.manager:tick()
		t.eq(session.roomIndex, 2)
	end)

	t.test("leaving ends the session for both and frees membership", function()
		local h, session = started()
		t.ok(h.manager:leave(A))
		t.eq(session.status, "ended")
		t.eq(h.manager:sessionOf(A), nil)
		t.eq(h.manager:sessionOf(B), nil)
		t.ok(h.manager:start(A, C), "A can start a new session")
	end)
end
