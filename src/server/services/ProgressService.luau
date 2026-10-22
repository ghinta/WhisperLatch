--!strict
-- Records per-player progress after a run. Persistence goes through an
-- injected store (DataStore adapter in production, memory in tests); the
-- update function validates whatever it reads before merging.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)

export type Record = {
	runs: number,
	finishedRuns: number,
	roomsCleared: number,
	hintsUsed: number,
	bestSeconds: number?,
}

export type Store = {
	update: (key: string, transform: (old: any) -> Record) -> (),
}

local ProgressService = {}
ProgressService.__index = ProgressService

export type ProgressService = typeof(setmetatable({} :: { store: Store? }, ProgressService))

local function isCount(value: any): boolean
	return type(value) == "number" and value == value and value >= 0 and value % 1 == 0
end

local function sanitize(old: any): Record
	local record: Record = { runs = 0, finishedRuns = 0, roomsCleared = 0, hintsUsed = 0 }
	if type(old) ~= "table" then
		return record
	end
	for _, key in { "runs", "finishedRuns", "roomsCleared", "hintsUsed" } do
		if isCount(old[key]) then
			(record :: any)[key] = old[key]
		end
	end
	if type(old.bestSeconds) == "number" and old.bestSeconds == old.bestSeconds and old.bestSeconds > 0 then
		record.bestSeconds = old.bestSeconds
	end
	return record
end

function ProgressService.merge(old: any, summary: Types.RunSummary): Record
	local record = sanitize(old)
	record.runs += 1
	record.roomsCleared += summary.roomsCleared
	record.hintsUsed += summary.hintsUsed
	if summary.reason == "finished" then
		record.finishedRuns += 1
		local seconds = math.floor(summary.seconds)
		if record.bestSeconds == nil or seconds < (record.bestSeconds :: number) then
			record.bestSeconds = seconds
		end
	end
	return record
end

function ProgressService.new(store: Store?): ProgressService
	return setmetatable({ store = store }, ProgressService)
end

function ProgressService.recordRun(self: ProgressService, userIds: { number }, summary: Types.RunSummary)
	local store = self.store
	if not store or summary.roomsCleared == 0 then
		return
	end
	for _, userId in userIds do
		store.update("user_" .. userId, function(old)
			return ProgressService.merge(old, summary)
		end)
	end
end

return ProgressService
