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
lib.TEX_UNITS = {'bp', 'cc', 'cm', 'dd', 'in', 'mm', 'pc', 'pt', 'sp', 'em',
'ex'}

-------------------------
-- General tool functions

function lib.contains(table_var, value)
--[[
  Returns the key if the given table contains the given value, or nil.
  A value of 'false' (string) is considered equal to false (Boolean).
--]]
    for k, v in pairs(table_var) do
        if v == value then return k
        elseif v == 'false' and value == false then return k
        end
    end
end


function lib.contains_key(table_var, key)
-- Returs true if the given key is present in the table, nil otherwise.
    for k in pairs(table_var) do
        if k == key then return true end
    end
end


function lib.convert_unit(value)
--[[
  Convert a LaTeX unit, if possible.
  TODO: Understand what this *really* does, what is accepted and returned.
--]]
    if not value then return 0
    elseif value == '' then return false
    elseif value:match('\\') then
        local n, u = value:match('^%d*%.?%d*'), value:match('%a+')
        if n == '' then n = 1 end
        return tonumber(n) * tex.dimen[u] / tex.sp("1pt")
    else return ('%f'):format(tonumber(value) or tex.sp(value) / tex.sp("1pt"))
    end
end


function lib.dirname(str)
--[[
  Return the left part of a string up to and including the last slash.
  If no slash is present (no path components) return an empty string
--]]
    return str:gsub("(.*/)(.*)", "%1") or ''
end


local fontdata = fonts.hashes.identifiers
function lib.fontinfo(id)
--[[
  Return a LuaTeX font object based on the given ID
--]]
    return fontdata[id] or font.fonts[id]
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
