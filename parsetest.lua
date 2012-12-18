-- generate intermediate codes from a .moddef file (for debug)
-- Usage: lua parsetest.lua < test.moddef

local moddef = require('rainy.moddef')

local all = io.read('*a')

function printtable(t)
	if type(t) == 'string' then
		io.write(string.format('%q', t))
	elseif type(t) == 'table' then
		io.write('{')
		local first = true
		for _, v in ipairs(t) do
			if first then
				first = false
			else
				io.write(',')
			end
			printtable(v)
		end
		io.write('}')
	end
end

local co = coroutine.create(moddef.parse)
local ok, op_err, params = coroutine.resume(co, all)
while ok and op_err do
	io.write(op_err, '\t')
	printtable(params)
	io.write('\n')
	ok, op_err, params = coroutine.resume(co, all)
end
if op_err ~= nil then
	error('-:'..op_err, 0)
end
