--!strict
-- Fixed set of preset pings. Players only ever send a ping id, never free text,
-- so the custom communication channel needs no moderation.

local Glyphs = require(script.Parent.Glyphs)

export type PingCategory = "status" | "glyph" | "number" | "arrow"

export type Ping = {
	id: string,
	category: PingCategory,
	label: string,
	glyph: string?,
}

local categories: { PingCategory } = { "status", "glyph", "number", "arrow" }

local list: { Ping } = {
	{ id = "look", category = "status", label = "Schau auf den Hinweis" },
	{ id = "next", category = "status", label = "Weiter" },
	{ id = "repeat", category = "status", label = "Nochmal bitte" },
	{ id = "ready", category = "status", label = "Bereit" },
	{ id = "help", category = "status", label = "Brauche einen Tipp" },
	{ id = "yes", category = "status", label = "Ja" },
	{ id = "no", category = "status", label = "Nein" },
	{ id = "on", category = "status", label = "AN" },
	{ id = "off", category = "status", label = "AUS" },
	{ id = "empty", category = "status", label = "Leer" },
	{ id = "check", category = "status", label = "Jetzt prüfen!" },
	{ id = "a_cw", category = "arrow", label = "↻ Rechtsdrehung" },
	{ id = "a_ccw", category = "arrow", label = "↺ Linksdrehung" },
	{ id = "a_180", category = "arrow", label = "⟲ Halbe Drehung" },
	{ id = "a_flip_h", category = "arrow", label = "↔ Links/Rechts spiegeln" },
	{ id = "a_flip_v", category = "arrow", label = "↕ Oben/Unten spiegeln" },
	{ id = "a_swap", category = "arrow", label = "⇄ Tauschen" },
}

for _, glyph in Glyphs.list do
	table.insert(list, { id = "g_" .. glyph.id, category = "glyph", label = glyph.name, glyph = glyph.id })
end

for n = 1, 12 do
	table.insert(list, { id = "n_" .. n, category = "number", label = tostring(n) })
end

local byId: { [string]: Ping } = {}
for _, ping in list do
	byId[ping.id] = ping
end

return table.freeze({
	categories = categories,
	list = list,
	byId = byId,
})
