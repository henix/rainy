function throw(msg)
	assert(msg)
	error(msg, 0)
end

function tassert(cond, msg, ...)
	if not cond then
		throw(msg)
	end
	return cond, msg, ...
end
