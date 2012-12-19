function startsWith(str, prefix)
	return (string.sub(str, 1, string.len(prefix)) == prefix)
end

function endsWith(str, suffix)
	return string.sub(str, str:len() - suffix:len() + 1) == suffix
end

require('rainy.throw')
local rainy = require('rainy')

local rain = rainy.new()

-- command line
if #arg < 1 then
	print('Usage: lua rain.lua [--incpath incpath]* [--moddef moddef]* [--type html/js] <filename>')
	os.exit(1)
end

local ok, err = pcall(function()

local moddefs = {}
local filename
local filetype
local pos = 1
while pos <= #arg do
	if arg[pos] == '--incpath' then
		pos = pos + 1
		tassert(pos <= #arg and not startsWith(arg[pos], '--'), 'missing parameter for --incpath')
		rain:add_incpath(arg[pos])
		pos = pos + 1
	elseif arg[pos] == '--moddef' then
		pos = pos + 1
		tassert(pos <= #arg and not startsWith(arg[pos], '--'), 'missing parameter for --moddef')
		table.insert(moddefs, arg[pos])
		pos = pos + 1
	elseif arg[pos] == '--type' then
		pos = pos + 1
		tassert(pos <= #arg and not startsWith(arg[pos], '--'), 'missing parameter for --type')
		if arg[pos] == 'js' then
			filetype = 'js'
		elseif arg[pos] == 'html' or arg[pos] == 'htm' then
			filetype = 'html'
		else
			throw('unknown file type: '..arg[pos])
		end
		pos = pos + 1
	elseif startsWith(arg[pos], '--') then
		throw('unknown parameter: '..arg[pos])
	else
		tassert(filename == nil, 'more than one filename: '..arg[pos])
		filename = arg[pos]
		pos = pos + 1
	end
end

if filetype == nil then
	if endsWith(filename, '.js') then
		filetype = 'js'
	elseif endsWith(filename, '.htm') or endsWith(filename, '.html') then
		filetype = 'html'
	else
		throw('cannot infer filetype from filename: '..filename..', specify filetype with --type')
	end
end

for _, moddef in ipairs(moddefs) do
	rain:add_moddef(moddef)
end

do -- process
	local func

	if filetype == 'js' then
		func = rainy.process_js
	elseif filetype == 'html' then
		func = rainy.process_html
	end

	local co = coroutine.create(func)
	local ok, line = coroutine.resume(co, rain, filename)
	while ok and line do
		io.write(line, '\n')
		ok, line = coroutine.resume(co, rain, filename)
	end
	if line ~= nil then
		throw(line)
	end
end

end)

if not ok then
	io.stderr:write(err, '\n')
	os.exit(2)
end
