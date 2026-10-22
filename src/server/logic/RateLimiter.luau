--!strict
-- Token bucket per key (user id). Time is injected to keep it testable.

local RateLimiter = {}
RateLimiter.__index = RateLimiter

type Bucket = { tokens: number, at: number }

export type RateLimiter = typeof(setmetatable(
	{} :: {
		now: () -> number,
		capacity: number,
		refillPerSecond: number,
		buckets: { [number]: Bucket },
	},
	RateLimiter
))

function RateLimiter.new(now: () -> number, capacity: number, refillPerSecond: number): RateLimiter
	return setmetatable({
		now = now,
		capacity = capacity,
		refillPerSecond = refillPerSecond,
		buckets = {},
	}, RateLimiter)
end

function RateLimiter.allow(self: RateLimiter, key: number): boolean
	local t = self.now()
	local bucket = self.buckets[key]
	if not bucket then
		bucket = { tokens = self.capacity, at = t }
		self.buckets[key] = bucket
	end
	bucket.tokens = math.min(self.capacity, bucket.tokens + (t - bucket.at) * self.refillPerSecond)
	bucket.at = t
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

function RateLimiter.forget(self: RateLimiter, key: number)
	self.buckets[key] = nil
end

return RateLimiter
