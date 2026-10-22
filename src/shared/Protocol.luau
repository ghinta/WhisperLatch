--!strict
-- Remote names, request enums and limits shared by server and client.

local ActionType = table.freeze({
	StepDial = "stepDial",
	SetDial = "setDial",
	Toggle = "toggle",
	Press = "press",
	ClearInput = "clearInput",
	Submit = "submit",
	Reset = "reset",
})

local LobbyAction = table.freeze({
	Hello = "hello",
	Queue = "queue",
	Cancel = "cancel",
	Leave = "leave",
	Requeue = "requeue",
})

local function valueSet(enum: { [string]: string }): { [string]: boolean }
	local set = {}
	for _, value in enum do
		set[value] = true
	end
	return table.freeze(set)
end

return table.freeze({
	-- RemoteEvents in ReplicatedStorage.Remotes (see default.project.json)
	Remote = table.freeze({
		-- client -> server
		Action = "Action",
		Ping = "Ping",
		Hint = "Hint",
		Lobby = "Lobby",
		-- server -> client (always FireClient, never FireAllClients)
		View = "View",
		Notice = "Notice",
		PingFeed = "PingFeed",
		LobbyState = "LobbyState",
	}),
	ActionType = ActionType,
	ActionTypes = valueSet(ActionType),
	LobbyAction = LobbyAction,
	LobbyActions = valueSet(LobbyAction),
	Limits = table.freeze({
		maxIdLength = 32,
		maxActionValue = 12,
		maxRevision = 2 ^ 31,
	}),
})
