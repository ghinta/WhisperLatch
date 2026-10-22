--!strict
-- Validates untrusted RemoteEvent payloads before they reach the
-- SessionManager. Every field is type-, range- and length-checked; anything
-- unexpected is rejected as "malformed".

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Protocol = require(ReplicatedStorage.Shared.Protocol)
local Types = require(ReplicatedStorage.Shared.Types)

local Limits = Protocol.Limits

local ActionGateway = {}

local function isId(value: any): boolean
	return type(value) == "string" and #value > 0 and #value <= Limits.maxIdLength and value:match("^[%w_]+$") ~= nil
end

local function isInteger(value: any, min: number, max: number): boolean
	return type(value) == "number" and value == value and value % 1 == 0 and value >= min and value <= max
end

function ActionGateway.parseAction(raw: any): (Types.ActionRequest?, string?)
	if type(raw) ~= "table" then
		return nil, "malformed"
	end
	local sessionId, roomId, actionType = raw.sessionId, raw.roomId, raw.actionType
	local controlId, actionValue, expectedRevision = raw.controlId, raw.actionValue, raw.expectedRevision
	if not isId(sessionId) or not isId(roomId) then
		return nil, "malformed"
	end
	if type(actionType) ~= "string" or not Protocol.ActionTypes[actionType] then
		return nil, "malformed"
	end
	if controlId ~= nil and not isId(controlId) then
		return nil, "malformed"
	end
	if actionValue ~= nil and not isInteger(actionValue, -Limits.maxActionValue, Limits.maxActionValue) then
		return nil, "malformed"
	end
	if not isInteger(expectedRevision, 0, Limits.maxRevision) then
		return nil, "malformed"
	end
	return {
		sessionId = sessionId,
		roomId = roomId,
		actionType = actionType,
		controlId = controlId,
		actionValue = actionValue,
		expectedRevision = expectedRevision,
	},
		nil
end

function ActionGateway.parsePing(raw: any): (Types.PingRequest?, string?)
	if type(raw) ~= "table" or not isId(raw.sessionId) or not isId(raw.pingId) then
		return nil, "malformed"
	end
	return { sessionId = raw.sessionId, pingId = raw.pingId }, nil
end

function ActionGateway.parseHint(raw: any): (Types.HintRequest?, string?)
	if type(raw) ~= "table" or not isId(raw.sessionId) or not isId(raw.roomId) then
		return nil, "malformed"
	end
	return { sessionId = raw.sessionId, roomId = raw.roomId }, nil
end

function ActionGateway.parseLobby(raw: any): (Types.LobbyRequest?, string?)
	if type(raw) ~= "table" or type(raw.action) ~= "string" or not Protocol.LobbyActions[raw.action] then
		return nil, "malformed"
	end
	return { action = raw.action }, nil
end

return ActionGateway
