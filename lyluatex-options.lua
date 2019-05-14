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

-----------------------------------------------------------
-- Functionality for handling package and local options
-- An options table has to be stored in the calling module
-- and passed into the functions.

function optlib.declare_package_options(options, obj_name)
    local exopt = ''
    for k, v in pairs(options) do
        tex.sprint(string.format([[
\DeclareOptionX{%s}{\directlua{
  %s.set_property('%s', '\luatexluaescapestring{#1}')
}}%%
]],
            k, obj_name, k
        ))
        exopt = exopt..k..'='..(v[1] or '')..','
    end
    tex.sprint([[\ExecuteOptionsX{]]..exopt..[[}%%]], [[\ProcessOptionsX]])
end


function optlib.is_alias() end


function optlib.is_dim(k, v)
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
    local _, i = k:find('^no')
    return i and lib.contains_key(options, k:sub(i + 1))
end


function optlib.sanitize_option(options, k, v)
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


return optlib
