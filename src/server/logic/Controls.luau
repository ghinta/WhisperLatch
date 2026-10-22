--!strict
-- Constructors and accessors for the generic puzzle controls.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)
local PuzzleTypes = require(script.Parent.PuzzleTypes)

type Control = PuzzleTypes.Control

local Controls = {}

function Controls.dial(
	id: string,
	label: string,
	display: Types.ControlDisplay,
	options: { string },
	value: number
): Control
	assert(value >= 1 and value <= #options, "Controls.dial: value out of range")
	return {
		id = id,
		kind = "dial",
		display = display,
		label = label,
		options = table.clone(options),
		value = value,
	}
end

function Controls.toggle(id: string, label: string, glyph: string?): Control
	return {
		id = id,
		kind = "toggle",
		display = "switch",
		label = label,
		glyph = glyph,
		value = 0,
	}
end

function Controls.button(id: string, label: string, glyph: string): Control
	return {
		id = id,
		kind = "button",
		display = "button",
		label = label,
		glyph = glyph,
		value = 0,
	}
end

-- Currently selected option id of a dial.
function Controls.option(control: Control): string
	local options = control.options
	assert(options, "Controls.option: not a dial")
	return options[control.value]
end

function Controls.indexOf(options: { string }, option: string): number
	local index = table.find(options, option)
	assert(index, "Controls.indexOf: unknown option " .. option)
	return index
end

function Controls.newState(stageCount: number?): PuzzleTypes.PuzzleState
	return {
		input = {},
		stage = 1,
		stageCount = stageCount or 1,
	}
end

return Controls
