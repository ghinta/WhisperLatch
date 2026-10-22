--!strict
-- Small deterministic PRNG (32-bit LCG) so puzzle generation is pure,
-- reproducible in tests and independent of Roblox's Random datatype.

local MODULUS = 4294967296
local MULTIPLIER = 1664525
local INCREMENT = 1013904223

local Rng = {}
Rng.__index = Rng

export type Rng = typeof(setmetatable({} :: { state: number }, Rng))

function Rng.new(seed: number): Rng
	return setmetatable({ state = math.floor(math.abs(seed)) % MODULUS }, Rng)
end

-- Uniform float in [0, 1).
function Rng.float(self: Rng): number
	self.state = (MULTIPLIER * self.state + INCREMENT) % MODULUS
	return self.state / MODULUS
end

-- Uniform integer in [min, max].
function Rng.integer(self: Rng, min: number, max: number): number
	assert(max >= min, "Rng.integer: empty range")
	return min + math.floor(self:float() * (max - min + 1))
end

function Rng.pick<T>(self: Rng, list: { T }): T
	assert(#list > 0, "Rng.pick: empty list")
	return list[self:integer(1, #list)]
end

-- Returns a shuffled copy; the input is not modified.
function Rng.shuffle<T>(self: Rng, list: { T }): { T }
	local copy = table.clone(list)
	for i = #copy, 2, -1 do
		local j = self:integer(1, i)
		copy[i], copy[j] = copy[j], copy[i]
	end
	return copy
end

-- Returns `count` distinct entries in random order.
function Rng.sample<T>(self: Rng, list: { T }, count: number): { T }
	assert(count <= #list, "Rng.sample: not enough entries")
	local shuffled = self:shuffle(list)
	return table.move(shuffled, 1, count, 1, {})
end

return Rng
