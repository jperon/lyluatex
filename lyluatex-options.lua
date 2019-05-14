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

local optlib = {}
local lib = require(kpse.find_file("lyluatex-lib.lua") or "lyluatex-lib.lua")

--[[
    This module provides functionality to handle package options and make them
    configurable in a fine-grained fashion as
    - package options
    - local options (for individual instances of commands/environments)
    - changed “from here on” within a document.

-- ]]

function optlib.declare_package_options(options, prefix)
--[[
    Declare package options along with their default and
    accepted values. To *some* extent also provide type checking.
    - options: a definition table stored in the calling module (see below)
    - prefix: the prefix/name by which the calling Lua module is referenced
      in the parent LaTeX document (preamble or package)

    Each entry in the 'options' table represents one package option, with each
    value being an array (table with integer indexes instead of keys). For
    details please refer to the manual.
--]]
    local exopt = ''
    for k, v in pairs(options) do
        tex.sprint(string.format([[
\DeclareOptionX{%s}{\directlua{
  %s.set_property('%s', '\luatexluaescapestring{#1}')
}}%%
]],
            k, prefix, k
        ))
        exopt = exopt..k..'='..(v[1] or '')..','
    end
    tex.sprint([[\ExecuteOptionsX{]]..exopt..[[}%%]], [[\ProcessOptionsX]])
end


function optlib.is_alias()
--[[
    Handling noop 'alias' options, for example to provide compatibility
    options. TODO: I don't really know how that works internally.
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


function optlib.is_neg(options, k)
--[[
    Type check for a 'negative' option. This is an existing option
    name prefixed with 'no' (e.g. 'noalign')
--]]
    local _, i = k:find('^no')
    return i and lib.contains_key(options, k:sub(i + 1))
end


function optlib.sanitize_option(options, k, v)
--[[
    Check and (if necessary) adjust the value of a given option.
    Reject undefined options
    Check 'negative' options
    Handle boolean options (empty strings or 'false'), set them to real booleans
--]]
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
    if optlib.is_neg(options, k) then
        if v ~= nil and v ~= 'default' then
            k = k:gsub('^no(.*)', '%1')
            v = not v
        else return
        end
    end
    return k, v
end


function optlib.set_local_options(global_opts, local_opts)
--[[
    Parse the given local_opts (options passed to a command/environment),
    sanitize them and merge them into the global_opts, so local
    options supersede global ones without changing them.
    Return a table with the effective options to be used for the given
    element.
--]]
    local options = {}
    local next_opt = local_opts:gmatch('([^,]+)')  -- iterator over options
    for opt in next_opt do
        local k, v = opt:match('([^=]+)=?(.*)')
        if k then
            if v and v:sub(1, 1) == '{' then  -- handle keys with {multiple, values}
                while v:sub(-1) ~= '}' do v = v..','..next_opt() end
                v = v:sub(2, -2)  -- remove { }
            end
            k, v = optlib.sanitize_option(global_opts, k:gsub('^%s', ''), v:gsub('^%s', ''))
            if k then
                if options[k] then err('Option %s is set two times for the same score.', k)
                else options[k] = v
                end
            end
        end
    end
    return options
end


return optlib
