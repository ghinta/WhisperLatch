--!strict
-- Builds a SessionManager with a fake clock, fixed seeds and a recording
-- transport, and offers helpers to drive sessions like real clients.

local Server = game:GetService("ServerScriptService").Server
local Rooms = require(Server.rooms)
local SessionManager = require(Server.services.SessionManager)
local Solver = require(script.Parent.Solver)

export type Message = { userId: number, channel: string, payload: any }

local Harness = {}
Harness.__index = Harness

export type Harness = typeof(setmetatable(
	{} :: {
		clock: number,
		seedCounter: number,
		messages: { Message },
		manager: SessionManager.SessionManager,
		events: { string },
	},
	Harness
))

function Harness.new(overrides: { [string]: any }?): Harness
	local self = setmetatable({ clock = 1000, seedCounter = 0, messages = {}, events = {} }, Harness) :: any
	local config: { [string]: any } = {
		now = function()
			return self.clock
		end,
		seed = function()
			self.seedCounter += 1
			return 7919 * self.seedCounter
		end,
		rooms = Rooms,
		send = function(userId: number, channel: string, payload: any)
			table.insert(self.messages, { userId = userId, channel = channel, payload = payload })
		end,
		hooks = {
			onRoomStarted = function(session)
				table.insert(self.events, "roomStarted:" .. session.roomIndex)
			end,
			onRoomSolved = function(session)
				table.insert(self.events, "roomSolved:" .. session.roomIndex)
			end,
			onSessionEnded = function(_session, summary)
				table.insert(self.events, "ended:" .. summary.reason)
			end,
		},
	}
	for key, value in overrides or {} do
		config[key] = value
	end
	self.manager = SessionManager.new(config :: any)
	return self
end

function Harness.advanceTime(self: Harness, seconds: number)
	self.clock += seconds
end

function Harness.messagesFor(self: Harness, userId: number, channel: string?): { any }
	local result = {}
	for _, message in self.messages do
		if message.userId == userId and (channel == nil or message.channel == channel) then
			table.insert(result, message.payload)
		end
	end
	return result
end

function Harness.lastView(self: Harness, userId: number): any
	local views = self:messagesFor(userId, "view")
	return views[#views]
end

function Harness.seerAndTinkerer(self: Harness, userId: number): (number, number)
	local session = assert(self.manager:sessionOf(userId), "not in a session")
	local a, b = session.playerIds[1], session.playerIds[2]
	if session.roleByUserId[a] == "Seer" then
		return a, b
	end
	return b, a
end

-- Sends an action as the given user, using that user's latest revision.
function Harness.act(
	self: Harness,
	userId: number,
	actionType: string,
	controlId: string?,
	value: number?
): (boolean, string?)
	local session = assert(self.manager:sessionOf(userId), "not in a session")
	return self.manager:handleAction(userId, {
		sessionId = session.id,
		roomId = session.puzzle.roomId,
		actionType = actionType,
		controlId = controlId,
		actionValue = value,
		expectedRevision = session.revision,
	})
end

-- Solves the current room through the public action API.
function Harness.solveRoom(self: Harness, anyUserId: number)
	local _, tinkerer = self:seerAndTinkerer(anyUserId)
	local session = assert(self.manager:sessionOf(anyUserId))
	for _ = 1, 4 do
		for _, step in Solver.stageSteps(session.puzzle) do
			local ok, err = self:act(tinkerer, step.actionType, step.controlId, step.actionValue)
			assert(ok, "solver step rejected: " .. tostring(err))
		end
		self:advanceTime(2)
		local ok, err = self:act(tinkerer, "submit")
		assert(ok, "submit rejected: " .. tostring(err))
		if session.status == "solved" then
			return
		end
	end
	error("room not solved")
end

return Harness
