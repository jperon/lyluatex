local function say(fmt, ...)
    texio.write_nl('term and log', '[pipe-test] ' .. string.format(fmt, ...))
end

local function capture(opener, cmd)
    if not opener then return nil, 'not available in this engine' end
    local ok, handle = pcall(opener, cmd, 'r')
    if not ok then return nil, 'open raised: ' .. tostring(handle) end
    if not handle then return nil, 'open returned nil' end
    local lines = {}
    local read_ok, read_err = pcall(function()
        for line in handle:lines() do lines[#lines + 1] = line end
    end)
    pcall(function() handle:close() end)
    if not read_ok then return nil, 'read raised: ' .. tostring(read_err) end
    return lines
end

local function report(opener, name, cmd)
    local lines, reason = capture(opener, cmd)
    if not lines then
        say('%s -> %s', name, reason)
        return nil
    end
    say('%s -> %d line(s)', name, #lines)
    for _, line in ipairs(lines) do say('    | %s', line) end
    return lines
end

local function lilypond_pdf()
    if not lfs.isdir('tmp-ly') then return nil end
    for entry in lfs.dir('tmp-ly') do
        if entry:sub(-4) == '.pdf' and not entry:find('-clip') then
            return 'tmp-ly/' .. entry
        end
    end
end

local gs = os.type == 'windows' and 'gswin64c' or 'gs'

say('os.type=%s  os.name=%s', tostring(os.type), tostring(os.name))
say('os.kpsepopen=%s  io.popen=%s',
    tostring(os.kpsepopen ~= nil), tostring(io.popen ~= nil))

say('=== step 1: plain pipe, kpsewhich --version ===')
local kpse_lines = report(os.kpsepopen, 'os.kpsepopen', 'kpsewhich --version')
local io_lines = report(io.popen, 'io.popen', 'kpsewhich --version')

local pipe_works = (kpse_lines and #kpse_lines > 0)
    or (io_lines and #io_lines > 0)

say('=== step 1b: %s --version ===', gs)
local gs_lines = report(os.kpsepopen or io.popen, gs, gs .. ' --version 2>&1')
local gs_found = false
for _, line in ipairs(gs_lines or {}) do
    if line:match('%d+%.%d+') then gs_found = true end
end

say('=== step 2: bbox pipe on a LilyPond PDF ===')
local pdf = lilypond_pdf()
local bbox_lines
if not pdf then
    say('no LilyPond PDF found in tmp-ly; skipping')
else
    say('pdf=%s', pdf)
    bbox_lines = report(
        os.kpsepopen or io.popen,
        'bbox',
        gs .. ' -sDEVICE=bbox -q -dBATCH -dNOPAUSE "' .. pdf .. '" 2>&1'
    )
end

local has_bbox = false
for _, line in ipairs(bbox_lines or {}) do
    if line:find('HiResBoundingBox', 1, true) then has_bbox = true end
end

say('=== verdict ===')
say('pipe captures output : %s', tostring(pipe_works))
say('ghostscript on PATH  : %s', tostring(gs_found))
say('HiResBoundingBox     : %s', tostring(has_bbox))

if not pipe_works then
    say('case A: the Lua pipe captured nothing from kpsewhich')
    tex.error('test-pipe: Lua pipe captured no output (case A)')
elseif not gs_found then
    say('%s is not on PATH, so step 2 says nothing about either case', gs)
    tex.error('test-pipe: ' .. gs .. ' not found on PATH')
elseif not has_bbox then
    say('case B: pipe works, Ghostscript runs, no bounding box')
else
    say('pipe and Ghostscript both fine')
end
