--!nonstrict
-- Roblox smoke test without Studio:
--   * builds the world (lobby, chambers, door) with the real ChamberService
--   * renders the real client UI with views produced by the real server
--     logic, for every room and both roles, plus HUD, ping wheel and lobby
--   * places the local-only chamber panels and prompts
-- Instances come from Lune's Roblox library, which validates every property
-- name and value type against the Roblox API. Signals are stubbed: this
-- checks construction, not interaction or rendering.
--
-- Usage: lune run scripts/smoke.luau

local process = require("@lune/process")
local roblox = require("@lune/roblox")
local FakeTree = require("./lib/FakeTree")

--------------------------------------------------------------------------------
-- Instance wrapper: real Lune instances, stubbed signals
--------------------------------------------------------------------------------

local SIGNALS = { Activated = true, Triggered = true, Changed = true, OnClientEvent = true }

local realOf = setmetatable({}, { __mode = "k" })
-- per-instance property stubs for values Lune cannot provide (e.g. cameras)
local stubs = setmetatable({}, { __mode = "k" })
local proxyOf = setmetatable({}, { __mode = "k" })
local connections = 0

local function fakeSignal()
	return {
		Connect = function(_, callback)
			assert(type(callback) == "function", "Connect expects a function")
			connections += 1
			return { Disconnect = function() end }
		end,
	}
end

local wrap

local function unwrap(value)
	return if type(value) == "table" and realOf[value] then realOf[value] else value
end

local function wrapValue(value)
	if typeof(value) == "Instance" then
		return wrap(value)
	elseif type(value) == "table" then
		local list = {}
		for index, item in value do
			list[index] = wrapValue(item)
		end
		return list
	end
	return value
end

function wrap(real)
	local existing = proxyOf[real]
	if existing then
		return existing
	end
	local proxy = setmetatable({}, {
		__index = function(_, key)
			if SIGNALS[key] then
				return fakeSignal()
			elseif key == "GetPropertyChangedSignal" then
				return function()
					return fakeSignal()
				end
			end
			local stub = stubs[real]
			if stub and stub[key] ~= nil then
				return stub[key]
			end
			if key == "WaitForChild" then
				-- nothing streams in here: waiting equals a direct lookup
				key = "FindFirstChild"
			end
			local value = real[key]
			if type(value) == "function" then
				return function(_, ...)
					local args = table.pack(...)
					for i = 1, args.n do
						args[i] = unwrap(args[i])
					end
					return wrapValue(value(real, table.unpack(args, 1, args.n)))
				end
			end
			return wrapValue(value)
		end,
		__newindex = function(_, key, value)
			real[key] = unwrap(value)
		end,
		__tostring = function()
			return tostring(real)
		end,
	})
	realOf[proxy] = real
	proxyOf[real] = proxy
	return proxy
end

local Instance = {
	new = function(className: string)
		return wrap(roblox.Instance.new(className))
	end,
}

local camera = {
	ViewportSize = roblox.Vector2.new(1280, 720),
	GetPropertyChangedSignal = function()
		return fakeSignal()
	end,
}

local playerGui = Instance.new("Folder")
local workspace = Instance.new("Workspace")
stubs[realOf[workspace]] = { CurrentCamera = camera }

local tree = FakeTree.new({
	mounts = {
		{ service = "ReplicatedStorage", name = "Shared", path = "src/shared" },
		{ service = "ServerScriptService", name = "Server", path = "src/server" },
		{ service = "StarterPlayerScripts", name = "Client", path = "src/client" },
		{ service = "TestService", name = "Tests", path = "tests" },
	},
	globals = {
		Instance = Instance,
		Enum = roblox.Enum,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		Vector2 = roblox.Vector2,
		Vector3 = roblox.Vector3,
		CFrame = roblox.CFrame,
		TweenInfo = {
			new = function(...)
				return { ... }
			end,
		},
		Color3 = roblox.Color3,
		ColorSequence = roblox.ColorSequence,
		typeof = function(value)
			return if type(value) == "table" and realOf[value] then "Instance" else typeof(value)
		end,
		task = {
			-- run immediately; a task.wait parks the coroutine for good
			spawn = function(fn, ...)
				local ok, err = coroutine.resume(coroutine.create(fn), ...)
				if not ok then
					error(err, 2)
				end
			end,
			delay = function() end,
			wait = function()
				coroutine.yield()
			end,
		},
	},
	services = {
		Workspace = workspace,
		Lighting = Instance.new("Lighting"),
		Players = { LocalPlayer = {
			WaitForChild = function()
				return playerGui
			end,
		} },
		TweenService = {
			Create = function()
				return { Play = function() end }
			end,
		},
	},
})

local game = tree.game
local require = tree.require
local Client = game.StarterPlayerScripts.Client

local Rooms = require(game.ServerScriptService.Server.rooms)
local Harness = require(game.TestService.Tests.helpers.Harness)
local Solver = require(game.TestService.Tests.helpers.Solver)
local Pings = require(game.ReplicatedStorage.Shared.Pings)
local World = require(game.ReplicatedStorage.Shared.World)
local ChamberService = require(game.ServerScriptService.Server.services.ChamberService)
local ChamberDecor = require(Client.world.ChamberDecor)
local CluePanel = require(Client.ui.CluePanel)
local ControlPanel = require(Client.ui.ControlPanel)
local Hud = require(Client.ui.Hud)
local LobbyScreen = require(Client.ui.LobbyScreen)

--------------------------------------------------------------------------------
-- Scenarios
--------------------------------------------------------------------------------

local failures = 0
local checks = 0

local function check(name: string, fn: () -> ())
	checks += 1
	local ok, err = xpcall(fn, debug.traceback)
	if ok then
		print("  ✓ " .. name)
	else
		failures += 1
		print("  ✗ " .. name .. "\n    " .. tostring(err):gsub("\n", "\n    "))
	end
end

local function countDescendants(proxy): number
	return #realOf[proxy]:GetDescendants()
end

check("world: lighting, lobby, two chamber slots, door", function()
	local chambers = ChamberService.new()
	chambers:setupLighting()
	chambers:buildLobby()
	chambers:ensureSlot(1)
	chambers:ensureSlot(2)
	chambers:setDoorOpen(1, true)
	chambers:setDoorOpen(1, false)
	assert(chambers:spawnCFrame(1, "Seer") ~= chambers:spawnCFrame(1, "Tinkerer"), "separate spawns")
	local slot = workspace:FindFirstChild(World.Root):FindFirstChild(World.Chambers):FindFirstChild(World.slotName(1))
	local required = {
		{ World.SeerRoom, World.CluePanel },
		{ World.SeerRoom, World.SymbolTable },
		{ World.TinkererRoom, World.ControlPanel },
		{ World.TinkererRoom, World.Console },
		{ World.TinkererRoom, World.CheckButton },
	}
	for _, path in required do
		local room = slot:FindFirstChild(path[1])
		assert(room and room:FindFirstChild(path[2]), `missing {path[1]}/{path[2]}`)
	end
	print(`    world parts: {countDescendants(workspace)}`)
end)

local screen = Instance.new("ScreenGui")
local hud = Hud.new(screen, {
	sendAction = function() end,
	requestHint = function() end,
	sendPing = function() end,
	lobby = function() end,
})
local lobby = LobbyScreen.new(screen, function() end)

ChamberDecor.init({
	sendAction = function() end,
	openPanel = function() end,
	showLegend = function() end,
})

local h = Harness.new()
local A, B = 1, 2
local session = h.manager:start(A, B)

for room = 1, #Rooms do
	local def = Rooms[room]
	local seer, tinkerer = h:seerAndTinkerer(A)
	h.manager:handleHint(seer, { sessionId = session.id, roomId = def.id })
	h:advanceTime(10)

	for _, userId in { seer, tinkerer } do
		local view = h.manager:viewFor(userId)
		check(`{def.id} / {view.role}: panel renders`, function()
			local container = Instance.new("Frame")
			if view.role == "Seer" then
				CluePanel.render(container, view)
			else
				ControlPanel.render(container, view, function() end)
			end
			assert(countDescendants(container) > 5, "panel is empty")
			-- re-render into the same container (view updates)
			if view.role == "Seer" then
				CluePanel.render(container, view)
			else
				ControlPanel.render(container, view, function() end)
			end
		end)
		check(`{def.id} / {view.role}: HUD update`, function()
			hud:update(view)
		end)
		check(`{def.id} / {view.role}: chamber panel + prompts`, function()
			ChamberDecor.update(view)
			local surface = playerGui:FindFirstChild("WhisperLatchPanel")
			assert(surface and surface.Adornee, "panel SurfaceGui placed")
			local expected = if view.role == "Seer" then World.CluePanel else World.ControlPanel
			assert(surface.Adornee.Name == expected, "adorned to " .. surface.Adornee.Name)
			assert(countDescendants(surface) > 5, "panel rendered")
			ChamberDecor.update(nil)
			assert(playerGui:FindFirstChild("WhisperLatchPanel") == nil, "cleared")
		end)
	end

	if def.id == "dual_reactor" then
		-- stage 2 shows the core and a partial input
		for _, step in Solver.stageSteps(session.puzzle) do
			h:act(tinkerer, step.actionType, step.controlId, step.actionValue)
		end
		h:act(tinkerer, "submit")
		h:act(tinkerer, "press", session.puzzle.controls[1].id)
		check("dual_reactor / Tinkerer: stage 2 renders", function()
			local view = h.manager:viewFor(tinkerer)
			assert(view.info.core, "core revealed")
			ControlPanel.render(Instance.new("Frame"), view, function() end)
		end)
		h:act(tinkerer, "clearInput")
	end

	h:solveRoom(A)
	h:advanceTime(10)
	h.manager:tick()
end

check("HUD notices and pause overlay", function()
	for _, kind in { "wrong", "stage", "solved", "advanced", "reset", "hint", "partnerLeft", "partnerBack" } do
		hud:notice({ kind = kind })
	end
	hud:notice({ kind = "rejected", reason = "cooldown" })
	hud:notice({ kind = "ended", reason = "finished" })
	hud:openPanel()
	hud:showLegend()
	hud:hide()
end)

check("ping feed accepts every preset ping", function()
	for _, ping in Pings.list do
		hud:ping({ from = "partner", pingId = ping.id })
		hud:ping({ from = "self", pingId = ping.id })
	end
end)

check("lobby states", function()
	lobby:show({ state = "idle" })
	lobby:show({ state = "queued" })
	lobby:show({
		state = "idle",
		lastRun = { reason = "finished", roomsCleared = 5, roomCount = 5, seconds = 754, hintsUsed = 2 },
	})
	lobby:hide()
end)

print(`\n{checks - failures}/{checks} smoke checks passed ({connections} handlers connected)`)
process.exit(if failures == 0 then 0 else 1)
