-- A PEG parser for .moddef files

local moddef = {}

local function findWord(str, pos)
	local endpos = pos
	local c = string.byte(str, endpos, endpos)
	local nl = string.byte('\n')
	local len = string.len(str)
	while c ~= nl and c ~= 32 and c ~= 9 do
		endpos = endpos + 1
		if endpos > len then
			break
		end
		c = string.byte(str, endpos, endpos)
	end
	return string.sub(str, pos, endpos - 1)
end

local DirStack = {}
DirStack.meta = {__index=DirStack}

function DirStack.new()
	local r = {}
	setmetatable(r, DirStack.meta)
	return r
end

function DirStack.addDir(this, name, path)
	table.insert(this, {name=name, path=path, before_all=false})
end

function DirStack.setBeforeAll(this)
	assert(#this > 0)
	this[#this].before_all = true
end

function DirStack.hasBeforeAll(this)
	return #this > 0 and this[#this].before_all
end

function DirStack.isEmpty(this)
	return #this == 0
end

function DirStack.fullName(this, name)
	local tmp = {}
	for _, v in ipairs(this) do
		table.insert(tmp, v.name)
	end
	table.insert(tmp, name)
	return table.concat(tmp, '.')
end

function DirStack.fullPath(this, name)
	local tmp = {}
	for _, v in ipairs(this) do
		table.insert(tmp, v.path)
	end
	table.insert(tmp, name)
	return table.concat(tmp, '/')
end

function DirStack.pop(this)
	table.remove(this)
end

function moddef.parse(str)
	local pos = 1
	local endpos = string.len(str)

	local dirStack = DirStack.new()

	local lineNo = 1

	function nextAny()
		if pos <= endpos then
			pos = pos + 1
			return true
		end
		return false
	end

	function nextChar(ec)
		if pos <= endpos then
			local c = string.byte(str, pos, pos)
			if c == ec then
				pos = pos + 1
				return true
			end
		end
		return false
	end

	function nextNot(ch)
		if pos <= endpos then
			local c = string.byte(str, pos, pos)
			if c ~= ch then
				pos = pos + 1
				return true
			end
		end
		return false
	end

	-- !_
	function aheadNot()
		if pos <= endpos then
			return false
		end
		return true
	end

	function nextStr(s)
		if pos <= endpos then
			local len = string.len(s)
			local t = string.sub(str, pos, pos + len - 1)
			if t == s then
				pos = pos + len
				return true
			end
		end
		return false
	end

	-- [A-Za-z0-9_$.-]
	function nextId()
		if pos <= endpos then
			local c = string.byte(str, pos, pos)
			if (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or (c >= 48 and c <= 57) or c == 95 or c == 36 or c == 46 or c == 45 then
				pos = pos + 1
				return true
			end
		end
		return false
	end

	-- id: nextId()+
	-- @return string
	function id()
		local begin = pos
		if not nextId() then return nil end
		while nextId() do end
		return string.sub(str, begin, pos - 1)
	end

	-- pathname: id | "/"
	function pathname()
		if nextId() or nextChar(string.byte("/")) then
			return true
		end
		return false
	end

	-- path: pathname+
	-- @return string
	function path()
		local begin = pos
		if not pathname() then return nil end
		while pathname() do end
		return string.sub(str, begin, pos - 1)
	end

	-- Spaces: (" " | "\t")*
	function Spaces()
		while nextChar(32) or nextChar(9) do end
		return true
	end

	-- Space1: (" " | "\t")+
	function Space1()
		if not (nextChar(32) or nextChar(9)) then return false end
		Spaces()
		return true
	end

	-- comment: "#" [^\n]*
	function comment()
		if not nextChar(string.byte("#")) then return false end
		local nl = string.byte("\n")
		while nextNot(nl) do end
		return true
	end

	-- newline: Spaces comment? "\n"
	function newline()
		local mark = pos
		Spaces()
		comment()
		if not nextChar(string.byte("\n")) then pos = mark; return false end
		lineNo = lineNo + 1
		return true
	end

	-- punct(s): Spaces s Spaces
	function punct(s)
		local mark = pos
		Spaces()
		if not nextStr(s) then pos = mark; return false end
		Spaces()
		return true
	end

	-- keyword(s): s Space1
	function keyword(s)
		local mark = pos
		if not nextStr(s) then pos = mark; return false end
		if not Space1() then pos = mark; return false end
		return true
	end

	-- Moddef: Spaces ("*before_all" | id) punct(":") (path (Space1 path)? )? newline
	function Moddef()
		local mark = pos
		Spaces()
		local modname = nil
		if nextStr("*before_all") then
			modname = '*before_all'
		else
			modname = id()
		end
		if not modname then pos = mark; return false end
		if not punct(":") then pos = mark; return false end
		local jspath = path()
		local csspath
		if jspath ~= nil then
			Spaces()
			csspath = path()
		end
		if not newline() then throw('Unexpect char at end of line: '..findWord(str, pos)); pos = mark; return false end
		-- emit code
		if jspath == nil then
			jspath = modname..'.js'
		end
		if modname == '*before_all' then
			if dirStack:isEmpty() then
				throw('You can\'t define *before_all outside a dir')
			end
		end
		coroutine.yield('define', {dirStack:fullName(modname), dirStack:fullPath(jspath), csspath and dirStack:fullPath(csspath)}, lineNo - 1)
		if modname == '*before_all' then
			dirStack:setBeforeAll()
		else
			if dirStack:hasBeforeAll() then
				coroutine.yield('add_depends', {dirStack:fullName(modname), {dirStack:fullName('*before_all')}}, lineNo - 1)
			end
		end
		return true
	end

	-- Depends_0: Spaces id
	function Depends_0()
		local mark = pos
		if not Space1() then pos = mark; return nil end
		local ret = id()
		if not ret then pos = mark; return nil end
		return ret
	end

	-- Depends: Spaces id "->" id (Space1 id)* newline
	function Depends()
		local mark = pos
		Spaces()
		local modname = id()
		if not modname then pos = mark; return false end
		if not punct("->") then pos = mark; return false end
		local depname = id()
		if not depname then throw('Expect module name after ->, but saw: '..findWord(str, pos)); pos = mark; return false end
		local depends = {}
		repeat
			table.insert(depends, dirStack:fullName(depname))
			depname = Depends_0()
		until depname == nil
		if not newline() then throw('Unexpect char at end of line: '..findWord(str, pos)); pos = mark; return nil end
		-- emit code
		coroutine.yield('add_depends', {dirStack:fullName(modname), depends}, lineNo - 1)
		return true
	end

	local Dir = nil
	local Statement = nil
	local Block = nil

	-- Dir: Spaces keyword("dir") id Space1 path newline? punct("{") newline Block punct("}") newline
	Dir = function()
		local mark = pos
		Spaces()
		if not keyword("dir") then pos = mark; return false end
		local dirname = id()
		if not dirname then throw('Expect id but saw: '..findWord(str, pos)); pos = mark; return false end
		if not Space1() then throw('Expect space but saw: '..findWord(str, pos)); pos = mark; return false end
		local dirpath = path()
		if not dirpath then throw('Expect path but saw: '..findWord(str, pos)); pos = mark; return false end
		newline()
		if not punct("{") then throw('Expect \'{\' but saw: '..findWord(str, pos)); pos = mark; return false end
		if not newline() then throw('There must be a newline after {'); pos = mark; return false end
		-- enter dir
		dirStack:addDir(dirname, dirpath)
		Block()
		dirStack:pop()
		-- exit dir
		if not punct("}") then throw('Expect \'}\' but saw: '..findWord(str, pos)); pos = mark; return false end
		if not newline() then throw('Unexpect char after }: '..findWord(str, pos)); pos = mark; return false end
		return true
	end

	-- Statement: Dir | Moddef | Depends
	Statement = function()
		if Dir() or Moddef() or Depends() then
			return true
		end
		return false
	end

	-- Block: (Statement | newline)*
	Block = function()
		while Statement() or newline() do end
	end

	-- All: Block !_
	function All()
		Block()
		Spaces()
		comment()
		if not aheadNot() then throw('Unexpected char: '..findWord(str, pos)) end
	end

	local ok, err = pcall(All)
	if not ok then
		throw(lineNo..': '..err)
	end
end

return moddef
