--!strict
-- Local-only presentation inside the player's own chamber:
--   * renders the role view onto the panel on the back wall (SurfaceGui in
--     PlayerGui, adorned to the part - other clients never see it)
--   * adds role-specific proximity prompts
-- The Seer's clue is therefore never part of the replicated world.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Types = require(ReplicatedStorage.Shared.Types)
local World = require(ReplicatedStorage.Shared.World)
local CluePanel = require(script.Parent.Parent.ui.CluePanel)
local ControlPanel = require(script.Parent.Parent.ui.ControlPanel)
local Strings = require(script.Parent.Parent.Strings)
local Theme = require(script.Parent.Parent.ui.Theme)

local PANEL_PIXELS_PER_STUD = 34
local LOOKUP_TIMEOUT = 10

export type Handlers = {
	sendAction: (actionType: string, controlId: string?, value: number?) -> (),
	openPanel: () -> (),
	showLegend: () -> (),
}

local ChamberDecor = {}

local handlers: Handlers? = nil
local latestView: Types.SessionView? = nil
local placementKey: string? = nil
local surface: SurfaceGui? = nil
local canvas: Frame? = nil
local prompts: { ProximityPrompt } = {}
local checkPrompt: ProximityPrompt? = nil

local function clearPlacement()
	if surface then
		surface:Destroy()
	end
	surface = nil
	canvas = nil
	checkPrompt = nil
	for _, prompt in prompts do
		prompt:Destroy()
	end
	table.clear(prompts)
	placementKey = nil
end

local function findRoom(slot: number, role: Types.Role): Instance?
	local root = Workspace:WaitForChild(World.Root, LOOKUP_TIMEOUT)
	local chambers = root and root:WaitForChild(World.Chambers, LOOKUP_TIMEOUT)
	local slotModel = chambers and chambers:WaitForChild(World.slotName(slot), LOOKUP_TIMEOUT)
	return slotModel
		and slotModel:WaitForChild(if role == "Seer" then World.SeerRoom else World.TinkererRoom, LOOKUP_TIMEOUT)
end

local function addPrompt(
	part: Instance?,
	actionText: string,
	objectText: string,
	onTriggered: () -> ()
): ProximityPrompt?
	if not part then
		return nil
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(onTriggered)
	prompt.Parent = part
	table.insert(prompts, prompt)
	return prompt
end

local function render()
	local view = latestView
	local target = canvas
	local current = handlers
	if not view or not target or not current then
		return
	end
	if view.role == "Seer" then
		CluePanel.render(target, view)
	else
		ControlPanel.render(target, view, current.sendAction)
	end
	if checkPrompt and view.submitLabel then
		checkPrompt.ActionText = view.submitLabel
	end
end

local function place(view: Types.SessionView, key: string)
	local room = findRoom(view.slot, view.role)
	if placementKey ~= key or not room then
		return -- a newer view arrived while waiting, or the room never appeared
	end
	local current = handlers :: Handlers
	local panelName = if view.role == "Seer" then World.CluePanel else World.ControlPanel
	local panel = room:WaitForChild(panelName, LOOKUP_TIMEOUT)
	if placementKey ~= key or not panel then
		return
	end

	local accent = Theme.accent(view.role)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "WhisperLatchPanel"
	gui.Adornee = panel :: BasePart
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PANEL_PIXELS_PER_STUD
	gui.LightInfluence = 0.2
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ResetOnSpawn = false
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Theme.Colors.ink
	frame.BackgroundTransparency = 0.2
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = gui
	Theme.stroke(frame, accent, 3, 0.2)
	Theme.list(frame, Enum.FillDirection.Vertical, 0, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	surface = gui
	canvas = frame

	if view.role == "Seer" then
		addPrompt(panel, "Hinweis lesen", Strings.panelTitle.Seer, current.openPanel)
		addPrompt(
			room:FindFirstChild(World.SymbolTable),
			"Symboltafel ansehen",
			Strings.hud.legendTitle,
			current.showLegend
		)
	else
		addPrompt(
			room:FindFirstChild(World.Console),
			"Steuerpult bedienen",
			Strings.panelTitle.Tinkerer,
			current.openPanel
		)
		checkPrompt = addPrompt(
			room:FindFirstChild(World.CheckButton),
			view.submitLabel or "Prüfen",
			"Mechanismus",
			function()
				current.sendAction("submit")
			end
		)
	end
	render()
end

function ChamberDecor.init(newHandlers: Handlers)
	handlers = newHandlers
end

-- Call with the latest view, or nil when the player is back in the lobby.
function ChamberDecor.update(view: Types.SessionView?)
	latestView = view
	if not view then
		clearPlacement()
		return
	end
	local key = `{view.sessionId}:{view.slot}:{view.role}`
	if key ~= placementKey then
		clearPlacement()
		placementKey = key
		task.spawn(place, view, key)
		return
	end
	render()
end

return ChamberDecor
