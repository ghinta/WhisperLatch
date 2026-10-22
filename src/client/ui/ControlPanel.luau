--!strict
-- Renders the Tinkerer's controls. Used for the HUD panel and for the
-- local-only SurfaceGui on the Tinkerer's control wall. All input is sent
-- to the server; nothing is decided locally.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Protocol = require(ReplicatedStorage.Shared.Protocol)
local Types = require(ReplicatedStorage.Shared.Types)
local GlyphUi = require(script.Parent.GlyphUi)
local Strings = require(script.Parent.Parent.Strings)
local Theme = require(script.Parent.Theme)

local ActionType = Protocol.ActionType
local create = Theme.create

export type Send = (actionType: string, controlId: string?, value: number?) -> ()

local ControlPanel = {}

local function iconButton(
	parent: Instance,
	text: string,
	accent: Color3,
	onActivated: () -> (),
	order: number
): TextButton
	local button = create("TextButton", {
		AutoButtonColor = true,
		BackgroundColor3 = Theme.Colors.inkSoft,
		Size = UDim2.fromOffset(44, 34),
		Text = text,
		TextColor3 = accent,
		TextSize = 18,
		Font = Theme.Fonts.bold,
		LayoutOrder = order,
		Parent = parent,
	})
	Theme.corner(button, UDim.new(0, 6))
	Theme.stroke(button, accent, 1.5, 0.3)
	button.Activated:Connect(onActivated)
	return button
end

local function optionOf(control: Types.ControlView): string
	local options = control.options
	return if options then options[control.value] or "?" else "?"
end

local function renderDial(parent: Instance, control: Types.ControlView, send: Send, accent: Color3, order: number)
	local column = Theme.stack(parent, Enum.FillDirection.Vertical, 6, order, Enum.HorizontalAlignment.Center)
	Theme.label(column, control.label, { TextColor3 = Theme.Colors.muted, TextSize = 14, LayoutOrder = 1 })
	if control.display == "clock" then
		local hour = tonumber(optionOf(control)) or 12
		GlyphUi.clock(column, hour, 92, accent, 2)
		local row = Theme.stack(column, Enum.FillDirection.Horizontal, 6, 3)
		iconButton(row, "◀", accent, function()
			send(ActionType.StepDial, control.id, -1)
		end, 1)
		Theme.label(
			row,
			`{hour} {Strings.controls.oClock}`,
			{ TextSize = 16, Font = Theme.Fonts.bold, LayoutOrder = 2 }
		)
		iconButton(row, "▶", accent, function()
			send(ActionType.StepDial, control.id, 1)
		end, 3)
	else
		iconButton(column, "▲", accent, function()
			send(ActionType.StepDial, control.id, 1)
		end, 2)
		GlyphUi.tile(column, optionOf(control), 80, accent, 3)
		iconButton(column, "▼", accent, function()
			send(ActionType.StepDial, control.id, -1)
		end, 4)
	end
end

local function renderSwitch(parent: Instance, control: Types.ControlView, send: Send, order: number)
	local column = Theme.stack(parent, Enum.FillDirection.Vertical, 8, order, Enum.HorizontalAlignment.Center)
	if control.glyph then
		GlyphUi.chip(column, control.glyph, 16, 1)
	end
	local on = control.value == 1
	local color = if on then Theme.Colors.good else Theme.Colors.muted
	local lever = create("TextButton", {
		AutoButtonColor = true,
		BackgroundColor3 = if on then Color3.fromRGB(20, 60, 40) else Theme.Colors.inkSoft,
		Size = UDim2.fromOffset(70, 90),
		Text = if on then `▲\n{Strings.controls.on}` else `{Strings.controls.off}\n▼`,
		TextColor3 = color,
		TextSize = 20,
		Font = Theme.Fonts.bold,
		LayoutOrder = 2,
		Parent = column,
	})
	Theme.corner(lever, UDim.new(0, 10))
	Theme.stroke(lever, color, 2)
	lever.Activated:Connect(function()
		send(ActionType.Toggle, control.id)
	end)
end

local function renderRow(root: Instance, controls: { Types.ControlView }, send: Send, accent: Color3)
	local row = Theme.stack(root, Enum.FillDirection.Horizontal, 14, 2)
	for index, control in controls do
		if control.kind == "dial" then
			renderDial(row, control, send, accent, index)
		elseif control.kind == "toggle" then
			renderSwitch(row, control, send, index)
		end
	end
end

local function tileButton(parent: Instance, option: string, size: number, order: number, onActivated: (() -> ())?)
	local blank = option == "empty"
	local color = if blank then Theme.Colors.muted else GlyphUi.color(option)
	local tile = create(if onActivated then "TextButton" else "TextLabel", {
		BackgroundColor3 = Theme.Colors.inkSoft,
		Size = UDim2.fromOffset(size, size),
		Text = if blank then "" else GlyphUi.char(option),
		TextColor3 = color,
		TextSize = math.floor(size * 0.5),
		Font = Theme.Fonts.glyph,
		LayoutOrder = order,
		Parent = parent,
	})
	Theme.corner(tile, UDim.new(0, 6))
	Theme.stroke(tile, color, 1.5, if blank then 0.6 else 0.1)
	if not blank and size >= 48 then
		Theme.label(tile, GlyphUi.name(option), {
			AutomaticSize = Enum.AutomaticSize.None,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -2),
			Size = UDim2.new(1, 0, 0, 12),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = color,
			TextSize = 11,
			Font = Theme.Fonts.bold,
		})
	end
	if onActivated then
		(tile :: TextButton).Activated:Connect(onActivated)
	end
end

local function grid(parent: Instance, cell: number, order: number): Frame
	local frame = create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(cell * 3 + 12, cell * 3 + 12),
		LayoutOrder = order,
		Parent = parent,
	})
	create("UIGridLayout", {
		CellSize = UDim2.fromOffset(cell, cell),
		CellPadding = UDim2.fromOffset(6, 6),
		FillDirectionMaxCells = 3,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = frame,
	})
	return frame
end

local function renderGrid(root: Instance, view: Types.SessionView, send: Send, accent: Color3)
	local controls = view.controls :: { Types.ControlView }
	local row = Theme.stack(root, Enum.FillDirection.Horizontal, 22, 2)

	local mine = Theme.stack(row, Enum.FillDirection.Vertical, 6, 1, Enum.HorizontalAlignment.Center)
	Theme.label(mine, Strings.controls.yourGrid, { TextColor3 = accent, Font = Theme.Fonts.bold, LayoutOrder = 1 })
	local field = grid(mine, 58, 2)
	for index, control in controls do
		tileButton(field, optionOf(control), 58, index, function()
			send(ActionType.StepDial, control.id, 1)
		end)
	end

	local reference = view.info and view.info.reference
	if reference then
		local column = Theme.stack(row, Enum.FillDirection.Vertical, 6, 2, Enum.HorizontalAlignment.Center)
		Theme.label(
			column,
			Strings.controls.reference,
			{ TextColor3 = Theme.Colors.muted, TextSize = 13, LayoutOrder = 1 }
		)
		local template = grid(column, 34, 2)
		for index, option in reference do
			tileButton(template, option, 34, index, nil)
		end
	end
end

local function renderReactor(root: Instance, view: Types.SessionView, send: Send, accent: Color3)
	local controls = view.controls :: { Types.ControlView }
	local info = view.info
	if not info then
		return
	end

	local status = Theme.stack(root, Enum.FillDirection.Horizontal, 16, 2)
	Theme.label(status, `{Strings.controls.stage} {info.stage}/{info.stageCount}`, {
		TextColor3 = accent,
		Font = Theme.Fonts.bold,
		TextSize = 18,
		LayoutOrder = 1,
	})
	local coreRow = Theme.stack(status, Enum.FillDirection.Horizontal, 6, 2)
	Theme.label(coreRow, `{Strings.controls.core}:`, { TextColor3 = Theme.Colors.muted, LayoutOrder = 1 })
	if info.core then
		GlyphUi.chip(coreRow, info.core, 18, 2)
	else
		Theme.label(coreRow, Strings.controls.coreHidden, { TextColor3 = Theme.Colors.muted, LayoutOrder = 2 })
	end

	local inputRow = Theme.stack(root, Enum.FillDirection.Horizontal, 6, 3)
	Theme.label(inputRow, `{Strings.controls.input}:`, { TextColor3 = Theme.Colors.muted, LayoutOrder = 0 })
	for slot = 1, info.inputMax do
		local entry = info.input[slot]
		if entry then
			GlyphUi.chip(inputRow, entry, 16, slot)
		else
			Theme.label(inputRow, "＿", { TextColor3 = Theme.Colors.muted, LayoutOrder = slot })
		end
	end
	Theme.button(inputRow, Strings.controls.clear, Theme.Colors.muted, function()
		send(ActionType.ClearInput)
	end, { LayoutOrder = 99, Size = UDim2.fromOffset(0, 28), TextSize = 14 })

	local buttons = Theme.stack(root, Enum.FillDirection.Horizontal, 12, 4)
	for index, control in controls do
		local glyph = control.glyph or ""
		local color = GlyphUi.color(glyph)
		local button = create("TextButton", {
			AutoButtonColor = true,
			BackgroundColor3 = Theme.Colors.inkSoft,
			Size = UDim2.fromOffset(78, 78),
			Text = GlyphUi.char(glyph),
			TextColor3 = color,
			TextSize = 34,
			Font = Theme.Fonts.glyph,
			LayoutOrder = index,
			Parent = buttons,
		})
		Theme.corner(button, UDim.new(0.5, 0))
		Theme.stroke(button, color, 2.5)
		Theme.label(button, control.label, {
			AutomaticSize = Enum.AutomaticSize.None,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(1, 0, 0, 12),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = color,
			TextSize = 11,
			Font = Theme.Fonts.bold,
		})
		button.Activated:Connect(function()
			send(ActionType.Press, control.id)
		end)
	end
end

-- Clears `container` and renders the controls of `view` into it.
function ControlPanel.render(container: Instance, view: Types.SessionView, send: Send)
	Theme.clear(container)
	local controls = view.controls
	if not controls then
		return
	end
	local accent = Theme.accent("Tinkerer")
	local root = Theme.stack(container, Enum.FillDirection.Vertical, 12, 0, Enum.HorizontalAlignment.Center)
	Theme.label(root, view.roomTitle, { Font = Theme.Fonts.title, TextSize = 24, TextColor3 = accent, LayoutOrder = 1 })
	if view.layout == "grid3" then
		renderGrid(root, view, send, accent)
	elseif view.layout == "reactor" then
		renderReactor(root, view, send, accent)
	else
		renderRow(root, controls, send, accent)
	end
	local submitProps = {
		LayoutOrder = 99,
		Size = UDim2.fromOffset(0, 42),
		TextSize = 18,
		BackgroundColor3 = Theme.Colors.tinkererSoft,
	}
	Theme.button(root, view.submitLabel or "Prüfen", accent, function()
		send(ActionType.Submit)
	end, submitProps)
end

return ControlPanel
