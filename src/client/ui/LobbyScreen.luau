--!strict
-- Lobby overlay: concept, roles, "how it works" and the pairing button.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)
local Strings = require(script.Parent.Parent.Strings)
local Theme = require(script.Parent.Theme)

local create = Theme.create

local LobbyScreen = {}
LobbyScreen.__index = LobbyScreen

export type LobbyScreen = typeof(setmetatable(
	{} :: {
		root: Frame,
		status: TextLabel,
		result: TextLabel,
		queueButton: TextButton,
		cancelButton: TextButton,
	},
	LobbyScreen
))

local function roleColumn(parent: Instance, role: Types.Role, text: string, order: number)
	local accent = Theme.accent(role)
	local card = Theme.card(parent, accent, { LayoutOrder = order, Size = UDim2.fromOffset(320, 0) })
	card.BackgroundColor3 = Theme.accentSoft(role)
	Theme.list(card, Enum.FillDirection.Vertical, 4)
	Theme.label(card, `{Strings.roleIcon[role]}  {Strings.roleName[role]}`, {
		Font = Theme.Fonts.title,
		TextSize = 26,
		TextColor3 = accent,
		LayoutOrder = 1,
	})
	Theme.label(card, string.upper(Strings.roleTagline[role]), {
		TextSize = 12,
		TextColor3 = accent,
		Font = Theme.Fonts.bold,
		LayoutOrder = 2,
	})
	Theme.paragraph(card, text, { TextSize = 15, LayoutOrder = 3 })
end

function LobbyScreen.new(parent: Instance, onAction: (action: string) -> ()): LobbyScreen
	local root = create("Frame", {
		Name = "Lobby",
		BackgroundColor3 = Color3.fromRGB(6, 9, 14),
		BackgroundTransparency = 0.35,
		Size = UDim2.fromScale(1, 1),
		Parent = parent,
	})

	local card = Theme.card(root, Theme.Colors.latch, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(720, 0),
	})
	card.BackgroundTransparency = 0.05
	local padding = card:FindFirstChildOfClass("UIPadding") :: UIPadding
	padding.PaddingLeft = UDim.new(0, 22)
	padding.PaddingRight = UDim.new(0, 22)
	padding.PaddingTop = UDim.new(0, 22)
	padding.PaddingBottom = UDim.new(0, 22)
	Theme.autoScale(card)
	Theme.list(card, Enum.FillDirection.Vertical, 14, Enum.HorizontalAlignment.Center)

	Theme.label(card, 'Whisper<font color="#40D4C8">Latch</font>', {
		RichText = true,
		Font = Theme.Fonts.title,
		TextSize = 54,
		LayoutOrder = 1,
	})
	Theme.label(card, Strings.lobby.subtitle, {
		Font = Theme.Fonts.title,
		TextSize = 22,
		TextColor3 = Theme.Colors.latch,
		LayoutOrder = 2,
	})

	local roles = Theme.stack(card, Enum.FillDirection.Horizontal, 16, 3)
	roleColumn(roles, "Seer", Strings.lobby.seerText, 1)
	roleColumn(roles, "Tinkerer", Strings.lobby.tinkererText, 2)

	local steps = Theme.stack(card, Enum.FillDirection.Horizontal, 18, 4)
	for index, step in Strings.lobby.steps do
		Theme.label(steps, step, { TextSize = 14, TextColor3 = Theme.Colors.muted, LayoutOrder = index })
	end
	Theme.label(card, Strings.lobby.swapNote, { TextSize = 14, Font = Theme.Fonts.hand, LayoutOrder = 5 })

	local actions = Theme.stack(card, Enum.FillDirection.Horizontal, 12, 6)
	local queueButton = Theme.button(actions, Strings.lobby.queue, Theme.Colors.latch, function()
		onAction("queue")
	end, { LayoutOrder = 1, Size = UDim2.fromOffset(0, 48), TextSize = 22 })
	local cancelButton = Theme.button(actions, Strings.lobby.cancel, Theme.Colors.muted, function()
		onAction("cancel")
	end, { LayoutOrder = 2, Size = UDim2.fromOffset(0, 48), Visible = false })

	local status = Theme.label(card, "", { TextColor3 = Theme.Colors.latch, LayoutOrder = 7, Visible = false })
	local result = Theme.label(card, "", { TextSize = 15, LayoutOrder = 8, Visible = false })
	Theme.label(card, Strings.lobby.friendNote, { TextSize = 12, TextColor3 = Theme.Colors.muted, LayoutOrder = 9 })

	return setmetatable({
		root = root,
		status = status,
		result = result,
		queueButton = queueButton,
		cancelButton = cancelButton,
	}, LobbyScreen)
end

function LobbyScreen.show(self: LobbyScreen, state: Types.LobbyState)
	self.root.Visible = true
	local queued = state.state == "queued"
	self.queueButton.Visible = not queued
	self.cancelButton.Visible = queued
	self.status.Visible = queued
	self.status.Text = Strings.lobby.queued

	local lastRun = state.lastRun
	self.result.Visible = lastRun ~= nil
	if lastRun then
		local headline = if lastRun.reason == "finished" then `{Strings.notice.finished}  ` else ""
		self.result.Text = headline .. Strings.summary(lastRun)
		self.result.TextColor3 = if lastRun.reason == "finished" then Theme.Colors.good else Theme.Colors.text
	end
end

function LobbyScreen.hide(self: LobbyScreen)
	self.root.Visible = false
end

return LobbyScreen
