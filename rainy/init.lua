function startsWith(str, prefix)
	return (string.sub(str, 1, string.len(prefix)) == prefix)
end

require('rainy.throw')
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
	local fin = tassert(io.open(modfile))
	local all = fin:read('*a')

	local co = coroutine.create(moddef.parse)
	local ok, op_err, params, lineNo = coroutine.resume(co, all)
	while ok and op_err do
		local ok2, err = this.mod[op_err](this.mod, unpack(params))
		if not ok2 then
			throw(modfile..':'..lineNo..': '..err)
		end
		ok, op_err, params, lineNo = coroutine.resume(co, all)
	end
	if op_err ~= nil then
		throw(modfile..':'..op_err)
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
	local ok, err = pcall(function()
	for line in io.lines(jsname) do
		nu = nu + 1
		if startsWith(line, '#inline') then
			local statement = {}
			for w in string.gmatch(line, '[^%s]+') do
				table.insert(statement, w)
			end
			tassert(statement[1] == '#inline', 'bad syntax: '..line)
			tassert(#statement == 2, '#inline expect 1 argument, but got '..tostring(#statement-1))
			local name = statement[2]
			tassert(this.mod:is_defined(name), 'module not defined: '..name)
			do
				local alldeps = assert(this.mod:import(name))
				coroutine.yield(';')
				for _, modname in ipairs(alldeps) do
					local jspath = this.mod:jspath(modname)
					if jspath ~= nil then
						local fin = openFileIncPath(this, jspath)
						tassert(fin, 'file not found: '..this.mod:jspath(modname)..' (in '..table.concat(this.incpaths, ';')..')')
						for line in fin:lines() do
							coroutine.yield(line)
						end
						coroutine.yield(';') -- insert a ; between js files
						fin:close()
					end
				end
			end
		else
			coroutine.yield(line)
		end
	end
	end)
	if not ok then
		throw(jsname..':'..nu..': '..err)
	end
end

function yieldall(t)
	for _, v in ipairs(t) do
		coroutine.yield(v)
	end
end

function rainy.process_html(this, htmlname)
	local nu = 0
	local ok, err = pcall(function()

	local beforeHeadCss = {}
	local afterHead

	for line in io.lines(htmlname) do
		nu = nu + 1
		if line == '</head>' then
			tassert(afterHead == nil, 'there are 2 </head>');
			afterHead = {}
			table.insert(afterHead, line)
		elseif startsWith(line, '#inline') then
			local statement = {}
			for w in string.gmatch(line, '[^%s]+') do
				table.insert(statement, w)
			end
			tassert(statement[1] == '#inline', 'bad syntax: '..line)
			tassert(#statement == 2, '#inline expect 1 argument, but got '..tostring(#statement-1))
			local name = statement[2]
			tassert(this.mod:is_defined(name), 'module not defined: '..name)
			local alldeps = assert(this.mod:import(name))
			if #alldeps > 0 then -- insert css
				-- css can only appear in <head>
				local collected_css = (afterHead == nil) and {} or beforeHeadCss
				for _, modname in ipairs(alldeps) do
					local csspath = this.mod:csspath(modname)
					if csspath ~= nil then
						local fin = openFileIncPath(this, csspath)
						tassert(fin, 'file not found: '..csspath..' (in '..table.concat(this.incpaths, ';')..')')
						for line in fin:lines() do
							table.insert(collected_css, line)
						end
						fin:close()
					end
				end
				-- if it is before </head> , yield immediately
				if afterHead == nil and #collected_css > 0 then
					coroutine.yield('<style type="text/css" rel="stylesheet">')
					yieldall(collected_css)
					coroutine.yield('</style>')
				end
			end
			if #alldeps > 0 then -- insert js
				local collected_js = afterHead or {}
				table.insert(collected_js, '<script type="text/javascript">')
				for _, modname in ipairs(alldeps) do
					local jspath = this.mod:jspath(modname)
					if jspath ~= nil then
						local fin = openFileIncPath(this, jspath)
						tassert(fin, 'file not found: '..this.mod:jspath(modname)..' (in '..table.concat(this.incpaths, ';')..')')
						for line in fin:lines() do
							table.insert(collected_js, line)
						end
						table.insert(collected_js, ';') -- insert a ; between js files
						fin:close()
					end
				end
				table.insert(collected_js, '</script>')
				-- if it is before </head> , yield immediately, otherwise buffer it in afterHead
				if afterHead == nil then
					yieldall(collected_js)
				end
			end
		else
			if afterHead ~= nil then
				table.insert(afterHead, line)
			else
				coroutine.yield(line)
			end
		end
	end
	tassert(afterHead, 'did not see </head>')
	if #beforeHeadCss > 0 then
		coroutine.yield('<style type="text/css" rel="stylesheet">')
		yieldall(beforeHeadCss)
		coroutine.yield('</style>')
	end
	yieldall(afterHead)

	end)

	if not ok then
		throw(htmlname..':'..nu..': '..err)
	end
end

return rainy
