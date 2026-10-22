--!strict
-- Approved public glyph vocabulary. Every glyph carries a name and a color,
-- so no clue ever depends on shape or color alone.

export type Glyph = {
	id: string,
	char: string,
	name: string,
	rgb: { number },
}

local list: { Glyph } = {
	{ id = "moon", char = "☾", name = "Mond", rgb = { 140, 180, 255 } },
	{ id = "star", char = "✦", name = "Stern", rgb = { 255, 228, 140 } },
	{ id = "sun", char = "☀", name = "Sonne", rgb = { 255, 160, 60 } },
	{ id = "ring", char = "◎", name = "Ring", rgb = { 200, 140, 255 } },
	{ id = "triangle", char = "▲", name = "Dreieck", rgb = { 110, 225, 150 } },
	{ id = "diamond", char = "◆", name = "Raute", rgb = { 255, 110, 120 } },
}

local byId: { [string]: Glyph } = {}
local ids: { string } = {}
for _, glyph in list do
	byId[glyph.id] = glyph
	table.insert(ids, glyph.id)
end

return table.freeze({
	list = list,
	byId = byId,
	ids = ids,
})
