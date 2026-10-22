--!strict
-- FIFO lobby queue for players on the same server.

local PairingService = {}
PairingService.__index = PairingService

export type PairingService = typeof(setmetatable({} :: { queue: { number } }, PairingService))

function PairingService.new(): PairingService
	return setmetatable({ queue = {} }, PairingService)
end

-- Idempotent: a user is never queued twice.
function PairingService.enqueue(self: PairingService, userId: number): boolean
	if table.find(self.queue, userId) then
		return false
	end
	table.insert(self.queue, userId)
	return true
end

function PairingService.cancel(self: PairingService, userId: number): boolean
	local index = table.find(self.queue, userId)
	if not index then
		return false
	end
	table.remove(self.queue, index)
	return true
end

function PairingService.isQueued(self: PairingService, userId: number): boolean
	return table.find(self.queue, userId) ~= nil
end

function PairingService.size(self: PairingService): number
	return #self.queue
end

-- Removes and returns the two longest-waiting users.
function PairingService.popPair(self: PairingService): (number?, number?)
	if #self.queue < 2 then
		return nil, nil
	end
	local first = table.remove(self.queue, 1)
	local second = table.remove(self.queue, 1)
	return first, second
end

return PairingService
