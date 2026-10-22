--!strict
-- Server bootstrap: wires RemoteEvents, players, pairing, sessions and the
-- world. All game rules live in the pure services; this file only adapts
-- them to Roblox.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Protocol = require(ReplicatedStorage.Shared.Protocol)
local Types = require(ReplicatedStorage.Shared.Types)
local RateLimiter = require(script.Parent.logic.RateLimiter)
local Rooms = require(script.Parent.rooms)
local services = script.Parent.services
local ActionGateway = require(services.ActionGateway)
local ChamberService = require(services.ChamberService)
local PairingService = require(services.PairingService)
local ProgressService = require(services.ProgressService)
local SessionManager = require(services.SessionManager)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local function remote(name: string): RemoteEvent
	return Remotes:WaitForChild(name) :: RemoteEvent
end
local ActionRemote = remote(Protocol.Remote.Action)
local PingRemote = remote(Protocol.Remote.Ping)
local HintRemote = remote(Protocol.Remote.Hint)
local LobbyRemote = remote(Protocol.Remote.Lobby)
local ViewRemote = remote(Protocol.Remote.View)
local NoticeRemote = remote(Protocol.Remote.Notice)
local PingFeedRemote = remote(Protocol.Remote.PingFeed)
local LobbyStateRemote = remote(Protocol.Remote.LobbyState)

local LobbyAction = Protocol.LobbyAction

local function createProgressStore(): ProgressService.Store?
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore("WhisperLatchProgress_v1")
	end)
	if not ok then
		warn("[WhisperLatch] progress disabled:", store)
		return nil
	end
	return {
		update = function(key, transform)
			task.spawn(function()
				local success, err = pcall(function()
					store:UpdateAsync(key, function(old)
						return transform(old)
					end)
				end)
				if not success then
					warn("[WhisperLatch] progress save failed:", err)
				end
			end)
		end,
	}
end

local chambers = ChamberService.new()
chambers:setupLighting()
chambers:buildLobby()

local pairing = PairingService.new()
local progress = ProgressService.new(createProgressStore())
local random = Random.new()
local lastRun: { [number]: Types.RunSummary } = {}

local function now(): number
	return os.clock()
end

local actionLimiter = RateLimiter.new(now, 10, 8)
local pingLimiter = RateLimiter.new(now, 4, 2)
local hintLimiter = RateLimiter.new(now, 2, 0.5)
local lobbyLimiter = RateLimiter.new(now, 4, 1)

local sessions: SessionManager.SessionManager

local function placeInChamber(player: Player)
	local session = sessions:sessionOf(player.UserId)
	if session then
		chambers:teleport(player, chambers:spawnCFrame(session.slot, session.roleByUserId[player.UserId]))
	end
end

local function sendLobbyState(player: Player)
	local userId = player.UserId
	local state: Types.LobbyStateName = if sessions:sessionOf(userId)
		then "inSession"
		elseif pairing:isQueued(userId) then "queued"
		else "idle"
	local payload: Types.LobbyState = { state = state, lastRun = lastRun[userId] }
	LobbyStateRemote:FireClient(player, payload)
end

sessions = SessionManager.new({
	now = now,
	seed = function()
		return random:NextInteger(1, 2 ^ 31 - 1)
	end,
	rooms = Rooms,
	send = function(userId, channel, payload)
		local player = Players:GetPlayerByUserId(userId)
		if not player then
			return
		end
		if channel == "view" then
			ViewRemote:FireClient(player, payload)
		elseif channel == "notice" then
			NoticeRemote:FireClient(player, payload)
		elseif channel == "ping" then
			PingFeedRemote:FireClient(player, payload)
		end
	end,
	hooks = {
		onRoomStarted = function(session)
			chambers:ensureSlot(session.slot)
			chambers:setDoorOpen(session.slot, false)
			for _, userId in session.playerIds do
				local player = Players:GetPlayerByUserId(userId)
				if player then
					placeInChamber(player)
				end
			end
		end,
		onRoomSolved = function(session)
			chambers:setDoorOpen(session.slot, true)
		end,
		onPlayerRestored = function(_session, userId)
			local player = Players:GetPlayerByUserId(userId)
			if player then
				placeInChamber(player)
			end
		end,
		onSessionEnded = function(session, summary)
			progress:recordRun(session.playerIds, summary)
			chambers:setDoorOpen(session.slot, false)
			for _, userId in session.playerIds do
				lastRun[userId] = summary
				local player = Players:GetPlayerByUserId(userId)
				if player then
					chambers:teleport(player, chambers:lobbyCFrame())
					sendLobbyState(player)
				end
			end
		end,
	},
})

local function tryMatch()
	while pairing:size() >= 2 and sessions:hasCapacity() do
		local first, second = pairing:popPair()
		if not (first and second) then
			return
		end
		local session = sessions:start(first, second)
		if session then
			for _, userId in session.playerIds do
				local player = Players:GetPlayerByUserId(userId)
				if player then
					sendLobbyState(player)
				end
			end
		end
	end
end

-- Rejected requests get a resync of the authoritative view.
local function reject(player: Player, reason: string?)
	NoticeRemote:FireClient(player, { kind = "rejected", reason = reason })
	local view = sessions:viewFor(player.UserId)
	if view then
		ViewRemote:FireClient(player, view)
	end
end

ActionRemote.OnServerEvent:Connect(function(player: Player, raw: any)
	if not actionLimiter:allow(player.UserId) then
		return
	end
	local request, err = ActionGateway.parseAction(raw)
	if not request then
		reject(player, err)
		return
	end
	local ok, reason = sessions:handleAction(player.UserId, request)
	if not ok then
		reject(player, reason)
	end
end)

PingRemote.OnServerEvent:Connect(function(player: Player, raw: any)
	if not pingLimiter:allow(player.UserId) then
		return
	end
	local request = ActionGateway.parsePing(raw)
	if request then
		sessions:handlePing(player.UserId, request)
	end
end)

HintRemote.OnServerEvent:Connect(function(player: Player, raw: any)
	if not hintLimiter:allow(player.UserId) then
		return
	end
	local request = ActionGateway.parseHint(raw)
	if not request then
		return
	end
	local ok, reason = sessions:handleHint(player.UserId, request)
	if not ok then
		NoticeRemote:FireClient(player, { kind = "rejected", reason = reason })
	end
end)

LobbyRemote.OnServerEvent:Connect(function(player: Player, raw: any)
	if not lobbyLimiter:allow(player.UserId) then
		return
	end
	local request = ActionGateway.parseLobby(raw)
	if not request then
		return
	end
	local userId = player.UserId
	local action = request.action
	if action == LobbyAction.Hello then
		local view = sessions:viewFor(userId)
		if view then
			ViewRemote:FireClient(player, view)
		end
	elseif action == LobbyAction.Queue then
		if not sessions:sessionOf(userId) then
			pairing:enqueue(userId)
		end
	elseif action == LobbyAction.Cancel then
		pairing:cancel(userId)
	elseif action == LobbyAction.Leave then
		pairing:cancel(userId)
		sessions:leave(userId)
	elseif action == LobbyAction.Requeue then
		sessions:leave(userId)
		pairing:enqueue(userId)
	end
	sendLobbyState(player)
	tryMatch()
end)

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 10)
		task.wait(0.1)
		placeInChamber(player)
	end)
	-- rejoining the same server resumes a paused session
	sessions:reconnect(player.UserId)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	local userId = player.UserId
	pairing:cancel(userId)
	sessions:disconnect(userId)
	lastRun[userId] = nil
	for _, limiter in { actionLimiter, pingLimiter, hintLimiter, lobbyLimiter } do
		limiter:forget(userId)
	end
end)

task.spawn(function()
	while true do
		sessions:tick()
		tryMatch()
		task.wait(0.25)
	end
end)
