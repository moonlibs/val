local yaml = require 'yaml'
yaml.cfg{ encode_use_tostring = true }

local ffi = require'ffi'
local val = require 'val'

local testno = 0
local failed = 0

local function ok (r, name)
	testno = testno+1
	name = name or "test"
	if r then
		print(string.format("ok %d - %s", testno, name))
	else
		failed = failed + 1
		print(string.format("not ok %d - %s", testno, name))
		print(string.format("#\tError: %s",e))
	end
end

local function is (v1, v2, name)
	testno = testno+1
	name = name or "test"
	if v1 == v2 then
		print(string.format("ok %d - %s", testno, name))
	else
		failed = failed + 1
		print(string.format("not ok %d - %s", testno, name))
		print(string.format("#\tError: %s is not %s", v1, v2))
	end
end

local function summary()
	print(string.format("%d..%d",testno,testno))
	if failed > 0 then
		print(string.format("# Looks like you failed %d test of %d.",failed,testno))
	end
end

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
		{ "number",          { -2^31, -1, 0, 1, 0.5, 2/3, 2^31 }, { "","test", 1LL, 1ULL, {}, function() end, true, false } },
		{ "string",          { "", "test" },                      { 1, 1LL, 1ULL, {}, function() end, true, false } },
		{ "table",           { {}, {x=1} },                       { "", "test", 1, 1LL, 1ULL, function() end, true, false } },
		{ "function",        { function() end },                  { "", "test", 1, 1LL, 1ULL, {}, true, false } },
		{ "boolean",         { true, false },                     { "", "test", 1, 1LL, 1ULL, {}, function() end } },
		{ "cdata",           { 1LL, 1ULL },                       { "", 1, {}, function() end } },
		{ "ctype<uint64_t>", { 1ULL },                            { "",1, 1LL, {}, function() end } },
		{ "ctype<int64_t>",  { 1LL },                             { "",1, 1ULL, {}, function() end } },
	}) do
		local typename, positive, negative = unpack(test)
		local constraint;
		local constraint_name;
		if type(typecheck) == 'table' then
			if #typecheck == 1 then
				local method = unpack(typecheck)
				constraint_name = "val."..method.."("..typename..")"
				constraint = val[method](typename)
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
			local vv = val({ test = n_cons });
		
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
	end
end

local dummy      = function (v) return v end
local noret      = function (v) return   end
local custom_err = function (v) error{'wrong', 'myerrormessage'} end

v_test_not_ok(
	val(
		{ test = custom_err }
	),
	{ test = 1 },
	function(e)
		-- print("#",e)
		return e:match("wrong") and e:match("myerrormessage")
	end,
	"required function negative: custom error"
)

v_test_not_ok(
	val(
		{ test = noret }
	),
	{ test = 1 },
	function(e)
		return e:match("invalid") and e:match("after 1 cast")
	end,
	"required function negative: noreturn"
)

v_test_ok(
	val(
		{ test = { inner = dummy } }
	),
	{ test = { inner = "test" }},
	"required function nested positive"
)

v_test_not_ok(
	val(
		{ test = { inner = custom_err } }
	),
	{ test = { inner = "test" }},
	function(e)
		return e:match("test%.inner") and e:match("wrong") and e:match("myerrormessage")
	end,
	"required function nested negative: custom error"
)

v_test_not_ok(
	val(
		{ test = { inner = noret }}
	),
	{ test = { inner = "test" }},
	"required function nested negative: noreturn"
)

v_test_ok(
	val(
		{ test = { inner = val.req(dummy, 'string', dummy, 'string') }}
	),
	{ test = { inner = "test" }},
	"required function nested positive: cascade"
)

v_test_not_ok(
	val(
		{ test = { inner = val.req(dummy, 'string', noret) }}
	),
	{ test = { inner = "test" }},
	function(e)
		return e:match("test%.inner") and e:match("invalid") and e:match("after 2 cast")
	end,
	"required function nested negative: cascade noreturn"
)

v_test_ok(
	val(
		{ test = { inner = val.req(dummy, 'string', function (v) return 1 end, 'number') }}
	),
	{ test = { inner = "test" }},
	"required function nested positive: cascade with changing type"
)

v_test_not_ok(
	val(
		{ test = { inner = val.req(dummy, 'string', function (v) return {} end, 'number') }}
	),
	{ test = { inner = "test" }},
	function(e)
		return e:match("test%.inner") and e:match("invalid") and e:match("after 2 cast")
	end,
	"required function nested negative: cascade with changing type"
)

local json = require 'json'

local custom_handler = function(key_check, value_check, error_check, name)
	name = name or "custom handler test"
	return function (k, v, e)
		if type(key_check) == 'function' then
			ok(key_check(k), string.format("'%s' correct key in custom handler", name))
		else
			is(k, key_check, string.format("'%s' correct key in custom handler", name))
		end

		if type(value_check) == 'function' then
			ok(value_check(v), string.format("'%s' correct value in custom handler", name))
		else
			is(v, value_check, string.format("'%s' correct value in custom handler", name))
		end

		if type(error_check) == 'function' then
			ok(error_check(e), string.format("'%s' correct error in custom handler", name))
		else
			is(e[1], error_check[1], string.format("'%s' correct error reason in custom handler", name))
			is(e[2], error_check[2], string.format("'%s' correct error message in custom handler", name))
		end
		error(e)
	end
end

local function custom_handler_test (schema, to_test, key_check, value_check, err_check, name)
	local vv = val(schema, {
		handler = custom_handler(key_check, value_check, err_check, name)
	})

	local r, e = pcall(vv, to_test)
	if r then
		ok(false, string.format("'%s' did not raise", name))
	end
end

custom_handler_test(
	{ a = 'string' },
	{ a = 1 },
	'args.a',
	1,
	function(e)
		return e[1] == 'invalid' and e[2]:match('got number') and e[2]:match('expected string')
	end,
	"custom handler for normal errors"
)

custom_handler_test(
	{ inner = { a = 'string' } },
	{ inner = { a = 1 } },
	'args.inner.a',
	1,
	function(e)
		return e[1] == 'invalid' and e[2]:match('got number') and e[2]:match('expected string')
	end,
	"custom handler for normal errors, nested"
)

custom_handler_test(
	{ a = custom_err },
	{ a = 1 },
	'args.a',
	1,
	function(e)
		return e[1] == 'wrong' and e[2]:match('myerrormessage')
	end,
	"custom handler for custom errors"
)

custom_handler_test(
	{ inner = { a = custom_err } },
	{ inner = { a = 1 } },
	'args.inner.a',
	1,
	function(e)
		return e[1] == 'wrong' and e[2]:match('myerrormessage')
	end,
	"custom handler for custom errors: nested"
)

local v = val.idator({
	ull    = 'ctype<uint64_t>';
	string = '?string';
	number = val.required(
		'number',
		function(v, name)
			if v < 0 then
				error{ 'CustomInvalid', name..' must be positive'; shit="happens" }
			end
			return v
		end,
		'number'
	);
	number2 = val.required(
		'number',
		function(v,name) return ffi.typeof('uint64_t')(v) --[[return v]] end,
		'ctype<uint64_t>',
		function(v,name) return tostring(v) end,
		'string'
	);
	nested = {
		string = val.req('string');
		number = val.opt('number');
	};
	['x-req-id'] = 'string';
},{
	handler = function(name,value,err)
		error(box.tuple.new{ 500, { Code=err[1]; ArgumentName=name; ArgumentValue=value; Debug = err[2] } })
	end;
})

local r,e = pcall(v, {
	string = "test";
	number = 1;
	number2 = 1;
	ull = 1ull;
	nested = {
		string = 'qwe';
		number = 1;
	};
	['x-req-id'] = 'ksdiluf';
})
ok(r, "complex validator positive")

local r,e = pcall(v, {
	string = "test";
	number = -1;
	number2 = 1;
	ull = 1ull;
	nested = {
		string = 'qwe';
		number = 1;
	};
	['x-req-id'] = 'ksdiluf';
})

ok(not r, "complex validator negative")
if not r then
	local status, err = e[1], e[2]
	is(status,           500,                            "complex validator correct custom error 1")
	is(err.Code,         'CustomInvalid',                "complex validator correct custom error 2")
	is(err.Debug,        'args.number must be positive', "complex validator correct custom error 3")
	is(err.ArgumentName, 'args.number',                  "complex validator correct custom error 4")
	is(err.ArgumentValue, -1,                            "complex validator correct custom error 5")
end

summary()

do return end
