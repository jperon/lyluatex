local function say(fmt, ...)
    texio.write_nl('term and log', '[test-miktex] ' .. string.format(fmt, ...))
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

local function score_basename()
    local list = 'tmp-ly/' .. tex.jobname .. '.list'
    local handle = io.open(list, 'r')
    if not handle then
        say('no %s', list)
        return nil
    end
    local first = handle:read('*l')
    handle:close()
    return first and first:match('^%s*(%S+)')
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

if not pipe_works then
    say('=== verdict ===')
    say('case A: the Lua pipe captured nothing from kpsewhich')
    tex.error('test-miktex: Lua pipe captured no output (case A)')
    return
end

local is_miktex = false
for _, line in ipairs(kpse_lines or io_lines or {}) do
    if line:find('MiKTeX', 1, true) then is_miktex = true end
end
local forced = os.getenv('LYLUATEX_PIPE_TEST_FORCE') ~= nil
say('distribution is MiKTeX : %s%s', tostring(is_miktex),
    forced and ' (forced)' or '')

if not (is_miktex or forced) then
    say('=== verdict ===')
    say('pipe works; skipping the bounding box stage, which targets MiKTeX')
    return
end

say('=== step 2: %s --version ===', gs)
local gs_lines = report(os.kpsepopen or io.popen, gs, gs .. ' --version 2>&1')
local gs_found = false
for _, line in ipairs(gs_lines or {}) do
    if line:match('%d+%.%d+') then gs_found = true end
end

if not gs_found then
    say('=== verdict ===')
    say('%s is not on PATH, so step 3 says nothing', gs)
    tex.error('test-miktex: ' .. gs .. ' not found on PATH')
    return
end

say('=== step 3: bounding box per candidate name ===')
local base = score_basename()
local results = {}
if not base then
    say('no score basename found; cannot test any path')
else
    say('basename=%s', base)
    local candidates = {
        {label = 'whole score', name = base .. '.pdf'},
        {label = 'per system', name = base .. '-1.pdf'},
        {label = 'epstopdf output', name = base .. '-1-eps-converted-to.pdf'},
    }
    for _, candidate in ipairs(candidates) do
        local path = 'tmp-ly/' .. candidate.name
        local size = lfs.attributes(path, 'size')
        local exists = size ~= nil
        say('--- %s: %s (exists=%s, size=%s)',
            candidate.label, path, tostring(exists), tostring(size or '-'))
        local entry = {
            label = candidate.label, path = path, exists = exists,
            size = size, bbox = false, blank = false,
        }
        if exists then
            local lines = report(
                os.kpsepopen or io.popen,
                'bbox',
                gs .. ' -sDEVICE=bbox -q -dBATCH -dNOPAUSE "' .. path .. '" 2>&1'
            )
            for _, line in ipairs(lines or {}) do
                if line:find('HiResBoundingBox', 1, true) then
                    if line:match('HiResBoundingBox:%s*0[%.0%s]*$') then
                        entry.blank = true
                    else
                        entry.bbox = true
                    end
                end
            end
        end
        results[#results + 1] = entry
    end
end

local function first_system_eps(prefix)
    if not lfs.isdir('tmp-ly') then return nil end
    for entry in lfs.dir('tmp-ly') do
        if entry:sub(-4) == '.eps' and entry:find(prefix, 1, true)
            and entry:match('%-%d+%.eps$')
        then return 'tmp-ly/' .. entry end
    end
end

say('=== step 4: converting an EPS ourselves (options 1 and 2) ===')
local probe_ok, probe_size = false, nil
local eps = base and first_system_eps(base)
if not eps then
    say('no per-system EPS found; skipping')
else
    local out = 'tmp-ly/probe-gs.pdf'
    os.remove(out)
    say('eps=%s', eps)
    report(os.kpsepopen or io.popen, 'pdfwrite',
        gs .. ' -q -dBATCH -dNOPAUSE -dEPSCrop -sDEVICE=pdfwrite -sOutputFile="'
        .. out .. '" "' .. eps .. '" 2>&1')
    probe_size = lfs.attributes(out, 'size')
    if not probe_size then
        say('%s wrote no file', gs)
    else
        local lines = report(os.kpsepopen or io.popen, 'bbox',
            gs .. ' -sDEVICE=bbox -q -dBATCH -dNOPAUSE "' .. out .. '" 2>&1')
        for _, line in ipairs(lines or {}) do
            if line:find('HiResBoundingBox', 1, true)
                and not line:match('HiResBoundingBox:%s*0[%.0%s]*$')
            then probe_ok = true end
        end
    end
end

say('=== verdict ===')
say('pipe captures output : %s', tostring(pipe_works))
say('ghostscript on PATH  : %s', tostring(gs_found))
local any_exists, any_bbox, any_blank = false, false, false
for _, entry in ipairs(results) do
    say('%-16s exists=%-5s size=%-8s bbox=%-5s blank=%s',
        entry.label, tostring(entry.exists), tostring(entry.size or '-'),
        tostring(entry.bbox), tostring(entry.blank))
    any_exists = any_exists or entry.exists
    any_bbox = any_bbox or entry.bbox
    any_blank = any_blank or entry.blank
end
if any_blank then
    say('a converted PDF measures 0 0 0 0, matching issue 332: epstopdf')
    say('writes the file but its content is empty')
end

say('%-16s ok=%-5s size=%s', 'direct gs', tostring(probe_ok),
    tostring(probe_size or '-'))
if probe_ok then
    say('options 1 and 2 are viable: gs converts this EPS itself')
else
    say('options 1 and 2 would not help: gs cannot convert this EPS either')
end

if not any_exists then
    say('neither candidate exists, so lyluatex has no PDF to measure')
    tex.error('test-miktex: no candidate PDF found for ' .. tostring(base))
elseif not any_bbox then
    say('a PDF exists but Ghostscript yields no usable bounding box')
else
    say('pipe, Ghostscript and bounding box all fine')
end
