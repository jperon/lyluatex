local function say(fmt, ...)
    texio.write_nl('term and log', '[test-miktex] ' .. string.format(fmt, ...))
end

local function capture(cmd)
    local opener = os.kpsepopen or io.popen
    if not opener then return nil end
    local ok, handle = pcall(opener, cmd, 'r')
    if not ok or not handle then return nil end
    local lines = {}
    local read_ok = pcall(function()
        for line in handle:lines() do lines[#lines + 1] = line end
    end)
    pcall(function() handle:close() end)
    if not read_ok then return nil end
    return lines
end

local function score_basename()
    local list = 'tmp-ly/' .. tex.jobname .. '.list'
    local handle = io.open(list, 'r')
    if not handle then return nil end
    local first = handle:read('*l')
    handle:close()
    return first and first:match('^%s*(%S+)')
end

local gs = os.type == 'windows' and 'gswin64c' or 'gs'

local base = score_basename()
if not base then
    tex.error('test-miktex: no score basename in tmp-ly/' .. tex.jobname .. '.list')
    return
end

local path = 'tmp-ly/' .. base .. '-1.pdf'
local size = lfs.attributes(path, 'size')
say('%s exists=%s size=%s', path, tostring(size ~= nil), tostring(size or '-'))

if not size then
    say('LilyPond wrote no per-system PDF, so the score falls back to the')
    say('EPS route, which cannot be converted on MiKTeX')
    tex.error('test-miktex: missing ' .. path)
    return
end

local version = capture(gs .. ' --version 2>&1') or {}
local gs_found = false
for _, line in ipairs(version) do
    if line:match('%d+%.%d+') then gs_found = true end
end
if not gs_found then
    say('%s not available; skipping the bounding box check', gs)
    return
end

local lines = capture(
    gs .. ' -sDEVICE=bbox -q -dBATCH -dNOPAUSE "' .. path .. '" 2>&1') or {}
local usable = false
for _, line in ipairs(lines) do
    say('    | %s', line)
    if line:find('HiResBoundingBox', 1, true)
        and not line:match('HiResBoundingBox:%s*0[%.0%s]*$')
    then usable = true end
end

if usable then
    say('per-system PDF is present and has a usable bounding box')
else
    say('the per-system PDF measures 0 0 0 0, so it carries no music')
    tex.error('test-miktex: blank per-system PDF ' .. path)
end
