--!strict
-- Renders the Seer's clue. Used for the HUD panel and for the local-only
-- SurfaceGui on the Seer's clue wall.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)
local GlyphUi = require(script.Parent.GlyphUi)
local Strings = require(script.Parent.Parent.Strings)
local Theme = require(script.Parent.Theme)

local CluePanel = {}

local function renderSequence(parent: Instance, sequence: { string }, accent: Color3, order: number)
	local row = Theme.stack(parent, Enum.FillDirection.Horizontal, 10, order, Enum.HorizontalAlignment.Center)
	for index, glyphId in sequence do
		local column = Theme.stack(row, Enum.FillDirection.Vertical, 4, index, Enum.HorizontalAlignment.Center)
		Theme.label(
			column,
			tostring(index),
			{ TextColor3 = accent, Font = Theme.Fonts.title, TextSize = 20, LayoutOrder = 1 }
		)
		GlyphUi.tile(column, glyphId, 84, accent, 2)
	end
end

local function renderClocks(parent: Instance, hours: { number }, order: number)
	local mirror = Theme.create("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		LayoutOrder = order,
		Parent = parent,
	})
	Theme.corner(mirror, UDim.new(0, 14))
	Theme.stroke(mirror, Color3.fromRGB(200, 210, 225), 3)
	Theme.padding(mirror, 12)
	Theme.create("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(110, 125, 150), Color3.fromRGB(45, 52, 66)),
		Rotation = 35,
		Parent = mirror,
	})
	local column = Theme.stack(mirror, Enum.FillDirection.Vertical, 6, 0, Enum.HorizontalAlignment.Center)
	Theme.label(column, Strings.controls.mirror, { Font = Theme.Fonts.title, TextSize = 18, LayoutOrder = 1 })
	local row = Theme.stack(column, Enum.FillDirection.Horizontal, 14, 2)
	for index, hour in hours do
		GlyphUi.clock(row, hour, 96, Color3.fromRGB(200, 210, 225), index)
	end
end

local function renderLines(parent: Instance, lines: { { Types.ClueToken } }, order: number)
	local column = Theme.stack(parent, Enum.FillDirection.Vertical, 6, order)
	for index, line in lines do
		local row = Theme.stack(column, Enum.FillDirection.Horizontal, 6, index)
		for tokenIndex, token in line do
			if token.glyph then
				GlyphUi.chip(row, token.glyph, 16, tokenIndex)
			else
				Theme.label(row, token.text or "", { TextSize = 17, LayoutOrder = tokenIndex })
			end
		end
	end
end

-- Clears `container` and renders the clue of `view` into it.
function CluePanel.render(container: Instance, view: Types.SessionView)
	Theme.clear(container)
	local clue = view.clue
	if not clue then
		return
	end
	local accent = Theme.accent("Seer")
	local root = Theme.stack(container, Enum.FillDirection.Vertical, 10, 0, Enum.HorizontalAlignment.Center)
	Theme.label(root, clue.heading, { Font = Theme.Fonts.title, TextSize = 26, TextColor3 = accent, LayoutOrder = 1 })
	if clue.sequence then
		renderSequence(root, clue.sequence, accent, 2)
	end
	if clue.clocks then
		renderClocks(root, clue.clocks, 3)
	end
	if clue.lines then
		renderLines(root, clue.lines, 4)
	end
end

return CluePanel
