--!strict
-- Room 3 - Mirror Clocks
-- Seer sees three clocks in a mirror: order reversed, hands mirrored.
-- Tinkerer sets the three real clocks.

local Controls = require(script.Parent.Parent.logic.Controls)
local PuzzleTypes = require(script.Parent.Parent.logic.PuzzleTypes)

local CLOCK_COUNT = 3
-- 6 and 12 look identical in a mirror, so they are never targets
local HOURS = { 1, 2, 3, 4, 5, 7, 8, 9, 10, 11 }
local HOUR_OPTIONS = {}
for hour = 1, 12 do
	table.insert(HOUR_OPTIONS, tostring(hour))
end

type Secret = { target: { number }, shown: { number } }

local function mirrorHour(hour: number): number
	local mirrored = (12 - hour) % 12
	return if mirrored == 0 then 12 else mirrored
end

local MirrorClocks: PuzzleTypes.RoomDefinition = {
	id = "mirror_clocks",
	title = "Spiegeluhren",
	seerTask = "Du siehst die Uhren nur im Spiegel. Finde die echten Zeiten heraus.",
	tinkererTask = "Stelle die drei echten Uhren auf die Zeiten, die dein Partner herausfindet.",
	submitLabel = "Lösung prüfen",
	inputMax = 0,
	hints = {
		"Ein Spiegel vertauscht links und rechts.",
		"Die linke Uhr im Spiegel ist die rechte echte Uhr (Uhr 3).",
		"Gespiegelt laufen Zeiger rückwärts: echte Zeit = 12 minus Spiegelzeit (2 → 10).",
	},
	create = function(rng)
		local target = rng:sample(HOURS, CLOCK_COUNT)
		local shown = {}
		for i = 1, CLOCK_COUNT do
			shown[i] = mirrorHour(target[CLOCK_COUNT + 1 - i])
		end
		local controls = {}
		for i = 1, CLOCK_COUNT do
			table.insert(controls, Controls.dial("clock" .. i, "Uhr " .. i, "clock", HOUR_OPTIONS, 12))
		end
		local secret: Secret = { target = target, shown = shown }
		return {
			roomId = "mirror_clocks",
			layout = "row",
			controls = controls,
			state = Controls.newState(),
			secret = secret,
		}
	end,
	seerClue = function(puzzle)
		local secret: Secret = puzzle.secret
		return {
			heading = "Spiegelbild",
			clocks = table.clone(secret.shown),
			lines = {
				{ { text = "Die echten Uhren hängen beim Tüftler. Du siehst sie nur im Spiegel." } },
			},
		}
	end,
	evaluate = function(puzzle)
		local secret: Secret = puzzle.secret
		for i, control in puzzle.controls do
			if control.value ~= secret.target[i] then
				return "wrong"
			end
		end
		return "solved"
	end,
}

return MirrorClocks
