--!strict
-- Visual building blocks: glyph chips/tiles (symbol + name + color, never
-- color alone) and analog clock faces.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Glyphs = require(ReplicatedStorage.Shared.Glyphs)
local Theme = require(script.Parent.Theme)

local create = Theme.create

local GlyphUi = {}

function GlyphUi.color(glyphId: string): Color3
	local glyph = Glyphs.byId[glyphId]
	if not glyph then
		return Theme.Colors.muted
	end
	return Color3.fromRGB(glyph.rgb[1], glyph.rgb[2], glyph.rgb[3])
end

function GlyphUi.char(glyphId: string): string
	local glyph = Glyphs.byId[glyphId]
	return if glyph then glyph.char else "?"
end

function GlyphUi.name(glyphId: string): string
	local glyph = Glyphs.byId[glyphId]
	return if glyph then glyph.name else glyphId
end

-- Inline chip for clue lines: "☾ Mond".
function GlyphUi.chip(parent: Instance, glyphId: string, textSize: number?, order: number?): Frame
	local size = textSize or 16
	local color = GlyphUi.color(glyphId)
	local chip = create("Frame", {
		BackgroundColor3 = Theme.Colors.inkSoft,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		LayoutOrder = order or 0,
		Parent = parent,
	})
	Theme.corner(chip, UDim.new(0, 6))
	Theme.stroke(chip, color, 1, 0.3)
	create("UIPadding", {
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
		PaddingTop = UDim.new(0, 2),
		PaddingBottom = UDim.new(0, 2),
		Parent = chip,
	})
	Theme.list(chip, Enum.FillDirection.Horizontal, 4, nil, Enum.VerticalAlignment.Center)
	Theme.label(
		chip,
		GlyphUi.char(glyphId),
		{ TextColor3 = color, TextSize = size + 2, Font = Theme.Fonts.glyph, LayoutOrder = 1 }
	)
	Theme.label(
		chip,
		GlyphUi.name(glyphId),
		{ TextColor3 = color, TextSize = size, Font = Theme.Fonts.bold, LayoutOrder = 2 }
	)
	return chip
end

-- Large square tile with the symbol and its name underneath.
-- `glyphId` may be nil or "empty" for a blank tile.
function GlyphUi.tile(parent: Instance, glyphId: string?, size: number, accent: Color3, order: number?): Frame
	local blank = glyphId == nil or glyphId == "empty"
	local color = if blank then Theme.Colors.muted else GlyphUi.color(glyphId :: string)
	local tile = create("Frame", {
		BackgroundColor3 = Theme.Colors.inkSoft,
		Size = UDim2.fromOffset(size, size),
		LayoutOrder = order or 0,
		Parent = parent,
	})
	Theme.corner(tile, UDim.new(0, 8))
	Theme.stroke(tile, if blank then accent else color, 2, if blank then 0.6 else 0.1)
	if not blank then
		Theme.label(tile, GlyphUi.char(glyphId :: string), {
			AutomaticSize = Enum.AutomaticSize.None,
			Size = UDim2.fromScale(1, 0.68),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = color,
			TextScaled = true,
			Font = Theme.Fonts.glyph,
		})
		Theme.label(tile, GlyphUi.name(glyphId :: string), {
			AutomaticSize = Enum.AutomaticSize.None,
			Position = UDim2.fromScale(0, 0.68),
			Size = UDim2.fromScale(1, 0.28),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = color,
			TextScaled = true,
			Font = Theme.Fonts.bold,
		})
	end
	return tile
end

-- Thin bar on a clock face, centred `radius` (scale) from the middle and
-- rotated `angle` degrees clockwise from 12 o'clock. Each bar rotates around
-- its own centre, so no rotated parent containers are needed.
local function radialBar(
	face: Frame,
	angle: number,
	radius: number,
	length: number,
	width: number,
	color: Color3
): Frame
	local rad = math.rad(angle)
	return create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5 + radius * math.sin(rad), 0.5 - radius * math.cos(rad)),
		Size = UDim2.new(0, width, length, 0),
		Rotation = angle,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = face,
	})
end

-- Analog clock face showing `hour` (1..12).
function GlyphUi.clock(parent: Instance, hour: number, size: number, accent: Color3, order: number?): Frame
	local ink = Color3.fromRGB(40, 32, 26)
	local face = create("Frame", {
		BackgroundColor3 = Theme.Colors.parchment,
		Size = UDim2.fromOffset(size, size),
		LayoutOrder = order or 0,
		Parent = parent,
	})
	Theme.corner(face, UDim.new(0.5, 0))
	Theme.stroke(face, accent, 3)
	for mark = 0, 11 do
		local length = if mark % 3 == 0 then 0.12 else 0.07
		radialBar(
			face,
			mark * 30,
			0.45 - length / 2,
			length,
			if mark == 0 then 4 else 2,
			if mark == 0 then accent else ink
		)
	end
	local pointer = radialBar(face, (hour % 12) * 30, 0.18, 0.36, math.max(3, size // 22), ink)
	Theme.corner(pointer, UDim.new(0, 2))
	local cap = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size // 9, size // 9),
		BackgroundColor3 = accent,
		Parent = face,
	})
	Theme.corner(cap, UDim.new(0.5, 0))
	return face
end

return GlyphUi
