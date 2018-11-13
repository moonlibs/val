# Value validator

This is very fast validator with abilities to perform complex cascade inplace structure changes and to raise custom API-like errros

## Usage

```
local val = require 'val'

local structure_validator = val.idator({
	req_num1 = 'number';
	req_num2 = '+number';
	req_num3 = 'req number';
	req_num4 = 'required number';
	req_num5 = val.req('number');
	req_num6 = val.required('number');

	opt_str1 = '?string';
	opt_str2 = 'opt string';
	opt_str3 = 'optional string';
	opt_str4 = 'maybe string';
	opt_str5 = val.opt('string');
	opt_str6 = val.optional('string');
	opt_str7 = val.maybe('string');

	custom_value = function(value, name)
		if type(value) == 'string' then
			if value:upper() ~= value then
				error({ 'invalid', name .. ' should be either uppercase string or positive number'})
			end
		elseif type(value) == 'number' then
			if value <= 0 then
				error({ 'invalid', name .. ' should be either uppercase string or positive number'})
			end
		else
			error({ 'invalid', name .. ' should be either uppercase string or positive number'})
		end

		return value
	end;

	nested = {
		nested_string = '+string';
		nested_number = '+number';
	};

	complex_cast_cascade = val.required(
		'number',
		tostring,
		'string',
		function(value, name)
			if value:len() % 2 ~= 0 then
				error({ 'invalid', name .. ' should be number, that can be written in odd amount of symbols' })
			end

			return tonumber(value)
		end,
		'number'
	);
})

-- does not raise
local r, e = pcall(structure_validator, {
	req_num1 = 1;
	req_num2 = 1;
	req_num3 = 1;
	req_num4 = 1;
	req_num5 = 1;
	req_num6 = 1;

	opt_str1 = 'some string';
	opt_str3 = 'some string';
	opt_str5 = 'some string';
	opt_str7 = 'some string';

	custom_value = 2;

	nested = {
		nested_string = 'some string';
		nested_number = 42;
	};

	complex_cast_cascade = 1234;
})

-- raises error "args.complex_cast_cascade is invalid with value 123: args.complex_cast_cascade should be number, that can be written in odd amount of symbols"
local r, e = pcall(structure_validator, {
	req_num1 = 1;
	req_num2 = 1;
	req_num3 = 1;
	req_num4 = 1;
	req_num5 = 1;
	req_num6 = 1;

	opt_str1 = 'some string';
	opt_str3 = 'some string';
	opt_str5 = 'some string';
	opt_str7 = 'some string';

	custom_value = 2;

	nested = {
		nested_string = 'some string';
		nested_number = 42;
	};

	complex_cast_cascade = 123;
})

print("Raised error: " .. e)

-- raises error "args.custom_value is invalid with value qwe: args.custom_value should be either uppercase string or positive number"
local r, e = pcall(structure_validator, {
	req_num1 = 1;
	req_num2 = 1;
	req_num3 = 1;
	req_num4 = 1;
	req_num5 = 1;
	req_num6 = 1;

	opt_str1 = 'some string';
	opt_str3 = 'some string';
	opt_str5 = 'some string';
	opt_str7 = 'some string';

	custom_value = 'qwe';

	nested = {
		nested_string = 'some string';
		nested_number = 42;
	};

	complex_cast_cascade = 1234;
})

print("Raised error: " .. e)

-- following forms are equivalent
local val1 = val.idator({ a = 'number' })
local val2 = val.validator({ a = 'number' })
local val3 = val({ a = 'number' })

-- you can pass both schema and custom error handlers
local validator_w_custom_handler = val.idator({
	num = 'number';
	str = 'string';

	custom = function(value, name)
		if not value then
			error({ 'custom', name .. ' should be something that casts to true in Lua' })
		end

		return value
	end;
}, {
	handler = function (key, value, err)
		local reason  = err[1]
		local message = err[2]
		if reason == 'invalid' then
			return { 400, {
				Code    = 'EnterpriseLikeBigCodeForInvalidArguments';
				Key     = key;
				Value   = value;
				Message = message;
			} }
		elseif reason == 'missing' then
			return { 400, {
				Code    = 'EnterpriseLikeBigCodeForMissingArgument';
				Key     = key;
				Value   = value;
				Message = message;
			} }
		else
			return { 500, {
				Code    = 'EnterpriseLikeBigCodeForInternalError';
				Debug   = message;
				Message = 'Internal Error';
			} }
		end
	end;
})

local r, e = pcall(validator_w_custom_handler, {
	num = 'some random string';
	str = 'some random string';

	custom = true;
})

print(string.format("Custom error handler raised error: %s", require 'json' .encode(e)))

local r, e = pcall(validator_w_custom_handler, {
	num = 100;

	custom = true;
})

print(string.format("Custom error handler raised error: %s", require 'json' .encode(e)))

local r, e = pcall(validator_w_custom_handler, {
	num = 100;
	str = 'qwe';

	custom = false;
})

print(string.format("Custom error handler raised error: %s", require 'json' .encode(e)))
```

## Known Bugs

- Incorrect validation for optional nested structures

## TODO list

- array-of primitive
- non-empty-string primitive
- any-number primitive
