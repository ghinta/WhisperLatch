--!strict
-- Builds the physical world: the lobby and one pair of chambers per session
-- slot. Each chamber is fully enclosed and slots are far apart, so a player
-- only ever sees their own room. No puzzle data is ever placed in the world:
-- each client renders its own role's panel locally (client/world).

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Glyphs = require(ReplicatedStorage.Shared.Glyphs)
local Types = require(ReplicatedStorage.Shared.Types)
local World = require(ReplicatedStorage.Shared.World)

local SLOT_ORIGIN = Vector3.new(0, 0, 600)
local SLOT_SPACING = 200
local ROOM_W = 40
local ROOM_D = 36
local ROOM_H = 18
local WALL = 2
local DOOR_W = 8
local DOOR_H = 11

type Palette = {
	floor: Color3,
	wall: Color3,
	trim: Color3,
	light: Color3,
	accent: Color3,
	floorMaterial: Enum.Material,
	wallMaterial: Enum.Material,
}

local SEER: Palette = {
	floor = Color3.fromRGB(78, 54, 36),
	wall = Color3.fromRGB(66, 55, 48),
	trim = Color3.fromRGB(112, 78, 48),
	light = Color3.fromRGB(255, 168, 92),
	accent = Color3.fromRGB(232, 176, 74),
	floorMaterial = Enum.Material.WoodPlanks,
	wallMaterial = Enum.Material.Brick,
}

local TINKERER: Palette = {
	floor = Color3.fromRGB(40, 48, 54),
	wall = Color3.fromRGB(34, 44, 50),
	trim = Color3.fromRGB(150, 96, 60),
	light = Color3.fromRGB(90, 220, 235),
	accent = Color3.fromRGB(64, 212, 224),
	floorMaterial = Enum.Material.DiamondPlate,
	wallMaterial = Enum.Material.Concrete,
}

local DARK_WOOD = Color3.fromRGB(52, 36, 26)
local IRON = Color3.fromRGB(70, 72, 78)
local PAPER = Color3.fromRGB(226, 212, 178)

type SlotData = {
	model: Model,
	doorParts: { BasePart },
	doorClosed: { [BasePart]: CFrame },
}

local ChamberService = {}
ChamberService.__index = ChamberService

export type ChamberService = typeof(setmetatable(
	{} :: {
		root: Folder,
		chambers: Folder,
		slots: { [number]: SlotData },
	},
	ChamberService
))

--------------------------------------------------------------------------------
-- Building helpers
--------------------------------------------------------------------------------

local function newPart(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	if shape then
		part.Shape = shape
	end
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function addLight(part: BasePart, color: Color3, range: number, brightness: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = true
	light.Parent = part
end

-- Vertical cylinder (Roblox cylinders run along the X axis).
local function pillar(
	parent: Instance,
	name: string,
	base: Vector3,
	height: number,
	diameter: number,
	color: Color3,
	material: Enum.Material
): Part
	local cframe = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	return newPart(
		parent,
		name,
		Vector3.new(height, diameter, diameter),
		cframe,
		color,
		material,
		Enum.PartType.Cylinder
	)
end

local function candle(parent: Instance, base: Vector3, palette: Palette)
	pillar(parent, "Candle", base, 1.2, 0.5, Color3.fromRGB(235, 225, 200), Enum.Material.SmoothPlastic)
	local flame = newPart(
		parent,
		"Flame",
		Vector3.new(0.35, 0.35, 0.35),
		CFrame.new(base + Vector3.new(0, 1.45, 0)),
		palette.light,
		Enum.Material.Neon,
		Enum.PartType.Ball
	)
	flame.CanCollide = false
	addLight(flame, palette.light, 14, 1.3)
end

local function signGui(part: BasePart, face: Enum.NormalId, pixelsPerStud: number): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Sign"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud
	gui.LightInfluence = 0
	gui.Parent = part
	return gui
end

local function signLabel(
	parent: Instance,
	text: string,
	color: Color3,
	font: Enum.Font,
	position: UDim2,
	size: UDim2
): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Text = text
	label.RichText = true
	label.TextScaled = true
	label.Font = font
	label.TextColor3 = color
	label.Parent = parent
	return label
end

--------------------------------------------------------------------------------
-- Rooms
--------------------------------------------------------------------------------

-- Floor, ceiling, back/front wall and the outer side wall of one room.
local function buildShell(model: Model, center: Vector3, side: number, palette: Palette)
	newPart(
		model,
		"Floor",
		Vector3.new(ROOM_W, 1, ROOM_D),
		CFrame.new(center.X, -0.5, center.Z),
		palette.floor,
		palette.floorMaterial
	)
	newPart(
		model,
		"Ceiling",
		Vector3.new(ROOM_W + 2 * WALL, 1, ROOM_D + 2 * WALL),
		CFrame.new(center.X, ROOM_H + 0.5, center.Z),
		palette.wall,
		palette.wallMaterial
	)
	for _, sign in { -1, 1 } do
		newPart(
			model,
			if sign < 0 then "BackWall" else "FrontWall",
			Vector3.new(ROOM_W + 2 * WALL, ROOM_H + 1, WALL),
			CFrame.new(center.X, ROOM_H / 2, center.Z + sign * (ROOM_D / 2 + WALL / 2)),
			palette.wall,
			palette.wallMaterial
		)
	end
	newPart(
		model,
		"OuterWall",
		Vector3.new(WALL, ROOM_H + 1, ROOM_D),
		CFrame.new(center.X + side * (ROOM_W / 2 + WALL / 2), ROOM_H / 2, center.Z),
		palette.wall,
		palette.wallMaterial
	)
	-- hanging lantern
	local lantern = newPart(
		model,
		"Lantern",
		Vector3.new(1.4, 1.8, 1.4),
		CFrame.new(center.X, ROOM_H - 3, center.Z + 3),
		palette.light,
		Enum.Material.Neon
	)
	lantern.Transparency = 0.15
	lantern.CanCollide = false
	addLight(lantern, palette.light, 34, 1.1)
	newPart(
		model,
		"LanternChain",
		Vector3.new(0.15, 2.1, 0.15),
		CFrame.new(center.X, ROOM_H - 1.05, center.Z + 3),
		IRON,
		Enum.Material.Metal
	)
end

-- Big panel on the back wall; the client renders its role view onto it.
local function buildPanel(
	model: Model,
	center: Vector3,
	name: string,
	color: Color3,
	material: Enum.Material,
	trim: Color3,
	trimMaterial: Enum.Material
): Part
	local position = Vector3.new(center.X, 8.5, center.Z - ROOM_D / 2 + 0.3)
	local panel = newPart(
		model,
		name,
		Vector3.new(18, 9, 0.4),
		CFrame.lookAt(position, position + Vector3.new(0, 0, 1)),
		color,
		material
	)
	local z = position.Z + 0.25
	newPart(model, "PanelTrim", Vector3.new(19.2, 0.6, 0.6), CFrame.new(center.X, 13.3, z), trim, trimMaterial)
	newPart(model, "PanelTrim", Vector3.new(19.2, 0.6, 0.6), CFrame.new(center.X, 3.7, z), trim, trimMaterial)
	newPart(model, "PanelTrim", Vector3.new(0.6, 10.2, 0.6), CFrame.new(center.X - 9.3, 8.5, z), trim, trimMaterial)
	newPart(model, "PanelTrim", Vector3.new(0.6, 10.2, 0.6), CFrame.new(center.X + 9.3, 8.5, z), trim, trimMaterial)
	return panel
end

local function buildSeerRoom(model: Model, center: Vector3)
	local palette = SEER
	buildShell(model, center, -1, palette)
	buildPanel(
		model,
		center,
		World.CluePanel,
		Color3.fromRGB(46, 36, 28),
		Enum.Material.Wood,
		palette.trim,
		Enum.Material.Wood
	)

	local plaque = newPart(
		model,
		"Plaque",
		Vector3.new(8, 1.4, 0.3),
		CFrame.new(center.X, 14.6, center.Z - ROOM_D / 2 + 0.2),
		DARK_WOOD,
		Enum.Material.Wood
	)
	signLabel(
		signGui(plaque, Enum.NormalId.Back, 40),
		"HINWEISWAND",
		palette.accent,
		Enum.Font.Garamond,
		UDim2.fromScale(0, 0),
		UDim2.fromScale(1, 1)
	)

	-- scattered notes around the clue wall
	local notes = { { -11, 11 }, { -13.5, 6.5 }, { -15.5, 10 }, { 11.5, 10.5 }, { 13.5, 6 }, { 15.5, 11.5 } }
	for i, note in notes do
		local tilt = math.rad((i % 3 - 1) * 6)
		newPart(
			model,
			"Note",
			Vector3.new(1.5, 1.9, 0.08),
			CFrame.new(center.X + note[1], note[2], center.Z - ROOM_D / 2 + 0.05) * CFrame.Angles(0, 0, tilt),
			PAPER,
			Enum.Material.SmoothPlastic
		)
	end

	-- symbol table: shows the public glyph vocabulary as a legend
	local deskPosition = Vector3.new(center.X - 10, 0, center.Z + 3)
	newPart(
		model,
		"Desk",
		Vector3.new(7, 3, 3.5),
		CFrame.new(deskPosition + Vector3.new(0, 1.5, 0)),
		DARK_WOOD,
		Enum.Material.Wood
	)
	local tableTop = newPart(
		model,
		World.SymbolTable,
		Vector3.new(7.6, 0.4, 4),
		CFrame.new(deskPosition + Vector3.new(0, 3.2, 0)) * CFrame.Angles(math.rad(-12), 0, 0),
		palette.trim,
		Enum.Material.Wood
	)
	local legend = signGui(tableTop, Enum.NormalId.Top, 50)
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromScale(0.31, 0.45)
	grid.CellPadding = UDim2.fromScale(0.02, 0.05)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.VerticalAlignment = Enum.VerticalAlignment.Center
	grid.Parent = legend
	for _, glyph in Glyphs.list do
		local color = Color3.fromRGB(glyph.rgb[1], glyph.rgb[2], glyph.rgb[3])
		local label =
			signLabel(legend, `{glyph.char}  {glyph.name}`, color, Enum.Font.GothamBold, UDim2.new(), UDim2.new())
		label.BackgroundTransparency = 0.3
		label.BackgroundColor3 = Color3.fromRGB(30, 22, 16)
	end

	-- bookshelves along the outer wall
	local shelfX = center.X - ROOM_W / 2 + 1.2
	local bookColors = { Color3.fromRGB(120, 40, 40), Color3.fromRGB(50, 70, 110), Color3.fromRGB(70, 95, 55) }
	for _, z in { -9, 9 } do
		newPart(
			model,
			"Bookshelf",
			Vector3.new(2, 12, 7),
			CFrame.new(shelfX, 6, center.Z + z),
			DARK_WOOD,
			Enum.Material.Wood
		)
		for row, height in { 2.5, 6, 9.5 } do
			newPart(
				model,
				"Books",
				Vector3.new(1.4, 2.2, 6.2),
				CFrame.new(shelfX + 0.5, height, center.Z + z),
				bookColors[row],
				Enum.Material.Fabric
			)
		end
	end

	newPart(
		model,
		"Rug",
		Vector3.new(16, 0.1, 11),
		CFrame.new(center.X + 2, 0.05, center.Z + 5),
		Color3.fromRGB(105, 32, 36),
		Enum.Material.Fabric
	)
	newPart(
		model,
		"Chest",
		Vector3.new(3.4, 2.2, 2.2),
		CFrame.new(center.X + 15, 1.1, center.Z + 13),
		DARK_WOOD,
		Enum.Material.WoodPlanks
	)

	-- candle stands
	for _, offset in
		{ Vector3.new(-14, 0, -15), Vector3.new(14, 0, -15), Vector3.new(-6, 0, 15), Vector3.new(17, 0, 2) }
	do
		local base = center + offset
		pillar(model, "CandleStand", Vector3.new(base.X, 0, base.Z), 3, 0.8, IRON, Enum.Material.Metal)
		candle(model, Vector3.new(base.X, 3, base.Z), palette)
	end
end

local function buildTinkererRoom(model: Model, center: Vector3)
	local palette = TINKERER
	buildShell(model, center, 1, palette)
	buildPanel(
		model,
		center,
		World.ControlPanel,
		Color3.fromRGB(24, 32, 38),
		Enum.Material.Metal,
		palette.accent,
		Enum.Material.Neon
	)

	local plaque = newPart(
		model,
		"Plaque",
		Vector3.new(8, 1.4, 0.3),
		CFrame.new(center.X, 14.6, center.Z - ROOM_D / 2 + 0.2),
		IRON,
		Enum.Material.Metal
	)
	signLabel(
		signGui(plaque, Enum.NormalId.Back, 40),
		"STEUERWAND",
		palette.accent,
		Enum.Font.SciFi,
		UDim2.fromScale(0, 0),
		UDim2.fromScale(1, 1)
	)

	-- control console with decorative buttons
	local consolePosition = Vector3.new(center.X, 0, center.Z - 7)
	newPart(
		model,
		"ConsoleBase",
		Vector3.new(14, 3.4, 4),
		CFrame.new(consolePosition + Vector3.new(0, 1.7, 0)),
		Color3.fromRGB(55, 65, 72),
		Enum.Material.Metal
	)
	local topCFrame = CFrame.new(consolePosition + Vector3.new(0, 3.6, 0)) * CFrame.Angles(math.rad(-15), 0, 0)
	newPart(
		model,
		World.Console,
		Vector3.new(14.4, 0.4, 4.4),
		topCFrame,
		Color3.fromRGB(36, 44, 50),
		Enum.Material.Metal
	)
	local knobColors = { palette.accent, Color3.fromRGB(255, 150, 60), Color3.fromRGB(240, 80, 80) }
	for i = 1, 9 do
		local knob = newPart(
			model,
			"Knob",
			Vector3.new(0.6, 0.3, 0.6),
			topCFrame * CFrame.new(-6 + (i - 1) * 1.5, 0.3, (i % 2) * 1.2 - 0.6),
			knobColors[i % 3 + 1],
			Enum.Material.Neon
		)
		knob.CanCollide = false
	end

	-- check pedestal
	local pedestalBase = Vector3.new(center.X + 9, 0, center.Z + 3)
	pillar(model, "Pedestal", pedestalBase, 2.6, 2.6, Color3.fromRGB(55, 65, 72), Enum.Material.Metal)
	local button = pillar(
		model,
		World.CheckButton,
		pedestalBase + Vector3.new(0, 2.6, 0),
		0.4,
		2,
		palette.accent,
		Enum.Material.Neon
	)
	addLight(button, palette.light, 10, 1.5)

	-- pipes
	local copper = palette.trim
	local backZ = center.Z - ROOM_D / 2
	newPart(
		model,
		"Pipe",
		Vector3.new(ROOM_W, 1.1, 1.1),
		CFrame.new(center.X, 15.6, backZ + 1),
		copper,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	newPart(
		model,
		"Pipe",
		Vector3.new(ROOM_W, 0.7, 0.7),
		CFrame.new(center.X, 16.9, backZ + 2.2),
		copper,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	local outerX = center.X + ROOM_W / 2 - 1
	for _, z in { -12, 9 } do
		pillar(model, "Pipe", Vector3.new(outerX, 0, center.Z + z), ROOM_H, 0.9, copper, Enum.Material.Metal)
	end

	-- switch box on the outer wall
	newPart(
		model,
		"SwitchBox",
		Vector3.new(0.8, 4, 6),
		CFrame.new(center.X + ROOM_W / 2 - 0.4, 5, center.Z - 2),
		IRON,
		Enum.Material.Metal
	)
	for _, z in { -1.8, 0, 1.8 } do
		local lever = newPart(
			model,
			"Lever",
			Vector3.new(0.6, 1.2, 0.4),
			CFrame.new(center.X + ROOM_W / 2 - 1.1, 5, center.Z - 2 + z),
			palette.accent,
			Enum.Material.Neon
		)
		lever.CanCollide = false
	end

	-- neon strips and ceiling lamp
	for _, y in { 0.3, ROOM_H - 0.3 } do
		local strip = newPart(
			model,
			"Strip",
			Vector3.new(ROOM_W, 0.25, 0.25),
			CFrame.new(center.X, y, backZ + 0.2),
			palette.accent,
			Enum.Material.Neon
		)
		strip.CanCollide = false
	end
	local lamp = newPart(
		model,
		"CeilingLamp",
		Vector3.new(4, 0.4, 4),
		CFrame.new(center.X, ROOM_H - 0.2, center.Z),
		palette.light,
		Enum.Material.Neon
	)
	addLight(lamp, palette.light, 36, 1.2)

	newPart(
		model,
		"Crate",
		Vector3.new(3, 3, 3),
		CFrame.new(center.X - 15, 1.5, center.Z + 14),
		Color3.fromRGB(90, 66, 44),
		Enum.Material.WoodPlanks
	)
	newPart(
		model,
		"Crate",
		Vector3.new(2.4, 2.4, 2.4),
		CFrame.new(center.X - 15, 4.2, center.Z + 14) * CFrame.Angles(0, math.rad(20), 0),
		Color3.fromRGB(90, 66, 44),
		Enum.Material.WoodPlanks
	)
end

-- Middle wall with the shared, locked exit door.
local function buildDoorWall(model: Model, origin: Vector3): ({ BasePart }, { [BasePart]: CFrame })
	local segment = (ROOM_D - DOOR_W) / 2
	newPart(
		model,
		"Threshold",
		Vector3.new(WALL, 1, ROOM_D),
		CFrame.new(origin.X, -0.5, origin.Z),
		Color3.fromRGB(40, 38, 40),
		Enum.Material.Slate
	)
	for _, side in { -1, 1 } do
		local palette = if side < 0 then SEER else TINKERER
		local x = origin.X + side * WALL / 4
		for _, sign in { -1, 1 } do
			newPart(
				model,
				"MiddleWall",
				Vector3.new(WALL / 2, ROOM_H + 1, segment),
				CFrame.new(x, ROOM_H / 2, origin.Z + sign * (DOOR_W / 2 + segment / 2)),
				palette.wall,
				palette.wallMaterial
			)
		end
		newPart(
			model,
			"Lintel",
			Vector3.new(WALL / 2, ROOM_H + 1 - DOOR_H, DOOR_W),
			CFrame.new(x, DOOR_H + (ROOM_H + 1 - DOOR_H) / 2, origin.Z),
			palette.wall,
			palette.wallMaterial
		)
		local exitSign = newPart(
			model,
			"ExitSign",
			Vector3.new(0.2, 1.2, 4),
			CFrame.new(origin.X + side * (WALL / 2 + 0.1), DOOR_H + 1.2, origin.Z),
			DARK_WOOD,
			Enum.Material.Wood
		)
		signLabel(
			signGui(exitSign, if side < 0 then Enum.NormalId.Left else Enum.NormalId.Right, 40),
			"AUSGANG",
			palette.accent,
			Enum.Font.Garamond,
			UDim2.fromScale(0, 0),
			UDim2.fromScale(1, 1)
		)
	end

	local parts: { BasePart } = {}
	local door = newPart(
		model,
		"Door",
		Vector3.new(0.8, DOOR_H, DOOR_W),
		CFrame.new(origin.X, DOOR_H / 2, origin.Z),
		DARK_WOOD,
		Enum.Material.WoodPlanks
	)
	table.insert(parts, door)
	for _, side in { -1, 1 } do
		local palette = if side < 0 then SEER else TINKERER
		local x = origin.X + side * 0.5
		local lock = newPart(
			model,
			"Lock",
			Vector3.new(0.25, 1.4, 1.1),
			CFrame.new(x, DOOR_H / 2, origin.Z),
			palette.accent,
			Enum.Material.Neon
		)
		table.insert(parts, lock)
		for _, angle in { 40, -40 } do
			local chain = newPart(
				model,
				"Chain",
				Vector3.new(0.2, 0.3, DOOR_W * 1.15),
				CFrame.new(x, DOOR_H / 2, origin.Z) * CFrame.Angles(math.rad(angle), 0, 0),
				IRON,
				Enum.Material.Metal
			)
			table.insert(parts, chain)
		end
	end

	local closed: { [BasePart]: CFrame } = {}
	for _, part in parts do
		part.CanCollide = part == door
		closed[part] = part.CFrame
	end
	return parts, closed
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

function ChamberService.new(): ChamberService
	local root = Instance.new("Folder")
	root.Name = World.Root
	root.Parent = Workspace
	local chambers = Instance.new("Folder")
	chambers.Name = World.Chambers
	chambers.Parent = root
	return setmetatable({ root = root, chambers = chambers, slots = {} }, ChamberService)
end

function ChamberService.setupLighting(_self: ChamberService)
	Lighting.ClockTime = 0
	Lighting.Brightness = 1
	Lighting.Ambient = Color3.fromRGB(30, 30, 40)
	Lighting.OutdoorAmbient = Color3.fromRGB(44, 48, 66)
	Lighting.EnvironmentDiffuseScale = 0.3
	Lighting.EnvironmentSpecularScale = 0.3
	Lighting.FogColor = Color3.fromRGB(12, 16, 26)
	Lighting.FogStart = 80
	Lighting.FogEnd = 500
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 24
	bloom.Threshold = 1.4
	bloom.Parent = Lighting
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Contrast = 0.1
	grade.Saturation = 0.05
	grade.Parent = Lighting
end

function ChamberService.buildLobby(self: ChamberService)
	local lobby = Instance.new("Model")
	lobby.Name = World.Lobby
	local stone = Color3.fromRGB(38, 42, 52)
	newPart(lobby, "Ground", Vector3.new(90, 1, 90), CFrame.new(0, -0.5, 0), stone, Enum.Material.Slate)
	for _, edge in { { 0, -45, 90, 1 }, { 0, 45, 90, 1 }, { -45, 0, 1, 90 }, { 45, 0, 1, 90 } } do
		newPart(
			lobby,
			"Rim",
			Vector3.new(edge[3], 3, edge[4]),
			CFrame.new(edge[1], 1.5, edge[2]),
			Color3.fromRGB(30, 33, 42),
			Enum.Material.Slate
		)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(0, 0.5, 14)
	spawn.Color = Color3.fromRGB(64, 200, 190)
	spawn.Material = Enum.Material.Slate
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = lobby

	local sign = newPart(
		lobby,
		"TitleSign",
		Vector3.new(34, 10, 1),
		CFrame.new(0, 8, -24),
		Color3.fromRGB(22, 26, 34),
		Enum.Material.Slate
	)
	local signFace = signGui(sign, Enum.NormalId.Back, 30)
	signLabel(
		signFace,
		'Whisper<font color="#40D4C8">Latch</font>',
		Color3.fromRGB(240, 236, 225),
		Enum.Font.Garamond,
		UDim2.fromScale(0.05, 0.08),
		UDim2.fromScale(0.9, 0.55)
	)
	signLabel(
		signFace,
		"2 Spieler · 2 Räume · 1 gemeinsame Lösung",
		Color3.fromRGB(64, 212, 224),
		Enum.Font.Garamond,
		UDim2.fromScale(0.1, 0.66),
		UDim2.fromScale(0.8, 0.22)
	)

	-- two archways hinting at the two roles
	for _, side in { -1, 1 } do
		local palette = if side < 0 then SEER else TINKERER
		local x = side * 22
		for _, dz in { -4, 4 } do
			newPart(
				lobby,
				"ArchPillar",
				Vector3.new(1.5, 10, 1.5),
				CFrame.new(x, 5, -10 + dz),
				stone,
				Enum.Material.Slate
			)
		end
		local lintel = newPart(
			lobby,
			"ArchLintel",
			Vector3.new(1.6, 1, 9.5),
			CFrame.new(x, 10.5, -10),
			palette.accent,
			Enum.Material.Neon
		)
		addLight(lintel, palette.light, 20, 1)
		local label =
			newPart(lobby, "ArchLabel", Vector3.new(0.3, 1.6, 7), CFrame.new(x, 12, -10), stone, Enum.Material.Slate)
		signLabel(
			signGui(label, if side < 0 then Enum.NormalId.Right else Enum.NormalId.Left, 40),
			if side < 0 then "SEHER" else "TÜFTLER",
			palette.accent,
			Enum.Font.Garamond,
			UDim2.fromScale(0, 0),
			UDim2.fromScale(1, 1)
		)
	end

	for _, corner in
		{ Vector3.new(-30, 0, -30), Vector3.new(30, 0, -30), Vector3.new(-30, 0, 30), Vector3.new(30, 0, 30) }
	do
		pillar(lobby, "LampPost", corner, 7, 0.6, Color3.fromRGB(28, 30, 36), Enum.Material.Metal)
		local glow = newPart(
			lobby,
			"LampGlow",
			Vector3.new(1.2, 1.2, 1.2),
			CFrame.new(corner + Vector3.new(0, 7.6, 0)),
			SEER.light,
			Enum.Material.Neon
		)
		addLight(glow, SEER.light, 26, 1.2)
	end

	lobby.Parent = self.root
end

function ChamberService.slotOrigin(slot: number): Vector3
	return SLOT_ORIGIN + Vector3.new((slot - 1) * SLOT_SPACING, 0, 0)
end

function ChamberService.roomCenter(slot: number, role: Types.Role): Vector3
	local side = if role == "Seer" then -1 else 1
	return ChamberService.slotOrigin(slot) + Vector3.new(side * (WALL / 2 + ROOM_W / 2), 0, 0)
end

-- Builds the chamber pair for a slot on first use.
function ChamberService.ensureSlot(self: ChamberService, slot: number): SlotData
	local existing = self.slots[slot]
	if existing then
		return existing
	end
	local model = Instance.new("Model")
	model.Name = World.slotName(slot)

	local seerRoom = Instance.new("Model")
	seerRoom.Name = World.SeerRoom
	buildSeerRoom(seerRoom, ChamberService.roomCenter(slot, "Seer"))
	seerRoom.Parent = model

	local tinkererRoom = Instance.new("Model")
	tinkererRoom.Name = World.TinkererRoom
	buildTinkererRoom(tinkererRoom, ChamberService.roomCenter(slot, "Tinkerer"))
	tinkererRoom.Parent = model

	local doorParts, doorClosed = buildDoorWall(model, ChamberService.slotOrigin(slot))
	model.Parent = self.chambers

	local data: SlotData = { model = model, doorParts = doorParts, doorClosed = doorClosed }
	self.slots[slot] = data
	return data
end

function ChamberService.spawnCFrame(_self: ChamberService, slot: number, role: Types.Role): CFrame
	local center = ChamberService.roomCenter(slot, role)
	local position = Vector3.new(center.X, 3.5, center.Z + 10)
	return CFrame.lookAt(position, Vector3.new(center.X, 3.5, center.Z - ROOM_D / 2))
end

function ChamberService.lobbyCFrame(_self: ChamberService): CFrame
	return CFrame.lookAt(Vector3.new(0, 3.5, 10), Vector3.new(0, 3.5, -20))
end

function ChamberService.teleport(_self: ChamberService, player: Player, target: CFrame)
	local character = player.Character
	if character and character.PrimaryPart then
		character:PivotTo(target)
	end
end

function ChamberService.setDoorOpen(self: ChamberService, slot: number, open: boolean)
	local data = self.slots[slot]
	if not data then
		return
	end
	local info = TweenInfo.new(if open then 1.6 else 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, part in data.doorParts do
		local closed = data.doorClosed[part]
		local goal = if open then closed + Vector3.new(0, DOOR_H + 1, 0) else closed
		TweenService:Create(part, info, { CFrame = goal }):Play()
		if part.Name == "Door" then
			part.CanCollide = not open
		end
	end
end

return ChamberService
