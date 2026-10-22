--!nonstrict
-- Lune test runner.
--
-- Game code uses Roblox-style instance requires (`require(script.Parent.X)`);
-- lib/FakeTree mirrors the Rojo tree so the pure server modules run
-- unchanged outside Studio.
--
-- Usage: lune run scripts/test.luau [filter]

local fs = require("@lune/fs")
local process = require("@lune/process")
local stdio = require("@lune/stdio")
local FakeTree = require("./lib/FakeTree")

-- Rojo mapping (keep in sync with default.project.json)
local tree = FakeTree.new({
	mounts = {
		{ service = "ReplicatedStorage", name = "Shared", path = "src/shared" },
		{ service = "ServerScriptService", name = "Server", path = "src/server" },
		{ service = "TestService", name = "Tests", path = "tests" },
	},
})
local game = tree.game
local shimRequire = tree.require

--------------------------------------------------------------------------------
-- Minimal assertion API handed to every spec
--------------------------------------------------------------------------------

local function show(value: any): string
	if type(value) ~= "table" then
		return if type(value) == "string" then `"{value}"` else tostring(value)
	end
	local parts = {}
	for key, child in value do
		table.insert(parts, `{tostring(key)}={show(child)}`)
	end
	table.sort(parts)
	return "{" .. table.concat(parts, ", ") .. "}"
end

local function deepEqual(a: any, b: any): boolean
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end
	for key, value in a do
		if not deepEqual(value, b[key]) then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end
	return true
end

type Case = { name: string, fn: () -> () }
local cases: { Case } = {}
local currentFile = ""

local t = {
	game = game,
	Shared = game.ReplicatedStorage.Shared,
	Server = game.ServerScriptService.Server,
	Tests = game.TestService.Tests,
}

function t.test(name: string, fn: () -> ())
	table.insert(cases, { name = `{currentFile} › {name}`, fn = fn })
end

function t.eq(actual: any, expected: any, message: string?)
	if actual ~= expected then
		error(`{message or "eq"}: expected {show(expected)}, got {show(actual)}`, 2)
	end
end

function t.neq(actual: any, unexpected: any, message: string?)
	if actual == unexpected then
		error(`{message or "neq"}: did not expect {show(unexpected)}`, 2)
	end
end

function t.deepEq(actual: any, expected: any, message: string?)
	if not deepEqual(actual, expected) then
		error(`{message or "deepEq"}:\n  expected {show(expected)}\n  got      {show(actual)}`, 2)
	end
end

function t.ok(value: any, message: string?)
	if not value then
		error(message or "expected a truthy value", 2)
	end
end

function t.notOk(value: any, message: string?)
	if value then
		error(`{message or "expected a falsy value"}: got {show(value)}`, 2)
	end
end

--------------------------------------------------------------------------------
-- Run
--------------------------------------------------------------------------------

local filter = process.args[1]
local specFiles = {}
for _, entry in fs.readDir("tests") do
	if entry:match("%.spec%.luau$") and (filter == nil or entry:find(filter, 1, true)) then
		table.insert(specFiles, entry)
	end
end
table.sort(specFiles)

for _, entry in specFiles do
	currentFile = entry:gsub("%.spec%.luau$", "")
	local spec = shimRequire(t.Tests[entry:gsub("%.luau$", "")])
	spec(t)
end

local failures = 0
for _, case in cases do
	local ok, err = xpcall(case.fn, debug.traceback)
	if ok then
		print(stdio.color("green") .. "  ✓ " .. stdio.color("reset") .. case.name)
	else
		failures += 1
		print(stdio.color("red") .. "  ✗ " .. case.name .. stdio.color("reset"))
		print("    " .. tostring(err):gsub("\n", "\n    "))
	end
end

print(`\n{#cases - failures}/{#cases} tests passed`)
process.exit(if failures == 0 then 0 else 1)
