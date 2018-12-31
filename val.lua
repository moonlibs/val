local M = {}

local REQ_MULTICAST_MT = {}
local OPT_MULTICAST_MT = {}

local function validator(schema, prefix, lines, funcs)
	for k,rule in pairs(schema) do
		local key, name
		if type(k) == 'string' then
			name = string.format('%s.%s',prefix,k)
			if k:match("^[A-Za-z_][A-Za-z_0-9]*$") then
				key = name
			else
				key = string.format('%s[ [[%s]] ]',prefix,k)
			end
		elseif type(k) == 'number' then
			key = string.format('%s[%s]',prefix,k)
			name = key
		else
			error(string.format("Not supported key type for %s.%s: %s",prefix, k, type(k)),2)
		end
		-- print(k,key,name,rule)


		local function common_check(checktype, required)
			table.insert(lines, string.format([[
				_currkey = '%s'
				_currval = %s
			]], key, key))

			if required then
				table.insert(lines, string.format([[
					if %s == nil then
						error{ 'missing', ( _currcast and string.format("no value after %%d cast",_currcast) or unpack{} ) }
					end
				]],key))
			else
				table.insert(lines, string.format([[
					if %s ~= nil then
				]],key))
			end
				table.insert(lines, string.format([[
					if type(%s) ~= '%s' then
						error{ 'invalid', string.format("got %%s, expected %%s"..( _currcast and string.format(" (after %%d cast)",_currcast) or "" ), _typename(%s), '%s') }
					end
				]],key,checktype,key,checktype))
			if required then
			else
				table.insert(lines, string.format([[
					end
				]]))
			end
		end

		local function cdata_check(checktype, required)
			lines.top.ffi = [[local ffi = require 'ffi']]

			table.insert(lines, string.format([[
				_currkey = '%s'
				_currval = %s
			]], key, key))

			if required then
				table.insert(lines, string.format([[
					if %s == nil then
						error{ 'missing', ( _currcast and string.format("no value after %%d cast",_currcast) or unpack{} ) }
					end
				]],key))
			else
				table.insert(lines, string.format([[
					if %s ~= nil then
				]],key))
			end
				table.insert(lines, string.format([[
					if type(%s) ~= '%s' then
						error{ 'invalid', string.format("got %%s, expected %%s"..( _currcast and string.format(" (after %%d cast)",_currcast) or "" ), _typename(%s), '%s') }
					end
				]],key,'cdata',key,checktype))
				
				table.insert(lines, string.format([[
						if tostring(ffi.typeof(%s)) ~= '%s' then
							error{ 'invalid', string.format("got %%s, expected %%s"..( _currcast and string.format(" (after %%d cast)",_currcast) or "" ), _typename(%s), '%s') }
						end
				]],key,checktype,key,checktype))
				
			if required then
			else
				table.insert(lines, string.format([[
					end
				]]))
			end

		end

		local function array_check(checktype)
			-- table.insert(checks, 1, "local ffi = require 'ffi'")
			-- table.insert(checks, string.format("assert(tostring(ffi.typeof(%s)) == '%s','%s required to be of type %s')",key,ffitype,key,ffitype))
		end
		
		local generic_check -- function

		local function cast_check(checktype, required)
			table.insert(lines, string.format([[
				_currkey = '%s'
				_currval = %s
				do
					local _currcast = 0
			]], key, key))
			table.insert(lines, string.format([[
					if %s == nil then
			]], key))
			if required then
				table.insert(lines, [[
						error{ 'missing' }
					end
				]])
			else
				table.insert(lines, [[
					--skip
					else
				]])
			end

			for _, rule in pairs(checktype) do
				if type(rule) == 'function' then
					table.insert(funcs,rule) -- FIXME
					table.insert(lines, string.format([[
						_currcast = _currcast + 1
						%s = funcs[%s](%s, '%s')
					]], key, #funcs, key, key))
					
					table.insert(lines, string.format([[
						if %s == nil then
							error{ 'invalid', string.format("got no value after %%d cast", _currcast) }
						end
					]], key, #funcs, key, key))
				else
					table.insert(lines, string.format([[
						-- TODO: type check %s
					]], rule))
					generic_check(rule)
				end
			end
			table.insert(lines, string.format([[
					_currcast = nil
				end
			]]))
			if not required then
				table.insert(lines, [[
				end
				]])
			end
		end
		
		generic_check = function(rule)
			if type(rule) == 'string' then
				rule = rule
					:gsub("^req%s+","+")
					:gsub("^required%s+","+")
					:gsub("^opt%s+","?")
					:gsub("^optional%s+","?")
					:gsub("^maybe%s+","?")

				local required, luatype
				if rule:match('^[+?]') then
					required = rule:match('^([+?])') == '+'
					luatype  = rule:match('^.(.+)')
				else
					required = true
					luatype = rule
				end
				
				-- print(required,luatype)
				
				if luatype:match('^ctype') then
					-- common_check('cdata',required)
					cdata_check(luatype, required)
				else
					common_check(luatype,required)
				end
			elseif type(rule) == 'function' then
				-- table.insert(funcs,rule)
				-- 	table.insert(checks, string.format("callbacks[%s](%s, '%s')", #callbacks, key, key))
				cast_check({ rule }, true)
			elseif type(rule) == 'table' then
				local mt = getmetatable(rule)
				if mt and (mt == REQ_MULTICAST_MT or mt == OPT_MULTICAST_MT) then
					cast_check(rule,mt == REQ_MULTICAST_MT)
				else
					common_check('table',true)
					validator(rule,prefix..'.'..k, lines, funcs)
				end
			-- 	-- it's a type
			-- 	common_check('table')
			-- 	if type(rule) == 'table' then
			-- 	end
			else
				error("Not supported check type for "..k..": "..type(rule),2)
				error(string.format("Not supported check type for %s: %s", key, type(rule)),2)
			end
		end
		generic_check(rule)
	end
end

function M.validator(schema,handlers)
	-- print(yaml.encode(schema))
	local prefix = 'args'
	local lines = { "return function("..prefix..")",[[
		local _currkey,_currval,_currcast
		-- print("xpcall to validator function")
		local function _typename(value)
			return type(value) ~= 'cdata' and type(value) or tostring(require"ffi".typeof(value))
		end
		local r,e = xpcall(function()
	]] }
	lines.top = {}
	local funcs = {}
	handlers = handlers or {}
	validator(schema, prefix, lines, funcs)
	table.insert(lines,[[
		end,function(err) -- catch of xpcall
			-- print("in xpcall error",yaml.encode(err), _currkey, _currval)
			if type(err) == 'table' and err[1] then
				if handlers.handler then
					local _,he = pcall(handlers.handler,_currkey, _currval, err)
					-- handler could both return new error or raise it with error
					return he
				end
				local msg = {}
				local maxk
				for k,v in ipairs(err) do
					if k > 1 then
						table.insert(msg,tostring(v))
					end
					maxk = k
				end
				for k,v in pairs(err) do
					if type(k) ~= 'number' or k > maxk then
						table.insert(msg,string.format("%s=%s",k,tostring(v)))
					end
				end
				if #msg > 0 then
					return string.format("%s is %s with value %s: %s",
						_currkey,err[1],tostring(_currval),table.concat(msg,", "))
				else
					return string.format("%s is %s with value %s",
						_currkey,err[1],tostring(_currval))
					
				end
			else
				if handlers.handler then
					local internal_err = {'internal',err}
					local _,he = pcall(handlers.handler,_currkey, _currval, internal_err)
					return he
				end
			end
			return err
		end,args)
		-- print("xpcall return = ",r,yaml.encode(e))
		if not r then error(e,2) end
	]])
	table.insert(lines,"return "..prefix.." end")
	for k,v in pairs(lines.top) do
		table.insert(lines,1,v)
	end
	lines.top = nil
	
	local source =
	[[
		-- print("call to loaded: ",...)
		local handlers,funcs = ...
	]]
	..
	table.concat(lines,"\n")
	
	-- handlers.handler = handlers.handler or function(key,value,reason,...)
	-- 	-- if reason == 'invalid'
	-- 	-- '%s required to be of type %s'
	-- end
	
	-- print(source) os.exit()
	
	local loaded, err = loadstring(source)
	if not loaded then error(err) end
	local f = loaded(handlers, funcs)
	-- print(source, f)
	return f
end

M.idator = M.validator

local function required_optional( required, ... )
	local has_func = false
	local argc = select('#',...)
	for i=1,argc do
		if type(select(i,...)) == 'function' then
			has_func = true
			break
		end
	end
	if argc == 1 and not has_func then
		local check = ...
		if check:match('^[+?]') then
			-- check:match('^%+') xor required
			-- There is no xor, so...
			if check:match('^%+') ~= nil ~= required then
				error("Ambiguous usage of required vs sigils",3)
			end
			return check
		else
			return (required and '+' or '?') .. check
		end
	end
	return setmetatable({...},required and REQ_MULTICAST_MT or OPT_MULTICAST_MT)
end

function M.required(...)
	return required_optional(true,...)
end
M.req = M.required

function M.optional(...)
	return required_optional(false,...)
end
M.opt   = M.optional
M.maybe = M.optional

-- lua's tonumber can take optional second parameter
-- so it does not work with our functions taking (value, key) as arguments
function M.tonumber(value)
	return tonumber(value)
end
M.number = M.tonumber
M.num    = M.tonumber

return setmetatable(M,{
	__call = function(_,...) return _.idator(...) end
})
