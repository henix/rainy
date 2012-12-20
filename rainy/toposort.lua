-- An incremental DFS topological sort

local toposort = {}

local m = {__index = toposort}

function toposort.new()
	local n = {
		nodes = {},
		visited = {},
	}
	setmetatable(n, m)
	return n
end

function toposort.add_dep(t, name1, name2)
	if t.nodes[name1] == nil then
		t.nodes[name1] = {}
	end
	if t.nodes[name1][name2] ~= nil then
		return nil, 'duplicate edge: '..name1..' -> '..name2
	end
	t.nodes[name1][name2] = true
	return true
end

function toposort.get_deps_incr(t, nodename)
	local sorted = {}

	local function visit(name)
		if not t.visited[name] then
			t.visited[name] = true
			if t.nodes[name] ~= nil then
				for dep, _ in pairs(t.nodes[name]) do
					visit(dep)
				end
			end
			table.insert(sorted, name)
		end
	end

	visit(nodename)

	return sorted
end

-- reset states stored in t
function toposort.reset(t)
	t.visited = {}
end

return toposort
