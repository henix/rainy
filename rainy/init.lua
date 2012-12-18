function startsWith(str, prefix)
	return (string.sub(str, 1, string.len(prefix)) == prefix)
end

require('rainy.lang') -- os.pathsep

local mods = require('rainy.mods')
local moddef = require('rainy.moddef')

local rainy = {}
local m = {__index = rainy}

function rainy.new()
	local r = {
		mod = mods.new(),
		incpaths = {}
	}
	setmetatable(r, m)
	return r
end

function rainy.add_moddef(this, modfile)
	local fin = assert(io.open(modfile))
	local all = fin:read('*a')

	local co = coroutine.create(moddef.parse)
	local ok, op_err, params = coroutine.resume(co, all)
	while ok and op_err do
		this.mod[op_err](this.mod, unpack(params))
		ok, op_err, params = coroutine.resume(co, all)
	end
	if op_err ~= nil then
		error(modfile..':'..op_err, 0)
	end
	fin:close()
end

function rainy.add_incpath(this, path)
	assert(path)
	table.insert(this.incpaths, path)
end

function openFileIncPath(this, path)
	for _, dir in ipairs(this.incpaths) do
		local finalName = dir..'/'..path
		if os.pathsep ~= '/' then
			finalName = string.gsub(dir..'/'..path, '/', os.pathsep)
		end
		local fin = io.open(finalName)
		if fin ~= nil then
			return fin
		end
	end
	return nil
end

function rainy.process_js(this, jsname)
	local nu = 0
	for line in io.lines(jsname) do
		nu = nu + 1
		if startsWith(line, '#inline') then
			local statement = {}
			for w in string.gmatch(line, '[^%s]+') do
				table.insert(statement, w)
			end
			assert(statement[1] == '#inline', jsname..':'..tostring(nu)..': bad syntax: '..line)
			assert(#statement == 2, jsname..':'..tostring(nu)..': #inline expect 1 argument, but got '..tostring(#statement-1))
			local name = statement[2]
			assert(this.mod:is_defined(name), jsname..':'..tostring(nu)..': module not defined: '..name)

			do
				local alldeps = assert(this.mod:import(name))
				for _, modname in ipairs(alldeps) do
					local fin = openFileIncPath(this, this.mod:jspath(modname))
					assert(fin, 'file not found: '..this.mod:jspath(modname)..' (in '..table.concat(this.incpaths, ';')..')')
					for line in fin:lines() do
						coroutine.yield(line)
					end
					fin:close()
				end
			end
		else
			coroutine.yield(line)
		end
	end
end

return rainy
