--!strict
-- Names of world instances the client looks up. The world itself is built
-- by the server (ChamberService) and never contains puzzle data.

return table.freeze({
	Root = "WhisperLatch",
	Chambers = "Chambers",
	Lobby = "Lobby",
	slotName = function(slot: number): string
		return "Slot" .. slot
	end,
	-- room models inside a slot, named by the role that plays there
	SeerRoom = "Seer",
	TinkererRoom = "Tinkerer",
	-- panels that clients render onto locally
	CluePanel = "CluePanel",
	ControlPanel = "ControlPanel",
	SymbolTable = "SymbolTable",
	Console = "Console",
	CheckButton = "CheckButton",
})
