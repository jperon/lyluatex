-- luacheck: ignore ly warn info log self luatexbase internalversion font fonts tex token kpse status
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
local optlib = {}  -- namespace for the returned table
local Opts = {options = {}}  -- Options class
Opts.__index = function (self, k) return self.options[k] or rawget(Opts, k) end
setmetatable(Opts, Opts)


function Opts:new(opt_prefix, declarations)
--[[
    Declare package options along with their default and
    accepted values. To *some* extent also provide type checking.
    - opt_prefix: the prefix/name by which the lyluatex-options module is
        referenced in the parent LaTeX document (preamble or package).
        This is required to write the code calling optlib.set_option into
        the option declaration.
    - declarations: a definition table stored in the calling module (see below)
    Each entry in the 'declarations' table represents one package option, with each
    value being an array (table with integer indexes instead of keys). For
    details please refer to the manual.
--]]
    local o = setmetatable(
        {
            declarations = declarations,
            options = {}
        },
        self
    )
    local exopt = ''
    for k, v in pairs(declarations) do
        o.options[k] = v[1] or ''
        tex.sprint(string.format([[
\DeclareOptionX{%s}{\directlua{
    %s:set_option('%s', '\luatexluaescapestring{#1}')
}}%%
]],
            k, opt_prefix, k
        ))
        exopt = exopt..k..'='..(v[1] or '')..','
    end
    tex.sprint([[\ExecuteOptionsX{]]..exopt..[[}%%]], [[\ProcessOptionsX]])
    return o
end

function Opts:check_local_options(opts, ignore_declarations)
--[[
    Parse the given options (options passed to a command/environment),
    sanitize them against the global package options and return a table
    with the local options that should then supersede the global options.
    If ignore_declaration is given any non-false value the sanitization
    step is skipped (i.e. local options are only parsed and duplicates
    rejected).
--]]
    local options = {}
    local next_opt = opts:gmatch('([^,]+)')  -- iterator over options
    for opt in next_opt do
        local k, v = opt:match('([^=]+)=?(.*)')
        if k then
            if v and v:sub(1, 1) == '{' then  -- handle keys with {multiple, values}
                while select(2, v:gsub('{', '')) ~= select(2, v:gsub('}', '')) do v = v..','..next_opt() end
                v = v:sub(2, -2)  -- remove { }
            end
            if not ignore_declarations then
                k, v = self:sanitize_option(k:gsub('^%s', ''), v:gsub('^%s', ''))
            end
            if k then
                if options[k] then err('Option %s is set two times for the same score.', k)
                else options[k] = v
                end
            end
        end
    end
    return options
end

function Opts:is_neg(k)
--[[
    Type check for a 'negative' option. This is an existing option
    name prefixed with 'no' (e.g. 'noalign')
--]]
    local _, i = k:find('^no')
    return i and lib.contains_key(self.declarations, k:sub(i + 1))
end

function Opts:sanitize_option(k, v)
--[[
    Check and (if necessary) adjust the value of a given option.
    Reject undefined options
    Check 'negative' options
    Handle boolean options (empty strings or 'false'), set them to real booleans
--]]
    local declarations = self.declarations
    if k == '' or k == 'noarg' then return end
    if not lib.contains_key(declarations, k) then err('Unknown option: '..k) end
    -- aliases
    if declarations[k] and declarations[k][2] == optlib.is_alias then
        if declarations[k][1] == v then return
        else k = declarations[k] end
    end
    -- boolean
    if v == 'false' then v = false end
    -- negation (for example, noindent is the negation of indent)
    if self:is_neg(k) then
        if v ~= nil and v ~= 'default' then
            k = k:gsub('^no(.*)', '%1')
            v = not v
        else return
        end
    end
    return k, v
end

function Opts:set_option(k, v)
--[[
    Set an option for the given prefix to be in effect from this point on.
    Raises an error if the option is not declared or does not meet the
    declared expectations. (TODO: The latter has to be integrated by extracting
    optlib.validate_option from optlib.validate_options and call it in
    sanitize_option).
--]]
    k, v = self:sanitize_option(k, v)
    if k then
        self.options[k] = v
        self:validate_option(k)
    end
end

function Opts:validate_option(key, options_obj)
--[[
    Validate an (already sanitized) option against its expected values.
    With options_obj a local options table can be provided,
    otherwise the global options stored in OPTIONS are checked.
--]]
    local package_opts = self.declarations
    local options = options_obj or self.options
    local unexpected
    if options[key] == 'default' then
        -- Replace 'default' with an actual value
        options[key] = package_opts[key][1]
        unexpected = options[key] == nil
    end
    if not lib.contains(package_opts[key], options[key]) and package_opts[key][2] then
        -- option value is not in the array of accepted values
        if type(package_opts[key][2]) == 'function' then package_opts[key][2](key, options[key])
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

function Opts:validate_options(options_obj)
--[[
    Validate the given set of options against the option declaration
    table for the given prefix.
    With options_obj a local options table can be provided,
    otherwise the global options stored in OPTIONS are checked.
--]]
    for k, _ in lib.orderedpairs(self.declarations) do
        self:validate_option(k, options_obj)
    end
end


function optlib.is_alias()
--[[
    This function doesn't do anything, but if an option is defined
    as an alias, its second parameter will be this function, so the
    test declarations[k][2] == optlib.is_alias in Opts:sanitize_options
    will return true.
--]]
end


function optlib.is_dim(k, v)
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


function optlib.is_neg(k, _)
--[[
    Type check for a 'negative' option. At this stage,
    we only check that it begins with 'no'.
--]]
    return k:find('^no')
end


function optlib.is_num(_, v)
--[[
    Type check for number options
--]]
    return v == '' or tonumber(v)
end


function optlib.is_str(_, v)
--[[
    Type check for string options
--]]
    return type(v) == 'string'
end


function optlib.merge_options(base_opt, super_opt)
--[[
    Merge two tables.
    Create a new table as a copy of base_opt, then merge with
    super_opt. Entries in super_opt supersede (i.e. overwrite)
    colliding entries in base_opt.
--]]
    local result = {}
    for k, v in pairs(base_opt) do result[k] = v end
    for k, v in pairs(super_opt) do result[k] = v end
    return result
end


optlib.Opts = Opts
return optlib
