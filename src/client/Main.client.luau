--!strict
-- Client bootstrap. The client is an untrusted view and input device: it
-- renders whatever role view the server sends and forwards input.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local Net = require(script.Parent.Net)
local Hud = require(script.Parent.ui.Hud)
local LobbyScreen = require(script.Parent.ui.LobbyScreen)
local ChamberDecor = require(script.Parent.world.ChamberDecor)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screen = Instance.new("ScreenGui")
screen.Name = "WhisperLatch"
screen.ResetOnSpawn = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.IgnoreGuiInset = false
screen.Parent = playerGui

local hud = Hud.new(screen, {
	sendAction = Net.sendAction,
	requestHint = Net.requestHint,
	sendPing = Net.sendPing,
	lobby = Net.lobby,
})

local lobby = LobbyScreen.new(screen, Net.lobby)

ChamberDecor.init({
	sendAction = Net.sendAction,
	openPanel = function()
		hud:openPanel()
	end,
	showLegend = function()
		hud:showLegend()
	end,
})

Net.View.OnClientEvent:Connect(function(view: Types.SessionView)
	Net.setView(view)
	lobby:hide()
	hud:update(view)
	ChamberDecor.update(view)
end)

Net.LobbyState.OnClientEvent:Connect(function(state: Types.LobbyState)
	if state.state == "inSession" then
		lobby:hide()
		return
	end
	Net.clearView()
	hud:hide()
	ChamberDecor.update(nil)
	lobby:show(state)
end)

Net.Notice.OnClientEvent:Connect(function(notice: Types.Notice)
	hud:notice(notice)
end)

Net.PingFeed.OnClientEvent:Connect(function(message: Types.PingMessage)
	hud:ping(message)
end)

lobby:show({ state = "idle" })
-- ask for the current state (also restores a paused session after rejoin)
Net.lobby("hello")
