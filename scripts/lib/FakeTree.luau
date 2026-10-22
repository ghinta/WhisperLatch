--!nonstrict
-- Mirrors the Rojo tree (default.project.json) with lightweight fake
-- instances, so modules written with Roblox-style instance requires
-- (`require(script.Parent.X)`) run unchanged under Lune.

local fs = require("@lune/fs")
local luau = require("@lune/luau")

export type Mount = { service: string, name: string, path: string }

export type Options = {
	mounts: { Mount },
	-- extra globals for every loaded module (e.g. Roblox datatypes)
	globals: { [string]: any }?,
	-- objects returned by game:GetService for services that are not mounted
	services: { [string]: any }?,
}

type Node = {
	name: string,
	className: string,
	parent: Node?,
	dir: string?,
	file: string?,
	children: { [string]: Node }?,
	extraChildren: { [string]: Node },
}

local FakeTree = {}

local function newNode(name: string, className: string, parent: Node?): Node
	return { name = name, className = className, parent = parent, extraChildren = {} }
end

local function stripSuffix(entry: string, suffix: string): string?
	if entry:sub(-#suffix) == suffix then
		return entry:sub(1, -#suffix - 1)
	end
	return nil
end

local function scanDir(node: Node)
	local children = {}
	local dir = node.dir
	if dir then
		for _, entry in fs.readDir(dir) do
			local full = dir .. "/" .. entry
			if fs.isDir(full) then
				local child = newNode(entry, "Folder", node)
				child.dir = full
				if fs.isFile(full .. "/init.luau") then
					child.className = "ModuleScript"
					child.file = full .. "/init.luau"
				end
				children[entry] = child
			elseif not entry:match("^init%.") then
				local serverName = stripSuffix(entry, ".server.luau")
				local clientName = stripSuffix(entry, ".client.luau")
				local moduleName = stripSuffix(entry, ".luau")
				if serverName then
					local child = newNode(serverName, "Script", node)
					child.file = full
					children[serverName] = child
				elseif clientName then
					local child = newNode(clientName, "LocalScript", node)
					child.file = full
					children[clientName] = child
				elseif moduleName then
					local child = newNode(moduleName, "ModuleScript", node)
					child.file = full
					children[moduleName] = child
				end
			end
		end
	end
	for name, child in node.extraChildren do
		children[name] = child
	end
	node.children = children
end

-- fs calls yield, which is not allowed inside metamethods, so the whole
-- tree is scanned eagerly up front.
local function scanTree(node: Node)
	scanDir(node)
	for _, child in node.children :: { [string]: Node } do
		scanTree(child)
	end
end

function FakeTree.new(options: Options)
	local proxies: { [Node]: any } = {}
	local nodeOfProxy: { [any]: Node } = {}
	local moduleCache: { [string]: any } = {}
	local loading: { [string]: boolean } = {}
	local services = options.services or {}

	local proxyOf

	local function findChild(node: Node, name: string): Node?
		return (node.children :: { [string]: Node })[name]
	end

	local methods = {}

	function methods.FindFirstChild(self, name: string)
		local child = findChild(nodeOfProxy[self], name)
		return if child then proxyOf(child) else nil
	end

	function methods.WaitForChild(self, name: string)
		local node = nodeOfProxy[self]
		local child = findChild(node, name)
		if not child then
			error(`WaitForChild: {name} is not a child of {node.name}`, 2)
		end
		return proxyOf(child)
	end

	function methods.GetChildren(self)
		local list = {}
		for _, child in nodeOfProxy[self].children :: { [string]: Node } do
			table.insert(list, proxyOf(child))
		end
		return list
	end

	function methods.IsA(self, className: string)
		return nodeOfProxy[self].className == className
	end

	function methods.GetService(self, name: string)
		if services[name] ~= nil then
			return services[name]
		end
		return methods.WaitForChild(self, name)
	end

	function proxyOf(node: Node): any
		local existing = proxies[node]
		if existing then
			return existing
		end
		local proxy = setmetatable({}, {
			__index = function(_, key: string)
				if key == "Name" then
					return node.name
				elseif key == "ClassName" then
					return node.className
				elseif key == "Parent" then
					return if node.parent then proxyOf(node.parent) else nil
				elseif methods[key] then
					return methods[key]
				end
				local child = findChild(node, key)
				if not child then
					error(`{key} is not a valid member of {node.className} "{node.name}"`, 2)
				end
				return proxyOf(child)
			end,
			__newindex = function()
				error("fake instances are read-only", 2)
			end,
			__tostring = function()
				return node.name
			end,
		})
		proxies[node] = proxy
		nodeOfProxy[proxy] = node
		return proxy
	end

	local gameNode = newNode("game", "DataModel", nil)
	for _, mount in options.mounts do
		local service = gameNode.extraChildren[mount.service]
		if not service then
			service = newNode(mount.service, "Folder", gameNode)
			gameNode.extraChildren[mount.service] = service
		end
		local folder = newNode(mount.name, "Folder", service)
		folder.dir = mount.path
		service.extraChildren[mount.name] = folder
	end
	scanTree(gameNode)
	local game = proxyOf(gameNode)

	local function shimRequire(target: any): any
		local node = nodeOfProxy[target]
		if not node or node.className ~= "ModuleScript" or not node.file then
			error(`require: expected a ModuleScript, got {tostring(target)}`, 2)
		end
		local file = node.file :: string
		if moduleCache[file] ~= nil then
			return moduleCache[file]
		end
		if loading[file] then
			error(`require: cyclic dependency on {file}`, 2)
		end
		loading[file] = true
		local environment = {
			script = proxyOf(node),
			require = shimRequire,
			game = game,
		}
		for key, value in options.globals or {} do
			environment[key] = value
		end
		local chunk = luau.load(fs.readFile(file), { debugName = file, environment = environment })
		local result = chunk()
		loading[file] = nil
		moduleCache[file] = result
		return result
	end

	return {
		game = game,
		require = shimRequire,
	}
end

return FakeTree
