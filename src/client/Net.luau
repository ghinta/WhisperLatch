--!strict
-- Client side of the network contract. Control actions go through a small
-- sequential queue: one action in flight, each stamped with the newest
-- revision the server sent, so fast clicking is not rejected as stale.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Protocol = require(ReplicatedStorage.Shared.Protocol)
local Types = require(ReplicatedStorage.Shared.Types)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Remote = Protocol.Remote

local function remote(name: string): RemoteEvent
	return Remotes:WaitForChild(name) :: RemoteEvent
end

type PendingAction = { actionType: string, controlId: string?, actionValue: number? }

local MAX_QUEUE = 4
local FLIGHT_TIMEOUT = 1

local Net = {
	Action = remote(Remote.Action),
	Ping = remote(Remote.Ping),
	Hint = remote(Remote.Hint),
	Lobby = remote(Remote.Lobby),
	View = remote(Remote.View),
	Notice = remote(Remote.Notice),
	PingFeed = remote(Remote.PingFeed),
	LobbyState = remote(Remote.LobbyState),
}

local view: Types.SessionView? = nil
local pending: { PendingAction } = {}
local inFlight = false
local flightToken = 0

local function pump()
	local current = view
	if inFlight or not current or #pending == 0 then
		return
	end
	local action = table.remove(pending, 1) :: PendingAction
	inFlight = true
	flightToken += 1
	local token = flightToken
	local request: Types.ActionRequest = {
		sessionId = current.sessionId,
		roomId = current.roomId,
		actionType = action.actionType,
		controlId = action.controlId,
		actionValue = action.actionValue,
		expectedRevision = current.revision,
	}
	Net.Action:FireServer(request)
	task.delay(FLIGHT_TIMEOUT, function()
		if inFlight and flightToken == token then
			inFlight = false
			pump()
		end
	end)
end

function Net.setView(newView: Types.SessionView)
	local previous = view
	view = newView
	if previous and (previous.roomId ~= newView.roomId or previous.role ~= newView.role) then
		table.clear(pending)
	end
	inFlight = false
	pump()
end

function Net.clearView()
	view = nil
	inFlight = false
	table.clear(pending)
end

function Net.sendAction(actionType: string, controlId: string?, value: number?)
	if not view or #pending >= MAX_QUEUE then
		return
	end
	table.insert(pending, { actionType = actionType, controlId = controlId, actionValue = value })
	pump()
end

function Net.requestHint()
	local current = view
	if current then
		local request: Types.HintRequest = { sessionId = current.sessionId, roomId = current.roomId }
		Net.Hint:FireServer(request)
	end
end

function Net.sendPing(pingId: string)
	local current = view
	if current then
		local request: Types.PingRequest = { sessionId = current.sessionId, pingId = pingId }
		Net.Ping:FireServer(request)
	end
end

function Net.lobby(action: string)
	local request: Types.LobbyRequest = { action = action }
	Net.Lobby:FireServer(request)
end

return Net
