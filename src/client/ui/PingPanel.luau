--!strict
-- Ping wheel (preset messages only, grouped by category) and message feed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Pings = require(ReplicatedStorage.Shared.Pings)
local Types = require(ReplicatedStorage.Shared.Types)
local GlyphUi = require(script.Parent.GlyphUi)
local Strings = require(script.Parent.Parent.Strings)
local Theme = require(script.Parent.Theme)

local create = Theme.create
local FEED_LENGTH = 6

local PingPanel = {}
PingPanel.__index = PingPanel

export type PingPanel = typeof(setmetatable(
	{} :: {
		root: Frame,
		feed: Frame,
		wheel: Frame,
		grid: Frame,
		tabs: Frame,
		category: Pings.PingCategory,
		onSend: (pingId: string) -> (),
		entries: number,
		accent: Color3,
	},
	PingPanel
))

local function pingContent(parent: Instance, ping: Pings.Ping, textSize: number, order: number?)
	if ping.glyph then
		GlyphUi.chip(parent, ping.glyph, textSize, order)
	else
		Theme.label(parent, ping.label, { TextSize = textSize, Font = Theme.Fonts.bold, LayoutOrder = order or 0 })
	end
end

function PingPanel.new(parent: Instance, onSend: (pingId: string) -> ()): PingPanel
	local root = Theme.card(parent, Theme.Colors.latch, { LayoutOrder = 3 })
	Theme.list(root, Enum.FillDirection.Vertical, 8)

	local feed = Theme.stack(root, Enum.FillDirection.Vertical, 4, 1)
	feed.AutomaticSize = Enum.AutomaticSize.Y
	feed.Size = UDim2.fromScale(1, 0)

	local toggle = Theme.button(
		root,
		`{Strings.hud.pings} ▾`,
		Theme.Colors.latch,
		function() end,
		{ LayoutOrder = 2 }
	)

	local wheel = Theme.stack(root, Enum.FillDirection.Vertical, 8, 3)
	wheel.Visible = false
	local tabs = Theme.stack(wheel, Enum.FillDirection.Horizontal, 4, 1)
	local grid = create("Frame", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromOffset(276, 0),
		LayoutOrder = 2,
		Parent = wheel,
	})
	create("UIGridLayout", {
		CellSize = UDim2.fromOffset(88, 34),
		CellPadding = UDim2.fromOffset(6, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})

	local self = setmetatable({
		root = root,
		feed = feed,
		wheel = wheel,
		grid = grid,
		tabs = tabs,
		category = "glyph" :: Pings.PingCategory,
		onSend = onSend,
		entries = 0,
		accent = Theme.Colors.latch,
	}, PingPanel)

	toggle.Activated:Connect(function()
		wheel.Visible = not wheel.Visible
		toggle.Text = `{Strings.hud.pings} {if wheel.Visible then "▴" else "▾"}`
	end)
	self:renderTabs()
	self:renderGrid()
	self:clearFeed()
	return self
end

function PingPanel.setAccent(self: PingPanel, accent: Color3)
	self.accent = accent
	self:renderTabs()
end

function PingPanel.renderTabs(self: PingPanel)
	Theme.clear(self.tabs)
	for index, category: Pings.PingCategory in Pings.categories do
		local active = category == self.category
		local tab = Theme.button(
			self.tabs,
			Strings.pingCategory[category],
			if active then self.accent else Theme.Colors.muted,
			function()
				self.category = category
				self:renderTabs()
				self:renderGrid()
			end,
			{ LayoutOrder = index, Size = UDim2.fromOffset(0, 28), TextSize = 13 }
		)
		tab.BackgroundColor3 = if active then Theme.Colors.inkSoft else Theme.Colors.ink
	end
end

function PingPanel.renderGrid(self: PingPanel)
	Theme.clear(self.grid)
	local order = 0
	for _, ping in Pings.list do
		if ping.category == self.category then
			order += 1
			local button = create("TextButton", {
				AutoButtonColor = true,
				BackgroundColor3 = Theme.Colors.inkSoft,
				Text = "",
				LayoutOrder = order,
				Parent = self.grid,
			})
			Theme.corner(button, UDim.new(0, 6))
			Theme.stroke(button, Theme.Colors.muted, 1, 0.6)
			local content = Theme.stack(button, Enum.FillDirection.Horizontal, 0, 0, Enum.HorizontalAlignment.Center)
			content.AutomaticSize = Enum.AutomaticSize.None
			content.Size = UDim2.fromScale(1, 1)
			pingContent(content, ping, if ping.category == "arrow" then 11 else 14)
			button.Activated:Connect(function()
				self.onSend(ping.id)
			end)
		end
	end
end

function PingPanel.clearFeed(self: PingPanel)
	Theme.clear(self.feed)
	self.entries = 0
	Theme.paragraph(
		self.feed,
		Strings.hud.feedEmpty,
		{ TextColor3 = Theme.Colors.muted, TextSize = 13, Name = "Empty" }
	)
end

function PingPanel.push(self: PingPanel, message: Types.PingMessage)
	local ping = Pings.byId[message.pingId]
	if not ping then
		return
	end
	local empty = self.feed:FindFirstChild("Empty")
	if empty then
		empty:Destroy()
	end
	self.entries += 1
	local fromPartner = message.from == "partner"
	local row = Theme.stack(self.feed, Enum.FillDirection.Horizontal, 6, -self.entries)
	Theme.label(row, `{if fromPartner then Strings.hud.partner else Strings.hud.you} ▸`, {
		TextColor3 = if fromPartner then self.accent else Theme.Colors.muted,
		TextSize = 14,
		Font = Theme.Fonts.bold,
		LayoutOrder = 1,
	})
	pingContent(row, ping, 15, 2)

	-- newest on top, keep the feed short
	local rows = {}
	for _, child in self.feed:GetChildren() do
		if child:IsA("Frame") then
			table.insert(rows, child)
		end
	end
	table.sort(rows, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for index = FEED_LENGTH + 1, #rows do
		rows[index]:Destroy()
	end
end

return PingPanel
