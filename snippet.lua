yaml = require 'yaml'
yaml.cfg{ encode_use_tostring = true }
local log = require 'log'

-- local clock = require 'clock'

-- local callee = function(...)
-- 	error("x")
-- end
-- local handler = function() end

-- local start  = clock.proc()
-- local N = 1000000
-- for i = 1,N do
-- 	xpcall(callee,handler,1,2,3);
-- 	-- pcall(callee,1,2,3);
-- end
-- local delta = clock.proc() - start

-- print(string.format("%0.4fs / %s: %0.0f RPS",delta,N,N/delta))

-- print(xpcall(function ()
-- 	error{"x"}
-- end,function (e)
-- 	print(type(e),e)
-- 	print(debug.traceback("",1))
-- 	return nil
-- end))

-- do return end

--[=[
local val = require 'validate'

-- local myvl = val.extend('method','get',function() end)
-- local myvl = val.primitive('get',function() end)

luatype:
type(v) == luatype
ctype<T>
type(v) == 'cdata' and ffi.typeof(v) == 'ctype<T>'
array<T>: (array of T)
type(v) == 'table' and is_array(v) and for _,inner in ipairs(v) do type(inner) == T end





local validator = val.copy { } -- perform a deepcopy instead of inplace cast

--[[
	+ - required
	? - optional
	
	
]]

local validator = val {
	-- required variants
	key = '+luatype'; -- canonical
	key = 'luatype';
	key = 'req luatype';
	key = 'required luatype';
	key = val.required('luatype');
	-- key = val.required{
	-- 	type = 'luatype',
	-- };
	
	-- optional variants
	key = '?luatype'; -- canonical
	key = 'opt luatype';
	key = 'optional luatype';
	key = 'maybe luatype';
	key = val.optional('luatype'); -- > '?luatype'
	
	-- functions
	key = function(v) end, -- result is not nil
	key = val.required(function(v) end, 'luatype'), -- result is not nil
	key = val.required('luatype', function(v) end, 'luatype'), -- result is not nil
	-- key = val.required{
	-- 	type = 'luatype';  -- checked before cast
	-- 	cast = function(v) end;
	-- 	result = 'luatype'; -- checked after cast
	-- };
}

function M.required( ... )
	-- 'luatype', function(v) end, 'luatype'
	return setmetatable({ 'luatype', function(v) end, 'luatype' },REQ_MT)
end

for _,rule in pairs(req_table) do
	value_validator(name,rulem....)
end

function M.required( ... )
	-- 'luatype', function(v) end, 'luatype'
	return function()
		
	end
end


val {
	id      = id.tobucket;
	project = val.req('string',function(v) return T.projects.hash(box.space.projects:get(v)) end);
	project = val.req('string',val.get('projects')); --> T(box.space[arg1]:get(v))
	project = val.req('string',val.get('projects','pid'));  --> T(box.space[arg1].index[arg2]:get(v))

	project = val.req('string',loader,'table');
	
	encodeUri = val.toboolean;
	encodeUri = val.opt(val.toboolean);
	
	user = val.req('string','box.space.users:get')
}


val({
	id      = id.tobucket;
	var     = function() val.error(reason,...) end;
},{
	-- default reasons: missing, invalid
	reasons = { -- map default reasons into custom
		missing  = 'MissingArgument';
		invalid  = 'InvalidArgument';
		internal = 'InternalError';
		invalid  = { reason = 'InvalidArgument' };
	};
	handler = function(name,value,reason,...)
		error(box.tuple.new{ 400, { Code; Message; ... } })
	end;
	
	-- error = {'invalid'};
	-- error = {'missing'};
	-- error{ "mybaderror", key="value" }
	
	handler = function(name,value,error)
		error(box.tuple.new{ 400, { Code; Message; ... } })
	end;
	handler = function(params)
		error(box.tuple.new{ 400, {
			Code = params.reason;
			Message = string.format("Field %s is bad",params.name);
			Value = params.value;
			...?
		} })
	end
})
]=]

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
			if required then
				table.insert(lines, string.format([[
					if %s == nil then
						error{ 'missing' }
					end
				]],key))
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
--[=[
local ffi = require 'ffi' -- if have cdata_check

print("call to loaded: ",...)
local funcs = ...
local invalid = ...
local function assert(test,err)
	
end

return function(args)
	xpcall(function()
	
		-- common_check
		assert( args.param ~= nil, missing )
		assert( type(args.param) == 'luatype', invalid )
		
		cdata_check
		assert( args.param ~= nil, missing )
		assert( type(args.param) == 'cdata', invalid )
		-- table.insert(checks, 1, "local ffi = require 'ffi'")
		assert(tostring(ffi.typeof(args.param)) == 'ctype<uint32_t>',invalid)
		
		

		
		assert( args.param ~= nil, missing )
		assert( type(args.param) == 'luatype', invalid )
		args.param = funcs[78]( args.param )
		assert( type(args.param) == 'luatype2', invalid )
		
	end,function(e)
		local msg = debug.traceback("",1)
		
	end)
	
	return args
end
]=]

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
M.opt = M.optional
M.maybe = M.optional

setmetatable(M,{
	__call = function(_,...) return _.idator(...) end
})

--[[
print(M.required('test'))
print(M.required('+test'))
-- print(M.required('?test'))
print(M.optional('test'))
print(M.optional('?test'))
-- print(M.optional('+test'))
]]

-- print(yaml.encode( M.required('test',function() end) ))
-- do return end


local ffi = require'ffi'

local testno = 0
local failed = 0

local function v_test_ok(validator, struct, name)
	testno = testno+1
	name = name or "test"
	local r,e = pcall(validator,struct)
	if r then
		print(string.format("ok %d - %s", testno, name))
	else
		failed = failed + 1
		print(string.format("not ok %d - %s", testno, name))
		print(string.format("#\tError: %s",e))
	end
end

local function v_test_not_ok(validator, struct, kind, name)
	testno = testno+1
	name = name or "test"
	local r,e = pcall(validator,struct)
	if r then
		failed = failed + 1
		print(string.format("not ok %d - %s", testno, name))
		print(string.format("#\tError: test is passing"))
	else
		if type(kind) == 'function' then
			if kind(e) then
				print(string.format("ok %d - %s", testno, name))
			else
				failed = failed + 1
				print(string.format("not ok %d - %s", testno, name))
				print(string.format("#\tError is wrong: %s",e))
			end
		end
	end
end

--[[
	synonyms
	types + cdata
		-- TODO:
			non-empty-string
			any-number
			callable
			toboolean
	nested structures
	custom error
]]

-- for _,test in pairs({
-- 	{ "number", {-2^31,-1,0,1,0.5,2/3,2^31}, {"","test", 1LL, 1ULL, {}, function() end,true,false}},
-- 	{ "string", {"","test"}, {1, 1LL, 1ULL, {}, function() end,true,false}},
-- 	{ "table", {{},{x=1}}, {"","test",1, 1LL, 1ULL, function() end,true,false}},
-- 	{ "function", { function() end }, {"","test",1, 1LL, 1ULL, {},true,false }},
-- 	{ "boolean", { true,false }, {"","test",1, 1LL, 1ULL, {}, function() end }},
	
-- 	{ "cdata", { 1LL, 1ULL }, {"",1, {}, function() end }},
	
-- 	{ "ctype<uint64_t>", { 1ULL }, { "",1, 1LL, {}, function() end }},
-- 	{ "ctype<int64_t>", { 1LL }, { "",1, 1ULL, {}, function() end }},
-- }) do
-- 	local typename,positive,negative = unpack(test)
-- 	local vv = M({ test = typename });
-- 	for _,value in pairs(positive) do
-- 		v_test_ok(
-- 			vv,
-- 			{ test = value },
-- 			"types '"..typename.."' positive with '"..tostring(value).."'"
-- 		)
-- 	end
-- 	for _,value in pairs(negative) do
-- 		v_test_not_ok(
-- 			vv,
-- 			{ test = value },
-- 			function(e)
-- 				return e:match("invalid")
-- 					and e:match(typename)
-- 					and e:match(type(value) == 'cdata' and tostring(ffi.typeof(value)) or type(value))
-- 				end,
-- 			"types '"..typename.."' negative: invalid with '"..tostring(value).."'"
-- 		)
-- 	end
-- end

-- M{ test = M.opt('table',{ nested = "?ctype<uint64_t>" }) }({})
-- do return end

for _,cons in pairs({
	{true,  ""},
	{true,  "+"},
	{true,  "req "},
	{true,  "required "},
	{true,  {"req"}},
	{true,  {"required"}},
		
	{false, "?"},
	{false, "opt "},
	{false, "optional "},
	{false, "maybe "},
	{false, {"opt"}},
	{false, {"optional"}},
	{false, {"maybe"}},
}) do
	local required, typecheck = unpack(cons)
	for _,test in pairs({
		{ "number", {-2^31,-1,0,1,0.5,2/3,2^31}, {"","test", 1LL, 1ULL, {}, function() end,true,false}},
		{ "string", {"","test"}, {1, 1LL, 1ULL, {}, function() end,true,false}},
		{ "table", {{},{x=1}}, {"","test",1, 1LL, 1ULL, function() end,true,false}},
		{ "function", { function() end }, {"","test",1, 1LL, 1ULL, {},true,false }},
		{ "boolean", { true,false }, {"","test",1, 1LL, 1ULL, {}, function() end }},
		{ "cdata", { 1LL, 1ULL }, {"",1, {}, function() end }},
		{ "ctype<uint64_t>", { 1ULL }, { "",1, 1LL, {}, function() end }},
		{ "ctype<int64_t>", { 1LL }, { "",1, 1ULL, {}, function() end }},
	}) do
		local typename,positive,negative = unpack(test)
		local constraint;
		local constraint_name;
		if type(typecheck) == 'table' then
			if #typecheck == 1 then
				local method = unpack(typecheck)
				constraint_name = "val."..method.."("..typename..")"
				constraint = M[method](typename)
			-- elseif #typecheck == 2 then
			-- 	local label,checkf = unpack(typecheck)
			-- 	constraint_name = label.."()"
			-- 	constraint = checkf
			else
				error("GTFO")
			end
			
		else
		 	constraint = typecheck..typename
		 	constraint_name = constraint
		end
		
		for _,is_nested in pairs({true,false}) do
			local positives = {}
			local negatives = {}
			local n_cons
			local n_cons_name
			if is_nested then
				for _,v in pairs(positive) do
					table.insert(positives, { inner = v })
				end
				for _,v in pairs(negative) do
					table.insert(negatives, { inner = v })
				end
				n_cons = { inner = constraint }
				n_cons_name = "nested "..constraint_name
			else
				positives = positive
				negatives = negative
				n_cons = constraint
				n_cons_name = "common "..constraint_name
			end
			local vv = M({ test = n_cons });
		
			for _,value in pairs(positives) do
				local real_value
				if is_nested then
					real_value = value.inner
				else
					real_value = value
				end
				v_test_ok(
					vv,
					{ test = value },
					"constraint '"..n_cons_name.."' positive with '"..tostring(real_value).."'"
				)
			end
			
			if required then
				v_test_not_ok(
					vv,
					{},
					function(e) return e:match("missing") end,
					"constraint '"..n_cons_name.."' negative: missing"
				)
			else
				v_test_ok(
					vv,
					is_nested and { test = {} } or {},
					"constraint '"..n_cons_name.."' positive missing"
				)
			end
			
			for _,value in pairs(negatives) do
				local real_value
				if is_nested then
					real_value = value.inner
				else
					real_value = value
				end
				v_test_not_ok(
					vv,
					{ test = value },
					function(e)
						return e:match("invalid")
							and e:match(typename)
							and e:match(type(real_value) == 'cdata' and tostring(ffi.typeof(real_value)) or type(real_value))
						end,
					"constraint '"..n_cons_name.."' negative: invalid with '"..tostring(real_value).."'"
				)
			end
			
		end
		
		-- local vv = M({ test = constraint });
	
		-- for _,value in pairs(positive) do
		-- 	v_test_ok(
		-- 		vv,
		-- 		{ test = value },
		-- 		"constraint '"..constraint_name.."' positive with '"..tostring(value).."'"
		-- 	)
		-- end
		
		-- if required then
		-- 	v_test_not_ok(
		-- 		vv,
		-- 		{},
		-- 		function(e) return e:match("missing") end,
		-- 		"constraint '"..constraint_name.."' negative: missing"
		-- 	)
		-- else
		-- 	v_test_ok(
		-- 		vv,
		-- 		{},
		-- 		"constraint '"..constraint_name.."' positive missing"
		-- 	)
		-- end
		
		-- for _,value in pairs(negative) do
		-- 	v_test_not_ok(
		-- 		vv,
		-- 		{ test = value },
		-- 		function(e)
		-- 			return e:match("invalid")
		-- 				and e:match(typename)
		-- 				and e:match(type(value) == 'cdata' and tostring(ffi.typeof(value)) or type(value))
		-- 			end,
		-- 		"constraint '"..constraint_name.."' negative: invalid with '"..tostring(value).."'"
		-- 	)
		-- end
	end
end

print(string.format("%d..%d",testno,testno))
if failed > 0 then
	print(string.format("# Looks like you failed %d test of %d.",failed,testno))
end

do return end

for _,typecheck in pairs({"?","opt ", "optional ", "maybe "}) do
	local constraint = typecheck.."string"
	local vv = M({ test = constraint })
	
	v_test_ok(
		vv,
		{ test = "test" },
		"constraint '"..constraint.."' positive"
	)
	
	v_test_ok(
		vv,
		{},
		"constraint '"..constraint.."' positive missing"
	)
	
	v_test_not_ok(
		vv,
		{ test = 1 },
		function(e) return e:match("invalid") and e:match("number") end,
		"constraint '"..constraint.."' negative: invalid"
	)
end

for _,method in pairs({"req","required"}) do
	local callname = "val."..method
	local vv = M({ test = M[method]("string") })
	
	v_test_ok(
		vv,
		{ test = "test" },
		"callname '"..callname.."' positive"
	)
	
	v_test_not_ok(
		vv,
		{},
		function(e) return e:match("missing") end,
		"callname '"..callname.."' negative: missing"
	)
	
	v_test_not_ok(
		vv,
		{ test = 1 },
		function(e) return e:match("invalid") and e:match("number") end,
		"callname '"..callname.."' negative: invalid"
	)
end

for _,method in pairs({"opt", "optional", "maybe"}) do
	local callname = "val."..method
	local vv = M({ test = M[method]("string") })
	
	v_test_ok(
		vv,
		{ test = "test" },
		"callname '"..callname.."' positive"
	)
	
	v_test_ok(
		vv,
		{},
		"callname '"..callname.."' positive missing"
	)
	
	v_test_not_ok(
		vv,
		{ test = 1 },
		function(e) return e:match("invalid") and e:match("number") end,
		"callname '"..callname.."' negative: invalid"
	)
end

v_test_ok(
	M({ test = { a = "string"; b = "number" }}),
	{ test = { a = "test"; b = 42 } },
	"required struct positive"
)

v_test_not_ok(
	M({ test = { a = "string"; b = "number" }}),
	{ test = { a = "string"; b = "string" } },
	function(e)
		return e:match("test%.b") and e:match("invalid") and e:match("expected number")
	end,
	"required struct negative: invalid"
)

v_test_not_ok(
	M({ test = { a = "string"; b = "number" }}),
	{ test = { a = "string"; } },
	function(e)
		return e:match("test%.b") and e:match("missing")
	end,
	"required struct negative: missing"
)

v_test_ok(
	M(
		{ test = function(v) return v end }
	),
	{ test = "test" },
	"required function positive"
)

v_test_not_ok(
	M(
		{ test = function(v) error{'wrong', 'myerrormessage'} end }
	),
	{ test = 1 },
	function(e)
		-- print("#",e)
		return e:match("wrong") and e:match("myerrormessage")
	end,
	"required function negative: custom error"
)

v_test_not_ok(
	M(
		{ test = function(v)  end }
	),
	{ test = 1 },
	function(e)
		-- print("#",e)
		return e:match("invalid") and e:match("after 1 cast")
	end,
	"required function negative: noreturn"
)

v_test_ok(
	M(
		{ test = { inner = function(v) return v end } }
	),
	{ test = { inner = "test" }},
	"required function nested positive"
)

v_test_not_ok(
	M(
		{ test = { inner = function(v) error{'wrong', 'myerrormessage'} end } }
	),
	{ test = { inner = "test" }},
	function(e)
		-- print("#",e)
		return e:match("test%.inner") and e:match("wrong") and e:match("myerrormessage")
	end,
	"required function nested negative: custom error"
)

v_test_not_ok(
	M(
		{ test = { inner = function(v)  end }}
	),
	{ test = { inner = "test" }},
	function(e)
		-- print("#",e)
		return e:match("test%.inner") and e:match("invalid") and e:match("after 1 cast")
	end,
	"required function nested negative: noreturn"
)

v_test_ok(
	M({ test = M.req("string") }),
	{ test = "test" },
	"explicit required string positive"
)
v_test_ok(
	M({ test = M.opt("string") }),
	{  },
	"explicit optional string positive (missing)"
)


do return end

local v = M.idator({
	ull    = 'ctype<uint64_t>';
	string = '?string';
	-- number = 'maybe number';
	number = function(v,name)
		-- local x = nil/nil
		if type(v) ~= 'number' then
			error{ 'invalid1' }
		end
 		if v < 0 then
 			error{ 'invalid2', 'must be positive'; shit="happens" }
 		end
	end;
	number2 = M.required(
		'number',
		function(v,name) return ffi.typeof('uint64_t')(v) --[[return v]] end,
		'ctype<uint64_t>',
		-- function(v,name) --[[return tostring(v)]] return v end,
		function(v,name) return tostring(v) end,
		'string'
	);
	['x-req-id'] = 'string';
},{
	-- handler = function(name,value,err)
	-- 	log.info("Got error %s on %s=%s, %s",err[1],name,value,yaml.encode(err))
	-- 	error(box.tuple.new{ 500, { Code=err[1]; ArgumentName=name; ArgumentValue=value; Debug = err[2] } })
	-- end;
})

local r,e = pcall(function()
	print(yaml.encode( v({
		string = "test";
		number = 1;
		number2 = 1;
		ull = 1ULL;
		['x-req-id'] = 'ksdiluf';
	}) ))
end)
if not r then
	error(yaml.encode(e))
end
