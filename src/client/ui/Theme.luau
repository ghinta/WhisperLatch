--!strict
-- Colors, fonts and small instance builders for the UI.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Types = require(ReplicatedStorage.Shared.Types)

local Theme = {}

Theme.Colors = table.freeze({
	ink = Color3.fromRGB(12, 16, 22),
	inkSoft = Color3.fromRGB(24, 30, 38),
	text = Color3.fromRGB(236, 232, 222),
	muted = Color3.fromRGB(150, 158, 168),
	seer = Color3.fromRGB(232, 176, 74),
	seerSoft = Color3.fromRGB(58, 42, 22),
	tinkerer = Color3.fromRGB(64, 212, 224),
	tinkererSoft = Color3.fromRGB(14, 50, 56),
	latch = Color3.fromRGB(64, 212, 200),
	good = Color3.fromRGB(110, 225, 150),
	bad = Color3.fromRGB(255, 110, 120),
	parchment = Color3.fromRGB(235, 225, 200),
})

Theme.Fonts = table.freeze({
	title = Enum.Font.Garamond,
	body = Enum.Font.GothamMedium,
	bold = Enum.Font.GothamBold,
	hand = Enum.Font.PatrickHand,
	glyph = Enum.Font.GothamBold,
})

function Theme.accent(role: Types.Role?): Color3
	if role == "Seer" then
		return Theme.Colors.seer
	elseif role == "Tinkerer" then
		return Theme.Colors.tinkerer
	end
	return Theme.Colors.latch
end

function Theme.accentSoft(role: Types.Role?): Color3
	if role == "Seer" then
		return Theme.Colors.seerSoft
	end
	return Theme.Colors.tinkererSoft
end

-- Creates an instance, assigns properties (Parent last) and parents children.
function Theme.create(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = (Instance.new :: any)(className)
	local parent = nil
	for key, value in props or ({} :: { [string]: any }) do
		if key == "Parent" then
			parent = value
		else
			instance[key] = value
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function Theme.corner(parent: Instance, radius: UDim?)
	Theme.create("UICorner", { CornerRadius = radius or UDim.new(0, 8), Parent = parent })
end

function Theme.stroke(parent: Instance, color: Color3, thickness: number?, transparency: number?)
	Theme.create("UIStroke", {
		Color = color,
		Thickness = thickness or 1.5,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function Theme.padding(parent: Instance, pixels: number)
	local pad = UDim.new(0, pixels)
	Theme.create("UIPadding", {
		PaddingLeft = pad,
		PaddingRight = pad,
		PaddingTop = pad,
		PaddingBottom = pad,
		Parent = parent,
	})
end

function Theme.list(
	parent: Instance,
	direction: Enum.FillDirection,
	spacing: number,
	horizontal: Enum.HorizontalAlignment?,
	vertical: Enum.VerticalAlignment?
): UIListLayout
	return Theme.create("UIListLayout", {
		FillDirection = direction,
		Padding = UDim.new(0, spacing),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = horizontal or Enum.HorizontalAlignment.Left,
		VerticalAlignment = vertical or Enum.VerticalAlignment.Top,
		Parent = parent,
	})
end

-- Transparent auto-sizing container with a list layout.
function Theme.stack(
	parent: Instance,
	direction: Enum.FillDirection,
	spacing: number,
	order: number?,
	horizontal: Enum.HorizontalAlignment?
): Frame
	local frame = Theme.create("Frame", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		LayoutOrder = order or 0,
		Parent = parent,
	})
	Theme.list(frame, direction, spacing, horizontal, Enum.VerticalAlignment.Center)
	return frame
end

function Theme.label(parent: Instance, text: string, props: { [string]: any }?): TextLabel
	local label = Theme.create("TextLabel", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		Text = text,
		TextColor3 = Theme.Colors.text,
		TextSize = 16,
		Font = Theme.Fonts.body,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = parent,
	})
	for key, value in props or ({} :: { [string]: any }) do
		(label :: any)[key] = value
	end
	return label
end

-- Wrapped paragraph that fills the parent's width.
function Theme.paragraph(parent: Instance, text: string, props: { [string]: any }?): TextLabel
	local label = Theme.label(parent, text, props)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.Size = UDim2.fromScale(1, 0)
	label.TextWrapped = true
	return label
end

function Theme.button(
	parent: Instance,
	text: string,
	accent: Color3,
	onActivated: () -> (),
	props: { [string]: any }?
): TextButton
	local button = Theme.create("TextButton", {
		AutoButtonColor = true,
		BackgroundColor3 = Theme.Colors.inkSoft,
		Size = UDim2.fromOffset(0, 36),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = text,
		TextColor3 = accent,
		TextSize = 16,
		Font = Theme.Fonts.bold,
		Parent = parent,
	})
	Theme.corner(button)
	Theme.stroke(button, accent, 1.5, 0.2)
	Theme.create("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = button })
	for key, value in props or ({} :: { [string]: any }) do
		(button :: any)[key] = value
	end
	button.Activated:Connect(onActivated)
	return button
end

-- Rounded dark card with an accent stroke.
function Theme.card(parent: Instance, accent: Color3, props: { [string]: any }?): Frame
	local card = Theme.create("Frame", {
		BackgroundColor3 = Theme.Colors.ink,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromOffset(300, 0),
		Parent = parent,
	})
	Theme.corner(card, UDim.new(0, 10))
	Theme.stroke(card, accent, 1.5, 0.35)
	Theme.padding(card, 12)
	for key, value in props or ({} :: { [string]: any }) do
		(card :: any)[key] = value
	end
	return card
end

-- UI scale for small screens (phones): 1280x720 is the reference size.
local scales: { UIScale } = {}

local function viewportScale(): number
	local camera = Workspace.CurrentCamera
	if not camera then
		return 1
	end
	local size = camera.ViewportSize
	return math.clamp(math.min(size.X / 1280, size.Y / 720), 0.5, 1)
end

local function watchViewport()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			for _, scale in scales do
				scale.Scale = viewportScale()
			end
		end)
	end
end
watchViewport()

function Theme.autoScale(target: GuiObject)
	local scale = Theme.create("UIScale", { Scale = viewportScale(), Parent = target })
	table.insert(scales, scale)
end

function Theme.clear(container: Instance)
	for _, child in container:GetChildren() do
		if not child:IsA("UIBase") then
			child:Destroy()
		end
	end
end

return Theme
