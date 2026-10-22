--!strict
-- In-session HUD. Shows only the local player's role: the Seer sees the
-- clue panel, the Tinkerer the control panel - never both.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Glyphs = require(ReplicatedStorage.Shared.Glyphs)
local Types = require(ReplicatedStorage.Shared.Types)
local CluePanel = require(script.Parent.CluePanel)
local ControlPanel = require(script.Parent.ControlPanel)
local GlyphUi = require(script.Parent.GlyphUi)
local PingPanel = require(script.Parent.PingPanel)
local Strings = require(script.Parent.Parent.Strings)
local Theme = require(script.Parent.Theme)

local create = Theme.create

export type Handlers = {
	sendAction: (actionType: string, controlId: string?, value: number?) -> (),
	requestHint: () -> (),
	sendPing: (pingId: string) -> (),
	lobby: (action: string) -> (),
}

local Hud = {}
Hud.__index = Hud

export type Hud = typeof(setmetatable(
	{} :: {
		root: Frame,
		handlers: Handlers,
		view: Types.SessionView?,
		elapsedBase: number,
		-- widgets
		title: TextLabel,
		timer: TextLabel,
		roleCard: Frame,
		roleIcon: TextLabel,
		roleName: TextLabel,
		roleTask: TextLabel,
		panel: Frame,
		panelTitle: TextLabel,
		panelBody: Frame,
		panelToggle: TextButton,
		hintCard: Frame,
		hintTitle: TextLabel,
		hintList: Frame,
		hintButton: TextButton,
		pings: PingPanel.PingPanel,
		banner: TextLabel,
		bannerToken: number,
		pauseOverlay: Frame,
		legend: Frame,
		leaveButton: TextButton,
		leaveArmed: boolean,
	},
	Hud
))

local function formatTime(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d", total // 60, total % 60)
end

function Hud.new(parent: Instance, handlers: Handlers): Hud
	local root = create("Frame", {
		Name = "SessionHud",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = parent,
	})

	-- top center: room title + timer
	local top = Theme.card(root, Theme.Colors.latch, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
	})
	Theme.autoScale(top)
	local topPadding = top:FindFirstChildOfClass("UIPadding") :: UIPadding
	topPadding.PaddingTop = UDim.new(0, 6)
	topPadding.PaddingBottom = UDim.new(0, 6)
	Theme.list(top, Enum.FillDirection.Horizontal, 14, nil, Enum.VerticalAlignment.Center)
	local title = Theme.label(top, "", { Font = Theme.Fonts.title, TextSize = 22, LayoutOrder = 1 })
	local timer = Theme.label(top, "00:00", { TextColor3 = Theme.Colors.muted, LayoutOrder = 2 })

	-- left column: menu, hints, pings
	local left = create("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(300, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = root,
	})
	Theme.list(left, Enum.FillDirection.Vertical, 10)
	Theme.autoScale(left)

	local menu = Theme.stack(left, Enum.FillDirection.Horizontal, 8, 1)
	local hintCard = Theme.card(left, Theme.Colors.latch, { LayoutOrder = 2 })
	Theme.list(hintCard, Enum.FillDirection.Vertical, 6)
	local hintTitle = Theme.label(hintCard, Strings.hud.hints, { Font = Theme.Fonts.bold, LayoutOrder = 1 })
	local hintList = Theme.stack(hintCard, Enum.FillDirection.Vertical, 4, 2)
	hintList.AutomaticSize = Enum.AutomaticSize.Y
	hintList.Size = UDim2.fromScale(1, 0)

	-- right column: role card + main panel
	local right = create("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(480, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = root,
	})
	Theme.list(right, Enum.FillDirection.Vertical, 10, Enum.HorizontalAlignment.Right)
	Theme.autoScale(right)

	local roleCard = Theme.card(right, Theme.Colors.latch, { LayoutOrder = 1, Size = UDim2.fromOffset(480, 0) })
	local roleIcon = Theme.label(roleCard, "", {
		AutomaticSize = Enum.AutomaticSize.None,
		Size = UDim2.fromOffset(52, 52),
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.Fonts.glyph,
	})
	local roleText = create("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(64, 0),
		Size = UDim2.new(1, -64, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = roleCard,
	})
	Theme.list(roleText, Enum.FillDirection.Vertical, 4)
	local roleName = Theme.label(roleText, "", { Font = Theme.Fonts.title, TextSize = 22, LayoutOrder = 1 })
	local roleTask = Theme.paragraph(roleText, "", { TextSize = 14, TextColor3 = Theme.Colors.muted, LayoutOrder = 2 })

	local panel = Theme.card(right, Theme.Colors.latch, { LayoutOrder = 2, Size = UDim2.fromOffset(480, 0) })
	Theme.list(panel, Enum.FillDirection.Vertical, 10, Enum.HorizontalAlignment.Center)
	local panelHeader = create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 28),
		LayoutOrder = 1,
		Parent = panel,
	})
	local panelTitle = Theme.label(panelHeader, "", { Font = Theme.Fonts.bold, TextSize = 16 })
	local panelToggle = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(28, 28),
		BackgroundTransparency = 1,
		Text = "–",
		TextColor3 = Theme.Colors.muted,
		TextSize = 22,
		Font = Theme.Fonts.bold,
		Parent = panelHeader,
	})
	local panelBody = create("Frame", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromScale(1, 0),
		LayoutOrder = 2,
		Parent = panel,
	})
	Theme.list(panelBody, Enum.FillDirection.Vertical, 0, Enum.HorizontalAlignment.Center)

	-- notice banner
	local banner = Theme.label(root, "", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.2),
		Font = Theme.Fonts.title,
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.4,
		Visible = false,
	})

	-- pause overlay
	local pauseOverlay = Theme.card(root, Theme.Colors.bad, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(420, 0),
		Visible = false,
		ZIndex = 5,
	})
	Theme.list(pauseOverlay, Enum.FillDirection.Vertical, 10, Enum.HorizontalAlignment.Center)
	Theme.autoScale(pauseOverlay)
	Theme.paragraph(pauseOverlay, Strings.hud.paused, {
		Font = Theme.Fonts.title,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 1,
	})
	Theme.label(pauseOverlay, Strings.hud.pausedWait, { TextColor3 = Theme.Colors.muted, LayoutOrder = 2 })
	local pauseButtons = Theme.stack(pauseOverlay, Enum.FillDirection.Horizontal, 10, 3)
	Theme.button(pauseButtons, Strings.hud.requeue, Theme.Colors.latch, function()
		handlers.lobby("requeue")
	end, { LayoutOrder = 1 })
	Theme.button(pauseButtons, Strings.hud.toLobby, Theme.Colors.muted, function()
		handlers.lobby("leave")
	end, { LayoutOrder = 2 })

	-- glyph legend (opened from the Seer's symbol table)
	local legend = Theme.card(root, Theme.Colors.seer, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(360, 0),
		Visible = false,
		ZIndex = 4,
	})
	Theme.list(legend, Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Center)
	Theme.autoScale(legend)
	Theme.label(
		legend,
		Strings.hud.legendTitle,
		{ Font = Theme.Fonts.title, TextSize = 24, TextColor3 = Theme.Colors.seer, LayoutOrder = 1 }
	)
	local legendGrid = create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(330, 140),
		LayoutOrder = 2,
		Parent = legend,
	})
	create("UIGridLayout", {
		CellSize = UDim2.fromOffset(104, 64),
		CellPadding = UDim2.fromOffset(9, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = legendGrid,
	})
	for index, glyph in Glyphs.list do
		local cell = Theme.stack(legendGrid, Enum.FillDirection.Vertical, 0, index, Enum.HorizontalAlignment.Center)
		Theme.label(
			cell,
			glyph.char,
			{ TextSize = 30, TextColor3 = GlyphUi.color(glyph.id), Font = Theme.Fonts.glyph, LayoutOrder = 1 }
		)
		Theme.label(
			cell,
			glyph.name,
			{ TextSize = 14, TextColor3 = GlyphUi.color(glyph.id), Font = Theme.Fonts.bold, LayoutOrder = 2 }
		)
	end
	Theme.button(legend, Strings.hud.close, Theme.Colors.seer, function()
		legend.Visible = false
	end, { LayoutOrder = 3 })

	local self = setmetatable({
		root = root,
		handlers = handlers,
		view = nil,
		elapsedBase = os.clock(),
		title = title,
		timer = timer,
		roleCard = roleCard,
		roleIcon = roleIcon,
		roleName = roleName,
		roleTask = roleTask,
		panel = panel,
		panelTitle = panelTitle,
		panelBody = panelBody,
		panelToggle = panelToggle,
		hintCard = hintCard,
		hintTitle = hintTitle,
		hintList = hintList,
		hintButton = (nil :: any) :: TextButton,
		pings = PingPanel.new(left, handlers.sendPing),
		banner = banner,
		bannerToken = 0,
		pauseOverlay = pauseOverlay,
		legend = legend,
		leaveButton = (nil :: any) :: TextButton,
		leaveArmed = false,
	}, Hud)

	self.hintButton = Theme.button(hintCard, Strings.hud.requestHint, Theme.Colors.latch, function()
		handlers.requestHint()
	end, { LayoutOrder = 3, Size = UDim2.fromOffset(0, 30), TextSize = 14 })

	Theme.button(menu, Strings.hud.reset, Theme.Colors.muted, function()
		handlers.sendAction("reset")
	end, { LayoutOrder = 1, Size = UDim2.fromOffset(0, 30), TextSize = 14 })
	self.leaveButton = Theme.button(menu, Strings.hud.leave, Theme.Colors.bad, function()
		self:onLeavePressed()
	end, { LayoutOrder = 2, Size = UDim2.fromOffset(0, 30), TextSize = 14 })

	panelToggle.Activated:Connect(function()
		self:setPanelOpen(not panelBody.Visible)
	end)

	task.spawn(function()
		while true do
			if self.view and self.root.Visible then
				self.timer.Text = formatTime(os.clock() - self.elapsedBase)
			end
			task.wait(0.5)
		end
	end)

	return self
end

function Hud.onLeavePressed(self: Hud)
	if self.leaveArmed then
		self.handlers.lobby("leave")
		return
	end
	self.leaveArmed = true
	self.leaveButton.Text = Strings.hud.leaveConfirm
	task.delay(3, function()
		self.leaveArmed = false
		self.leaveButton.Text = Strings.hud.leave
	end)
end

function Hud.setPanelOpen(self: Hud, open: boolean)
	self.panelBody.Visible = open
	self.panelToggle.Text = if open then "–" else "+"
end

function Hud.openPanel(self: Hud)
	self:setPanelOpen(true)
end

function Hud.showLegend(self: Hud)
	self.legend.Visible = true
end

function Hud.hide(self: Hud)
	self.root.Visible = false
	self.view = nil
	self.legend.Visible = false
	self.pauseOverlay.Visible = false
	self.pings:clearFeed()
end

function Hud.update(self: Hud, view: Types.SessionView)
	local previous = self.view
	self.view = view
	self.root.Visible = true
	self.elapsedBase = os.clock() - view.elapsed

	local role: Types.Role = view.role
	local accent = Theme.accent(role)
	local roleChanged = previous == nil or previous.role ~= role or previous.roomId ~= view.roomId

	self.title.Text = `{Strings.hud.room} {view.roomIndex}/{view.roomCount} · {view.roomTitle}`
	self.title.TextColor3 = accent
	self.roleIcon.Text = Strings.roleIcon[role]
	self.roleIcon.TextColor3 = accent
	self.roleName.Text = `{Strings.hud.yourRole} {Strings.roleName[role]}`
	self.roleName.TextColor3 = accent
	self.roleTask.Text = view.task
	self.panelTitle.Text = Strings.panelTitle[role]
	self.panelTitle.TextColor3 = accent
	for _, card in { self.roleCard, self.panel } do
		local stroke = card:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = accent
		end
	end
	if roleChanged then
		self.pings:setAccent(accent)
		self:setPanelOpen(true)
	end

	if role == "Seer" then
		CluePanel.render(self.panelBody, view)
	else
		ControlPanel.render(self.panelBody, view, self.handlers.sendAction)
	end

	-- hints
	self.hintTitle.Text = `{Strings.hud.hints} {#view.hints}/{view.hintCount}`
	Theme.clear(self.hintList)
	if #view.hints == 0 then
		Theme.paragraph(self.hintList, Strings.hud.noHints, { TextColor3 = Theme.Colors.muted, TextSize = 13 })
	end
	for index, hint in view.hints do
		Theme.paragraph(self.hintList, `{index}. {hint}`, { TextSize = 13, LayoutOrder = index })
	end
	self.hintButton.Visible = #view.hints < view.hintCount

	self.pauseOverlay.Visible = view.status == "paused"
end

function Hud.notice(self: Hud, notice: Types.Notice)
	local text: string? = nil
	local color = Theme.Colors.text
	if notice.kind == "rejected" then
		text = if notice.reason then (Strings.rejected :: any)[notice.reason] else nil
		color = Theme.Colors.muted
	elseif notice.kind == "ended" then
		text = (Strings.notice :: any)[notice.reason or "abandoned"]
	else
		text = (Strings.notice :: any)[notice.kind]
		if notice.kind == "wrong" or notice.kind == "partnerLeft" then
			color = Theme.Colors.bad
		elseif notice.kind == "solved" or notice.kind == "stage" or notice.kind == "partnerBack" then
			color = Theme.Colors.good
		end
	end
	if not text then
		return
	end
	self.bannerToken += 1
	local token = self.bannerToken
	self.banner.Text = text
	self.banner.TextColor3 = color
	self.banner.Visible = true
	task.delay(3, function()
		if self.bannerToken == token then
			self.banner.Visible = false
		end
	end)
end

function Hud.ping(self: Hud, message: Types.PingMessage)
	self.pings:push(message)
end

return Hud
