-- luacheck: ignore ly log self luatexbase internalversion font fonts tex token kpse status
local err, warn, info, log = luatexbase.provides_module({
    name               = "lyluatex-lib",
    version            = '1.0b',  --LYLUATEX_VERSION
    date               = "2018/03/12",  --LYLUATEX_DATE
    description        = "Module lyluatex-lib.",
    author             = "The Gregorio Project  − (see Contributors.md)",
    copyright          = "2015-2019 - jperon and others",
    license            = "MIT",
})

local lib = {}
lib.OPTIONS = {} -- will be a reference to the caller's lib.OPTIONS object
lib.TEX_UNITS = {'bp', 'cc', 'cm', 'dd', 'in', 'mm', 'pc', 'pt', 'sp', 'em',
'ex'}


function lib.contains(table_var, value)
    for k, v in pairs(table_var) do
        if v == value then return k
        elseif v == 'false' and value == false then return k
        end
    end
end


function lib.contains_key(table_var, key)
    for k in pairs(table_var) do
        if k == key then return true end
    end
end


function lib.convert_unit(value)
    if not value then return 0
    elseif value == '' then return false
    elseif value:match('\\') then
        local n, u = value:match('^%d*%.?%d*'), value:match('%a+')
        if n == '' then n = 1 end
        return tonumber(n) * tex.dimen[u] / tex.sp("1pt")
    else return ('%f'):format(tonumber(value) or tex.sp(value) / tex.sp("1pt"))
    end
end


function lib.declare_package_options(options)
    lib.OPTIONS = options
    local exopt = ''
    for k, v in pairs(options) do
        tex.sprint(string.format([[
\DeclareOptionX{%s}{\directlua{
  ly.set_property('%s', '\luatexluaescapestring{#1}')
}}%%
]],
            k, k
        ))
        exopt = exopt..k..'='..(v[1] or '')..','
    end
    tex.sprint([[\ExecuteOptionsX{]]..exopt..[[}%%]], [[\ProcessOptionsX]])
end


function lib.dirname(str) return str:gsub("(.*/)(.*)", "%1") or '' end


local fontdata = fonts.hashes.identifiers
function lib.fontinfo(id) return fontdata[id] or font.fonts[id] end


function lib.is_alias() end


function lib.is_dim(k, v)
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


function lib.is_neg(k, _)
    local _, i = k:find('^no')
    return i and lib.contains_key(lib.OPTIONS, k:sub(i + 1))
end


function lib.max(a, b)
    a, b = tonumber(a), tonumber(b)
    if a > b then return a else return b end
end


function lib.min(a, b)
    a, b = tonumber(a), tonumber(b)
    if a < b then return a else return b end
end


function lib.mkdirs(str)
    local path
    if str:sub(1, 1) == '/' then path = '' else path = '.' end
    for dir in str:gmatch('([^%/]+)') do
        path = path .. '/' .. dir
        lfs.mkdir(path)
    end
end


function lib.orderedpairs(t)
    local key
    local i = 0
    local orderedIndex = {}
    for k in pairs(t) do table.insert(orderedIndex, k) end
    table.sort(orderedIndex)
    return function ()
            i = i + 1
            key = orderedIndex[i]
            if key then return key, t[key] end
        end
end


function lib.process_options(k, v)
    if k == '' or k == 'noarg' then return end
    if not lib.contains_key(lib.OPTIONS, k) then err('Unknown option: '..k) end
    -- aliases
    if lib.OPTIONS[k] and lib.OPTIONS[k][2] == lib.is_alias then
        if lib.OPTIONS[k][1] == v then return
        else k = lib.OPTIONS[k][1]
        end
    end
    -- boolean
    if v == 'false' then v = false end
    -- negation (for example, noindent is the negation of indent)
    if lib.is_neg(k) then
        if v ~= nil and v ~= 'default' then
            k = k:gsub('^no(.*)', '%1')
            v = not v
        else return
        end
    end
    return k, v
end


function lib.range_parse(range, nsystems)
    local num = tonumber(range)
    if num then return {num} end
    -- if nsystems is set, we have insert=systems
    if nsystems ~= 0 and range:sub(-1) == '-' then range = range..nsystems end
    if not (range == '' or range:match('^%d+%s*-%s*%d*$')) then
        warn([[
Invalid value '%s' for item
in list of page ranges. Possible entries:
- Single number
- Range (M-N, N-M or N-)
This item will be skipped!
]],
            range
        )
        return
    end
    local result = {}
    local from, to = tonumber(range:match('^%d+')), tonumber(range:match('%d+$'))
    if to then
        local dir
        if from <= to then dir = 1 else dir = -1 end
        for i = from, to, dir do table.insert(result, i) end
        return result
    else return {range}  -- N- with insert=fullpage
    end
end


function lib.readlinematching(s, f)
    if f then
        local result = ''
        while result and not result:find(s) do result = f:read() end
        f:close()
        return result
    end
end


function lib.splitext(str, ext)
  return str:match('(.*)%.'..ext..'$') or str
end


return lib
