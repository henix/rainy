local toposort = require('rainy.toposort')

local mods = {}

local m = {__index = mods}

function mods.new()
	local r = {
		-- [str] => {jspath, csspath}
		mods = {},
		topo = toposort.new()
	}
	setmetatable(r, m)
	return r
end

function mods.is_defined(this, name)
	return this.mods[name] ~= nil
end

function mods.jspath(this, name)
	return this.mods[name].jspath
end

function mods.csspath(this, name)
	return this.mods[name].csspath
end

function mods.define(this, name, jspath, csspath)
	if this.mods[name] ~= nil then
		return nil, 'module already defined: '..name
	end
	this.mods[name] = {}
	this.mods[name].jspath = jspath
	this.mods[name].csspath = csspath
	return true
end

function mods.add_depends(this, name, deps)
	if this.mods[name] == nil then
		return nil, 'module not defined: '..name
	end
	for _, depname in ipairs(deps) do
		if this.mods[depname] == nil then
			return nil, 'module not defined: '..depname
		end
		if not this.topo:add_dep(name, depname) then
			return nil, 'duplication dependency of '..name..': '..depname
		end
	end
	return true
end

function mods.import(this, modname)
	assert(modname)
	if not mods.is_defined(this, modname) then
		return nil, 'module not defined: '..name
	end
	return this.topo:get_deps_incr(modname)
end

return mods
