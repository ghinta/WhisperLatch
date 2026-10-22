--!strict
-- Owns sessions, membership, roles and the session state machine:
--   active -> solved -> active (next room, roles swapped) ... -> ended
--   active/solved -> paused (disconnect) -> active/solved | ended (timeout)
-- Pure Luau: time, randomness, transport and world effects are injected.
-- Mutations never yield; views are pushed only after state is committed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Pings = require(ReplicatedStorage.Shared.Pings)
local Protocol = require(ReplicatedStorage.Shared.Protocol)
local Types = require(ReplicatedStorage.Shared.Types)
local PuzzleEngine = require(script.Parent.Parent.logic.PuzzleEngine)
local PuzzleTypes = require(script.Parent.Parent.logic.PuzzleTypes)
local Rng = require(script.Parent.Parent.logic.Rng)
local HintService = require(script.Parent.HintService)
local RoleViewFactory = require(script.Parent.RoleViewFactory)

local ActionType = Protocol.ActionType

export type Channel = "view" | "notice" | "ping"

export type Session = {
	id: string,
	playerIds: { number },
	roleByUserId: { [number]: Types.Role },
	connected: { [number]: boolean },
	slot: number,
	roomIndex: number,
	status: Types.SessionStatus,
	resumeStatus: Types.SessionStatus?,
	revision: number,
	puzzle: PuzzleTypes.Puzzle,
	attempts: number,
	hintsUsed: number,
	totalHints: number,
	lastHintAt: number,
	roomsCleared: number,
	startedAt: number,
	pausedAt: number?,
	advanceAt: number?,
	lastSubmitAt: number,
	lastResetAt: number,
}

export type Hooks = {
	-- a room begins (session start or after a role swap): place players
	onRoomStarted: ((session: Session) -> ())?,
	onRoomSolved: ((session: Session) -> ())?,
	onPlayerRestored: ((session: Session, userId: number) -> ())?,
	onSessionEnded: ((session: Session, summary: Types.RunSummary) -> ())?,
}

export type Config = {
	now: () -> number,
	seed: () -> number,
	rooms: { PuzzleTypes.RoomDefinition },
	send: (userId: number, channel: Channel, payload: any) -> (),
	hooks: Hooks?,
	slotCount: number?,
	advanceDelay: number?,
	pauseTimeout: number?,
	submitCooldown: number?,
	resetCooldown: number?,
}

type Fields = {
	now: () -> number,
	seed: () -> number,
	rooms: { PuzzleTypes.RoomDefinition },
	send: (userId: number, channel: Channel, payload: any) -> (),
	hooks: Hooks,
	slotCount: number,
	advanceDelay: number,
	pauseTimeout: number,
	submitCooldown: number,
	resetCooldown: number,
	sessions: { [string]: Session },
	byUser: { [number]: Session },
	usedSlots: { [number]: string },
	nextId: number,
}

local SessionManager = {}
SessionManager.__index = SessionManager

export type SessionManager = typeof(setmetatable({} :: Fields, SessionManager))

function SessionManager.new(config: Config): SessionManager
	return setmetatable({
		now = config.now,
		seed = config.seed,
		rooms = config.rooms,
		send = config.send,
		hooks = config.hooks or {},
		slotCount = config.slotCount or 6,
		advanceDelay = config.advanceDelay or 4,
		pauseTimeout = config.pauseTimeout or 90,
		submitCooldown = config.submitCooldown or 1,
		resetCooldown = config.resetCooldown or 3,
		sessions = {},
		byUser = {},
		usedSlots = {},
		nextId = 0,
	}, SessionManager)
end

local function partnerOf(session: Session, userId: number): number?
	for _, id in session.playerIds do
		if id ~= userId then
			return id
		end
	end
	return nil
end

function SessionManager.sessionOf(self: SessionManager, userId: number): Session?
	return self.byUser[userId]
end

function SessionManager.sessionCount(self: SessionManager): number
	local count = 0
	for _ in self.sessions do
		count += 1
	end
	return count
end

function SessionManager.freeSlot(self: SessionManager): number?
	for slot = 1, self.slotCount do
		if not self.usedSlots[slot] then
			return slot
		end
	end
	return nil
end

function SessionManager.hasCapacity(self: SessionManager): boolean
	return self:freeSlot() ~= nil
end

function SessionManager.viewFor(self: SessionManager, userId: number): Types.SessionView?
	local session = self.byUser[userId]
	if not session then
		return nil
	end
	local partner = partnerOf(session, userId)
	local ctx: RoleViewFactory.ViewContext = {
		sessionId = session.id,
		status = session.status,
		slot = session.slot,
		roomIndex = session.roomIndex,
		roomCount = #self.rooms,
		revision = session.revision,
		attempts = session.attempts,
		hintsUsed = session.hintsUsed,
		partnerConnected = partner ~= nil and session.connected[partner] == true,
		elapsed = self.now() - session.startedAt,
	}
	return RoleViewFactory.build(session.roleByUserId[userId], ctx, self.rooms[session.roomIndex], session.puzzle)
end

function SessionManager.pushView(self: SessionManager, session: Session, userId: number)
	if not session.connected[userId] then
		return
	end
	local view = self:viewFor(userId)
	if view then
		self.send(userId, "view", view)
	end
end

function SessionManager.pushViews(self: SessionManager, session: Session)
	for _, userId in session.playerIds do
		self:pushView(session, userId)
	end
end

function SessionManager.notify(self: SessionManager, session: Session, notice: Types.Notice)
	for _, userId in session.playerIds do
		if session.connected[userId] then
			self.send(userId, "notice", notice)
		end
	end
end

-- Creates a session for two lobby players. Returns nil if either player is
-- already in a session or no chamber slot is free.
function SessionManager.start(self: SessionManager, userA: number, userB: number): Session?
	if userA == userB or self.byUser[userA] or self.byUser[userB] then
		return nil
	end
	local slot = self:freeSlot()
	if not slot then
		return nil
	end
	local rng = Rng.new(self.seed())
	local seer, tinkerer = userA, userB
	if rng:integer(0, 1) == 1 then
		seer, tinkerer = userB, userA
	end
	local now = self.now()
	self.nextId += 1
	local session: Session = {
		id = "S" .. self.nextId,
		playerIds = { userA, userB },
		roleByUserId = { [seer] = "Seer", [tinkerer] = "Tinkerer" },
		connected = { [userA] = true, [userB] = true },
		slot = slot,
		roomIndex = 1,
		status = "active",
		revision = 1,
		puzzle = PuzzleEngine.create(self.rooms[1], rng),
		attempts = 0,
		hintsUsed = 0,
		totalHints = 0,
		lastHintAt = -math.huge,
		roomsCleared = 0,
		startedAt = now,
		lastSubmitAt = -math.huge,
		lastResetAt = -math.huge,
	}
	self.sessions[session.id] = session
	self.byUser[userA] = session
	self.byUser[userB] = session
	self.usedSlots[slot] = session.id

	local hook = self.hooks.onRoomStarted
	if hook then
		hook(session)
	end
	self:pushViews(session)
	return session
end

function SessionManager.handleAction(
	self: SessionManager,
	userId: number,
	request: Types.ActionRequest
): (boolean, string?)
	local session = self.byUser[userId]
	if not session or session.id ~= request.sessionId then
		return false, "notInSession"
	end
	if session.status ~= "active" then
		return false, "notActive"
	end
	local def = self.rooms[session.roomIndex]
	if request.roomId ~= def.id then
		return false, "wrongRoom"
	end
	local now = self.now()

	-- Either role may restart the current room with a fresh puzzle.
	if request.actionType == ActionType.Reset then
		if now - session.lastResetAt < self.resetCooldown then
			return false, "cooldown"
		end
		session.lastResetAt = now
		session.puzzle = PuzzleEngine.create(def, Rng.new(self.seed()))
		session.attempts = 0
		session.revision += 1
		self:notify(session, { kind = "reset" })
		self:pushViews(session)
		return true, nil
	end

	if session.roleByUserId[userId] ~= "Tinkerer" then
		return false, "wrongRole"
	end
	if request.expectedRevision ~= session.revision then
		return false, "staleRevision"
	end

	if request.actionType == ActionType.Submit then
		if now - session.lastSubmitAt < self.submitCooldown then
			return false, "cooldown"
		end
		session.lastSubmitAt = now
		session.attempts += 1
		local result = PuzzleEngine.submit(def, session.puzzle)
		session.revision += 1
		if result == "solved" then
			session.status = "solved"
			session.roomsCleared += 1
			session.advanceAt = now + self.advanceDelay
			local hook = self.hooks.onRoomSolved
			if hook then
				hook(session)
			end
		end
		local notice: Types.Notice = { kind = result :: Types.NoticeKind }
		self:notify(session, notice)
		self:pushViews(session)
		return true, nil
	end

	local ok, err = PuzzleEngine.apply(def, session.puzzle, request.actionType, request.controlId, request.actionValue)
	if not ok then
		return false, err
	end
	session.revision += 1
	-- control changes only affect the Tinkerer's view
	self:pushView(session, userId)
	return true, nil
end

function SessionManager.handleHint(self: SessionManager, userId: number, request: Types.HintRequest): (boolean, string?)
	local session = self.byUser[userId]
	if not session or session.id ~= request.sessionId then
		return false, "notInSession"
	end
	if session.status ~= "active" then
		return false, "notActive"
	end
	local def = self.rooms[session.roomIndex]
	if request.roomId ~= def.id then
		return false, "wrongRoom"
	end
	local ok, err = HintService.request(session, def, self.now())
	if not ok then
		return false, err
	end
	self:notify(session, { kind = "hint" })
	self:pushViews(session)
	return true, nil
end

function SessionManager.handlePing(self: SessionManager, userId: number, request: Types.PingRequest): (boolean, string?)
	local session = self.byUser[userId]
	if not session or session.id ~= request.sessionId then
		return false, "notInSession"
	end
	if session.status ~= "active" and session.status ~= "solved" then
		return false, "notActive"
	end
	if not Pings.byId[request.pingId] then
		return false, "unknownPing"
	end
	for _, memberId in session.playerIds do
		if session.connected[memberId] then
			local message: Types.PingMessage = {
				from = if memberId == userId then "self" else "partner",
				pingId = request.pingId,
			}
			self.send(memberId, "ping", message)
		end
	end
	return true, nil
end

function SessionManager.endSession(self: SessionManager, session: Session, reason: Types.EndReason)
	if session.status == "ended" then
		return
	end
	session.status = "ended"
	session.advanceAt = nil
	local summary: Types.RunSummary = {
		reason = reason,
		roomsCleared = session.roomsCleared,
		roomCount = #self.rooms,
		seconds = self.now() - session.startedAt,
		hintsUsed = session.totalHints,
	}
	self.sessions[session.id] = nil
	self.usedSlots[session.slot] = nil
	for _, userId in session.playerIds do
		if self.byUser[userId] == session then
			self.byUser[userId] = nil
		end
	end
	self:notify(session, { kind = "ended", reason = reason, summary = summary })
	local hook = self.hooks.onSessionEnded
	if hook then
		hook(session, summary)
	end
end

-- Moves to the next room and swaps roles exactly once, or finishes the run.
function SessionManager.advance(self: SessionManager, session: Session)
	session.advanceAt = nil
	if session.roomIndex >= #self.rooms then
		self:endSession(session, "finished")
		return
	end
	session.roomIndex += 1
	for _, userId in session.playerIds do
		session.roleByUserId[userId] = if session.roleByUserId[userId] == "Seer" then "Tinkerer" else "Seer"
	end
	session.puzzle = PuzzleEngine.create(self.rooms[session.roomIndex], Rng.new(self.seed()))
	session.status = "active"
	session.attempts = 0
	session.hintsUsed = 0
	session.lastSubmitAt = -math.huge
	session.revision += 1
	local hook = self.hooks.onRoomStarted
	if hook then
		hook(session)
	end
	self:notify(session, { kind = "advanced" })
	self:pushViews(session)
end

-- Freezes the chamber when a member leaves the server. The session ends
-- immediately if nobody is left.
function SessionManager.disconnect(self: SessionManager, userId: number)
	local session = self.byUser[userId]
	if not session or not session.connected[userId] then
		return
	end
	session.connected[userId] = false
	local partner = partnerOf(session, userId)
	if not (partner and session.connected[partner]) then
		self:endSession(session, "abandoned")
		return
	end
	if session.status ~= "paused" then
		session.resumeStatus = session.status
		session.status = "paused"
	end
	session.pausedAt = self.now()
	self:notify(session, { kind = "partnerLeft" })
	self:pushViews(session)
end

-- Restores a member who rejoins the same server while the session is paused.
function SessionManager.reconnect(self: SessionManager, userId: number): boolean
	local session = self.byUser[userId]
	if not session or session.connected[userId] then
		return false
	end
	session.connected[userId] = true
	session.status = session.resumeStatus or "active"
	session.resumeStatus = nil
	session.pausedAt = nil
	if session.status == "solved" then
		session.advanceAt = self.now() + self.advanceDelay
	end
	local hook = self.hooks.onPlayerRestored
	if hook then
		hook(session, userId)
	end
	local partner = partnerOf(session, userId)
	if partner and session.connected[partner] then
		self.send(partner, "notice", { kind = "partnerBack" })
	end
	self:pushViews(session)
	return true
end

-- Voluntary leave (back to lobby or requeue). Ends the session for both.
function SessionManager.leave(self: SessionManager, userId: number): boolean
	local session = self.byUser[userId]
	if not session then
		return false
	end
	self:endSession(session, "abandoned")
	return true
end

-- Drives timers: room advance after a solve, pause timeout.
function SessionManager.tick(self: SessionManager)
	local now = self.now()
	local snapshot = {}
	for _, session in self.sessions do
		table.insert(snapshot, session)
	end
	for _, session in snapshot do
		if session.status == "paused" and session.pausedAt and now - session.pausedAt >= self.pauseTimeout then
			self:endSession(session, "timeout")
		elseif session.status == "solved" and session.advanceAt and now >= session.advanceAt then
			self:advance(session)
		end
	end
end

return SessionManager
