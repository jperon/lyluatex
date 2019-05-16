-- luacheck: ignore ly log self luatexbase internalversion font fonts tex token kpse status
local err, warn, info, log = luatexbase.provides_module({
    name               = "lyluatex-options",
    version            = '1.0b',  --LYLUATEX_VERSION
    date               = "2018/03/12",  --LYLUATEX_DATE
    description        = "Module lyluatex-options.",
    author             = "The Gregorio Project  − (see Contributors.md)",
    copyright          = "2015-2019 - jperon and others",
    license            = "MIT",
})

--[[
    This module provides functionality to handle package options and make them
    configurable in a fine-grained fashion as
    - package options
    - local options (for individual instances of commands/environments)
    - changed “from here on” within a document.

-- ]]

local lib = require(kpse.find_file("lyluatex-lib.lua") or "lyluatex-lib.lua")
local optlib = {}  -- namespece for the returned table
local OPTIONS = {} -- store global options of any module using this


local function get_package_options(prefix)
--[[
    Returns a table with the package declaration and current option values
    vor the given prefix.
    Raises an error if given a prefix that hasn't been declared previously.
--]]
    local options = OPTIONS[prefix]
    if not options then
        err('No package declared with prefix '..prefix)
    end
    return options
end


function optlib.check_local_options(prefix, opts)
--[[
    Parse the given options (options passed to a command/environment),
    sanitize them against the global package options and return a table
    with the local options that should then supersede the global options.
--]]
    local options = {}
    local next_opt = opts:gmatch('([^,]+)')  -- iterator over options
    for opt in next_opt do
        local k, v = opt:match('([^=]+)=?(.*)')
        if k then
            if v and v:sub(1, 1) == '{' then  -- handle keys with {multiple, values}
                while v:sub(-1) ~= '}' do v = v..','..next_opt() end
                v = v:sub(2, -2)  -- remove { }
            end
            k, v = optlib.sanitize_option(prefix, k:gsub('^%s', ''), v:gsub('^%s', ''))
            if k then
                if options[k] then err('Option %s is set two times for the same score.', k)
                else options[k] = v
                end
            end
        end
    end
    return options
end


function optlib.declare_package_options(package_prefix, opt_prefix, declarations)
--[[
    Declare package options along with their default and
    accepted values. To *some* extent also provide type checking.
    - package_prefix: the prefix/name by which the calling Lua module is
      referenced in the parent LaTeX document (preamble or package).
      (Also used as the key in the OPTIONS table.)
    - opt_prefix: the prefix/name by which the lyluatex-options module is
      referenced in the parent LaTeX document (preamble or package).
      This is required to write the code calling optlib.set_option into
      the option declaration.
    - declarations: a definition table stored in the calling module (see below)

    Each entry in the 'declarations' table represents one package option, with each
    value being an array (table with integer indexes instead of keys). For
    details please refer to the manual.
--]]
    OPTIONS[package_prefix] = {
        declarations = declarations,
        options = {}
    }
    local exopt = ''
    for k, v in pairs(declarations) do
        OPTIONS[package_prefix]['options'][k] = v[1] or ''
        tex.sprint(string.format([[
\DeclareOptionX{%s}{\directlua{
  %s.set_option('%s', '%s', '\luatexluaescapestring{#1}')
}}%%
]],
            k, opt_prefix, package_prefix, k
        ))
        exopt = exopt..k..'='..(v[1] or '')..','
    end
    tex.sprint([[\ExecuteOptionsX{]]..exopt..[[}%%]], [[\ProcessOptionsX]])
end


function optlib.get_declarations(prefix)
--[[
    Return the table with the option declarations for the given package.
    Raises an error if the package hasn't previously been declared.
--]]
    return get_package_options(prefix)['declarations']
end


function optlib.get_options(prefix)
--[[
    Return the table with the current package options for the given package.
    Raises an error if the package hasn't previously been declared.
--]]
    return get_package_options(prefix)['options']
end


function optlib.get_option(prefix, key)
--[[
    Return the value of a given option in the selected package.
    Raises an error if the package hasn't previously been declared
    but returns nil if the option isn't present in the table.
--]]
    return optlib.get_options(prefix)[key]
end


function optlib.is_alias()
--[[
    Handling noop 'alias' options, for example to provide compatibility
    options. TODO: I don't really know how that works internally.
--]]
end


function optlib.is_dim(_, k, v)
--[[
    Type checking for options that accept a LaTeX dimension.
    This can be
    - a number (integer or float)
    - a number with unit
    - a (multiplied) TeX length
    (see error message in code for examples)
--]]
    if v == '' or v == false or tonumber(v) then return true end
    local n, sl, u = v:match('^%d*%.?%d*'), v:match('\\'), v:match('%a+')
    -- a value of number - backslash - length is a dimension
    -- invalid input will be prevented in by the LaTeX parser already
    if n and sl and u then return true end
    if n and lib.contains(lib.TEX_UNITS, u) then return true end
    err([[
Unexpected value "%s" for dimension %s:
should be either a number (for example "12"),
a number with unit, without space ("12pt"),
or a (multiplied) TeX length (".8\linewidth")
]],
        v, k
    )
end


function optlib.is_neg(prefix, k, v)
--[[
    Type check for a 'negative' option. This is an existing option
    name prefixed with 'no' (e.g. 'noalign')
--]]
    local _, i = k:find('^no')
    if not i then return false end
    local options = optlib.get_declarations(prefix)
    return lib.contains_key(options, k:sub(i + 1))
end


function optlib.is_num(_, _, v)
--[[
    Type check for number options
--]]
    return v == '' or tonumber(v)
end


function optlib.is_str(_, _, v)
--[[
    Type check for string options
--]]
    return type(v) == 'string'
end


function optlib.sanitize_option(prefix, k, v)
--[[
    Check and (if necessary) adjust the value of a given option.
    Reject undefined options
    Check 'negative' options
    Handle boolean options (empty strings or 'false'), set them to real booleans
--]]
    options = optlib.get_declarations(prefix)
    if k == '' or k == 'noarg' then return end
    if not lib.contains_key(options, k) then err('Unknown option: '..k) end
    -- aliases
    if options[k] and options[k][2] == optlib.is_alias then
        if options[k][1] == v then return
        else k = options[k] end
    end
    -- boolean
    if v == 'false' then v = false end
    -- negation (for example, noindent is the negation of indent)
    if optlib.is_neg(prefix, k, v) then
        if v ~= nil and v ~= 'default' then
            k = k:gsub('^no(.*)', '%1')
            v = not v
        else return
        end
    end
    return k, v
end


function optlib.set_option(prefix, k, v)
--[[
    Set an option for the given prefix to be in effect from this point on.
    Raises an error if the option is not declared or does not meet the
    declared expectations. (TODO: The latter has to be integrated by extracting
    optlib.validate_option from optlib.validate_options and call it in
    sanitize_option).
--]]
    k, v = optlib.sanitize_option(prefix, k, v)
    if k then
        optlib.get_options(prefix)[k] = v
        optlib.validate_option(prefix, k)
    end
end


function optlib.validate_option(prefix, key, options_obj)
--[[
    Validate an (already sanitized) option against its expected values.
    With options_obj a local options table can be provided,
    otherwise the global options stored in OPTIONS are checked.
--]]
    local package_opts = optlib.get_declarations(prefix)
    local options = options_obj or optlib.get_options(prefix)
    local unexpected
    if options[key] == 'default' then
        -- Replace 'default' with an actual value
        options[key] = package_opts[key][1]
        unexpected = options[key] == nil
    end
    if not lib.contains(package_opts[key], options[key]) and package_opts[key][2] then
        -- option value is not in the array of accepted values
        if type(package_opts[key][2]) == 'function' then package_opts[key][2](prefix, key, options[key])
        else unexpected = true
        end
    end
    if unexpected then
        err([[
  Unexpected value "%s" for option %s:
  authorized values are "%s"
  ]],
            options[key], key, table.concat(package_opts[key], ', ')
        )
    end
end


function optlib.validate_options(prefix, options_obj)
--[[
    Validate the given set of options against the option declaration
    table for the given prefix.
    With options_obj a local options table can be provided,
    otherwise the global options stored in OPTIONS are checked.
--]]
    local package_opts = optlib.get_declarations(prefix)
    for k, _ in lib.orderedpairs(package_opts) do
        optlib.validate_option(prefix, k, options_obj)
    end
end


return optlib
