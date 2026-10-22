--!strict
-- Ordered room catalog. Server-only: never map this folder into a
-- replicated container.

local PuzzleTypes = require(script.Parent.logic.PuzzleTypes)

local catalog: { PuzzleTypes.RoomDefinition } = {
	require(script.GlyphGate),
	require(script.CircuitSplit),
	require(script.MirrorClocks),
	require(script.PatternRelay).definition,
	require(script.DualReactor),
}

return catalog
