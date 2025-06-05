-- luacheck: ignore ly log self luatexbase internalversion font fonts tex token kpse status ly_opts
local err, warn, info, log = luatexbase.provides_module({
    name               = "lyluatex",
    version            = '1.1.5',  --LYLUATEX_VERSION
    date               = "2023/04/18",  --LYLUATEX_DATE
    description        = "Module lyluatex.",
    author             = "The Gregorio Project  − (see Contributors.md)",
    copyright          = "2015-2023 - jperon and others",
    license            = "MIT",
})

local lib = require(kpse.find_file("luaoptions-lib.lua") or "luaoptions-lib.lua")
local ly_opts = lua_options.client('ly')

local md5 = require 'md5'
local lfs = require 'lfs'

local ly = {
    err = err,
    varwidth_available = kpse.find_file('varwidth.sty')
}
local Score = ly_opts.options
Score.__index = Score

local FILELIST
local DIM_OPTIONS = {
    'extra-bottom-margin',
    'extra-top-margin',
    'gutter',
    'hpadding',
    'indent',
    'leftgutter',
    'line-width',
    'max-protrusion',
    'max-left-protrusion',
    'max-right-protrusion',
    'rightgutter',
    'paperwidth',
    'paperheight',
    'voffset'
}
local HASHIGNORE = {
    'autoindent',
    'cleantmp',
    'do-not-print',
    'force-compilation',
    'hpadding',
    'max-left-protrusion',
    'max-right-protrusion',
    'print-only',
    'valign',
    'voffset'
}
local MXML_OPTIONS = {
    'absolute',
    'language',
    'lxml',
    'no-articulation-directions',
    'no-beaming',
    'no-page-layout',
    'no-rest-positions',
    'verbose',
}
local TEXINFO_OPTIONS = {'doctitle', 'nogettext', 'texidoc'}
local LY_HEAD = [[
%%File header
\version "<<<version>>>"
<<<language>>>
#(define inside-lyluatex #t)
#(set-global-staff-size <<<staffsize>>>)
<<<preamble>>>

\header {
    copyright = ""
    tagline = ##f
}
\paper{
    <<<paper>>>    two-sided = ##<<<twoside>>>
    line-width = <<<linewidth>>>\pt
    <<<indent>>>
    <<<raggedright>>>
    <<<fonts>>>
}
\layout{
    <<<staffprops>>>
    <<<fixbadlycroppedstaffgroupbrackets>>>
}<<<header>>>

%%Follows original score
]]


--[[ ========================== Helper functions ========================== --]]
-- dirty fix as info doesn't work as expected
local oldinfo = info
function info(...)
    print('\n(lyluatex)', string.format(...))
    oldinfo(...)
end
-- debug acts as info if [debug] is specified
local function debug(...)
    if Score.debug then info(...) end
end


local function extract_includepaths(includepaths)
    includepaths = includepaths:explode(',')

    local cfd
    if lib.tex_engine.dist == 'MiKTeX' then
        cfd = Score.currfiledir:gsub('^$', '.\\')
    else
        cfd = Score.currfiledir:gsub('^$', './')
    end

    table.insert(includepaths, 1, cfd)
    for i, path in ipairs(includepaths) do
        -- delete initial space (in case someone puts a space after the comma)
        includepaths[i] = path:gsub('^ ', ''):gsub('^~', os.getenv("HOME")):gsub('^%.%.', './..')
    end
    return includepaths
end


local function font_default_staffsize()
    return lib.current_font_size()/39321.6
end


local function includes_parse(list)
    local includes = ''
    if list then
        includes = [[

]]
        list = list:explode(',')
        for _, included_file in ipairs(list) do
            includes = includes .. '\\include "'..included_file..'.ly"\n'
        end
    end
    return includes
end


local function locate(file, includepaths, ext)
    local result
    for _, d in ipairs(extract_includepaths(includepaths)) do
        if d:sub(-1) ~= '/' then d = d..'/' end
        result = d..file
        if lfs.isfile(result) then break end
    end
    if not (result and lfs.isfile(result)) then
        if ext and file:match('%.[^%.]+$') ~= ext then
            return locate(file..ext, includepaths)
        else
            return kpse.find_file(file)
        end
    end
    return result
end


local function range_parse(range, nsystems)
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


local function set_lyscore(score)
    ly.score = score
    ly.score.nsystems = ly.score:count_systems()
    if score.insert ~= 'fullpage' then  -- systems and inline
        local hoffset = ly.score.protrusion or 0
        if hoffset == '' then hoffset = 0 end
        ly.score.hoffset = hoffset..'pt'
        for s = 1, ly.score.nsystems do
            table.insert(ly.score, ly.score.output..'-'..s)
        end
    else ly.score[1] = ly.score.output
    end
end


--[[ ================ Bounding box calculations =========================== --]]

function bbox_get(filename, line_width)
    return bbox_read(filename) or bbox_parse(filename, line_width)
end

function bbox_calc(x_1, x_2, y_1, y_2, line_width)
    local bb = {
        ['protrusion'] = -lib.convert_unit(("%fbp"):format(x_1)),
        ['r_protrusion'] = lib.convert_unit(("%fbp"):format(x_2)) - line_width,
        ['width'] = lib.convert_unit(("%fbp"):format(x_2))
    }
    --FIX #192: height is only calculated if really needed, to prevent errors with huge scores.
    function bb.__index(_, k)
        if k == 'height' then return lib.convert_unit(("%fbp"):format(y_2)) - lib.convert_unit(("%fbp"):format(y_1)) end
    end
    setmetatable(bb, bb)
    return bb
end

function bbox_parse(filename, line_width)
    -- get BoundingBox from EPS file
    local bbline = lib.readlinematching('^%%%%BoundingBox', io.open(filename..'.eps', 'r'))
    if not bbline then return end
    local x_1, y_1, x_2, y_2 = bbline:match('(%--%d+)%s(%--%d+)%s(%--%d+)%s(%--%d+)')
    -- try to get HiResBoundingBox from PDF (if 'gs' works)
    bbline = lib.readlinematching(
        '^%%%%HiResBoundingBox',
        io.popen('gs -sDEVICE=bbox -q -dBATCH -dNOPAUSE '..filename..'.pdf 2>&1', 'r')
    )
    if bbline then
        local pbb = bbline:gmatch('(%d+%.%d+)')
        -- The HiRes BoundingBox retrieved from the PDF differs from the
        -- BoundingBox present in the EPS file. In the PDF (0|0) is the
        -- Lower Left corner while in the EPS (0|0) represents the top
        -- edge at the start of the staff symbol.
        -- Therefore we shift the HiRes results by the (truncated)
        -- points of the EPS bounding box.
        x_1, y_1, x_2, y_2 = pbb() + x_1, pbb() + y_1, pbb() + x_1, pbb() + y_1
    else warn([[gs couldn't be launched; there could be rounding errors.]])
    end
    local f = io.open(filename .. '.bbox', 'w')
    f:write(
        string.format("return %f, %f, %f, %f, %f", x_1, y_1, x_2, y_2, line_width)
    )
    f:close()
    return bbox_calc(x_1, x_2, y_1, y_2, line_width)
end

function bbox_read(f)
    f = f .. '.bbox'
    if lfs.isfile(f) then
        local x_1, y_1, x_2, y_2, line_width = dofile(f)
        return bbox_calc(x_1, x_2, y_1, y_2, line_width)
    end
end


--[[ =============== Functions that output LaTeX code ===================== --]]

function latex_filename(printfilename, insert, input_file)
    if printfilename and input_file then
        if insert ~= 'systems' then
            warn('`printfilename` only works with `insert=systems`')
        else
            local filename = input_file:gsub("(.*/)(.*)", "\\lyFilename{%2}\\par")
            tex.sprint(filename)
        end
    end
end

function latex_fullpagestyle(style, ppn)
    local function texoutput(s) tex.sprint('\\includepdfset{pagecommand='..s..'}%') end
    if style == '' then
        if ppn then texoutput('\\thispagestyle{empty}')
        else texoutput('')
        end
    else texoutput('\\thispagestyle{'..style..'}')
    end
end

function latex_includeinline(pdfname, height, valign, hpadding, voffset)
    local v_base
    if valign == 'bottom' then v_base = 0
    elseif valign == 'top' then v_base = lib.convert_unit('1em') - height
    else v_base = (lib.convert_unit('1em') - height) / 2
    end
    tex.sprint(
        string.format(
            [[\hspace{%fpt}\raisebox{%fpt}{\includegraphics{%s-1}}\hspace{%fpt}]],
            hpadding, v_base + voffset, pdfname, hpadding
        )
    )
end

function latex_includepdf(pdfname, range, papersize)
    tex.sprint(string.format(
        [[\includepdf[pages={%s},%s]{%s}]],
        table.concat(range, ','), papersize and 'noautoscale' or '', pdfname
    ))
end

function latex_includesystems(filename, range, protrusion, gutter, staffsize, indent_offset)
    local h_offset = protrusion + indent_offset
    local texoutput = '\\ifx\\preLilyPondExample\\undefined\\else\\preLilyPondExample\\fi\n'
    texoutput = texoutput..'\\par\n'
    for index, system in pairs(range) do
        if not lfs.isfile(filename..'-'..system..'.eps') then break end
        texoutput = texoutput..
            string.format([[
\noindent\hspace*{%fpt}\includegraphics{%s}%%
]],
                h_offset + gutter, filename..'-'..system
            )
        if index < #range then
            texoutput = texoutput..
                string.format([[
\ifx\betweenLilyPondSystem\undefined\par\vspace{%fpt plus %fpt minus %fpt}%%
\else\betweenLilyPondSystem{%s}\fi%%
]],
                    staffsize / 4, staffsize / 12, staffsize / 16,
                    index
                )
        end
    end
    texoutput = texoutput..'\n\\ifx\\postLilyPondExample\\undefined\\else\\postLilyPondExample\\fi'
    tex.sprint(texoutput:explode('\n'))
end

function latex_label(label, labelprefix)
    if label then tex.sprint('\\label{'..labelprefix..label..'}%%') end
end


ly.verbenv = {[[\begin{verbatim}]], [[\end{verbatim}]]}
function latex_verbatim(verbatim, ly_code, intertext, version)
    if verbatim then
        if version then tex.sprint('\\lyVersion{'..version..'}') end
        local content = table.concat(ly_code:explode('\n'), '\n'):gsub(
            '.*%%%s*begin verbatim', ''):gsub(
            '%%%s*end verbatim.*', '')
        --[[ We unfortunately need an external file,
             as verbatim environments are quite special. --]]
        local fname = ly_opts.tmpdir..'/verb.tex'
        local f = io.open(fname, 'w')
        f:write(
            ly.verbenv[1]..'\n'..
            content..
            '\n'..ly.verbenv[2]:gsub([[\end {]], [[\end{]])..'\n'
        )
        f:close()
        tex.sprint('\\input{'..fname..'}')
        if intertext then tex.sprint('\\lyIntertext{'..intertext..'}') end
    end
end


--[[ =============================== Classes =============================== --]]

-- Score class
function Score:new(ly_code, options, input_file)
    local o = options or {}
    setmetatable(o, self)
    o.output_names = {}
    o.input_file = input_file
    o.ly_code = ly_code
    return o
end

function Score:bbox(system)
    if system then
        if not self.bboxes then
            self.bboxes = {}
            for i = 1, self:count_systems() do
                table.insert(self.bboxes, bbox_get(self.output..'-'..i, self['line-width']))
            end
        end
        return self.bboxes[system]
    else
        if not self.bbox then self.bbox = bbox_get(self.output, self['line-width']) end
        return self.bbox
    end
end

function Score:calc_properties()
    self:calc_staff_properties()
    -- add includes to lilypond code
    self.ly_code = includes_parse(self.include_before_body)
        .. self.ly_code
        .. includes_parse(self.include_after_body)
    -- fragment and relative
    if self.relative and not self.fragment then
        -- local option takes precedence over global option
        if Score.fragment then self.relative = false end
    end
    if self.relative then
        self.fragment = 'true'  -- yes, here we need a string, not a bool
        if self.relative == '' then self.relative = 1
        else self.relative = tonumber(self.relative)
        end
    end
    if self.fragment == '' then
        -- by default, included files shouldn't be fragments
        if ly.state == 'file' then self.fragment = false end
    end
    -- default insertion mode
    if self.insert == '' then
        if ly.state == 'cmd' then self.insert = 'inline'
        else self.insert = 'systems'
        end
    end
    -- staffsize
    self.staffsize = tonumber(self.staffsize)
    if self.staffsize == 0 then self.staffsize = font_default_staffsize() end
    if self.insert == 'inline' or self.insert == 'bare-inline' then
        local inline_staffsize = tonumber(self['inline-staffsize'])
        if inline_staffsize == 0 then inline_staffsize = self.staffsize / 1.5 end
        self.staffsize = inline_staffsize
    end
    -- dimensions that can be given by LaTeX
    for _, dimension in pairs(DIM_OPTIONS) do
        self[dimension] = lib.convert_unit(self[dimension])
    end
    self['max-left-protrusion'] = self['max-left-protrusion'] or self['max-protrusion']
    self['max-right-protrusion'] = self['max-right-protrusion'] or self['max-protrusion']
    if self.quote then
        self.leftgutter = self.leftgutter or self.gutter
        self.rightgutter = self.rightgutter or self.gutter
        self['line-width'] = self['line-width'] - self.leftgutter - self.rightgutter
    else
        self.leftgutter = 0
        self.rightgutter = 0
    end
    -- store for comparing protrusion against
    self.original_lw = self['line-width']
    self.original_indent = self.indent
    -- explicit indent disables autoindent
    if self.indent then self.autoindent = false end
    -- score fonts
    if self['current-font-as-main'] then self.rmfamily = self['current-font'] end
    -- LilyPond version
    if self.addversion then self.addversion = self:lilypond_version(true) end
    -- temporary file name
    self.output = self:output_filename()
end

function Score:calc_range()
    local nsystems = self:count_systems(true)
    local printonly, donotprint = self['print-only'], self['do-not-print']
    if printonly == '' then printonly = '1-' end
    local result = tonumber(printonly) and {tonumber(printonly)} or {}
    if not result[1] then
        for _, r in pairs(printonly:explode(',')) do
            local range = range_parse(r:gsub('^%s', ''):gsub('%s$', ''), nsystems)
            if range then
                for _, v in pairs(range) do table.insert(result, v) end
            end
        end
    end
    local rm_result = tonumber(donotprint) and {tonumber(donotprint)} or {}
    if not rm_result[1] then
        for _, r in pairs(donotprint:explode(',')) do
            local range = range_parse(r:gsub('^%s', ''):gsub('%s$', ''), nsystems)
            if range then
                for _, v in pairs(range) do table.insert(rm_result, v) end
            end
        end
    end
    for _, v in pairs(rm_result) do
        local k = lib.contains(result, v)
        if k then table.remove(result, k) end
    end
    return result
end

function Score:calc_staff_properties()
    -- preset for bare notation symbols in inline images
    if self.insert == 'bare-inline' then self.nostaff = 'true' end
    -- handle meta properties
    if self.notime then
        self.notimesig = 'true'
        self.notiming = 'true'
    end
    if self.nostaff then
        self.nostaffsymbol = 'true'
        self.notimesig = 'true'
        -- do *not* suppress timing
        self.noclef = 'true'
    end
end

function Score:check_compilation()
    local debug_msg, doc_debug_msg
    if self.debug then
        debug_msg = string.format([[
Please check the log file
and the generated LilyPond code in
%s
%s
]],
            self.output..'.log', self.output..'.ly'
        )
        doc_debug_msg = [[
A log file and a LilyPond file have been written.\\
See log for details.]]
    else
        debug_msg = [[
If you need more information
than the above message,
please retry with option debug=true.
]]
        doc_debug_msg = "Re-run with \\texttt{debug} option to investigate."
    end
    if self.fragment then
        local frag_msg = '\n'..[[
As the input code has been automatically wrapped
with a music expression, you may try repeating
with the `nofragment` option.]]
        debug_msg = debug_msg..frag_msg
        doc_debug_msg = doc_debug_msg..frag_msg
    end

    if self:is_compiled() then
        if self.lilypond_error then
            warn([[

LilyPond reported a failed compilation but
produced a score. %s
]],
                debug_msg
            )
        end
        -- we do have *a* score (although labeled as failed by LilyPond)
        return true
    else
        self:clean_failed_compilation()
        if self.showfailed then
            tex.sprint(string.format([[
\begin{quote}
\minibox[frame]{LilyPond failed to compile a score.\\
%s}
\end{quote}

]],
                doc_debug_msg
            ))
            warn([[

LilyPond failed to compile the score.
%s
]],
                debug_msg
            )
        else
            err([[

LilyPond failed to compile the score.
%s
]],
                debug_msg
            )
        end
        -- We don't have any compiled score
        return false
    end
end

function Score:check_indent(lp)
    local nsystems = self:count_systems()

    local function handle_autoindent()
        self.indent_offset = 0
        if lp.shorten > 0 then
            if not self.indent or self.indent == 0 then
                self.indent = lp.overflow_left
                lp.shorten = lib.max(lp.shorten - lp.overflow_left, 0)
            else
                self.indent = lib.max(self.indent - lp.overflow_left, 0)
            end
            lp.changed_indent = true
        end
    end

    local function handle_indent()
        if not self.indent_offset then
            -- First step: deactivate indent
            self.indent_offset = 0
            if self:count_systems() > 1 then
                -- only recompile if the *original* score has more than 1 system
                self.indent = 0
                lp.changed_indent = true
            end
            info('Deactivate indentation because of system selection')
        elseif lp.shorten > 0 then
                self.indent = 0
                self.autoindent = true
                -- lp.changed_indent = true
                handle_autoindent()
                info('Deactivated indent causes protrusion.')
        end
    end

    local function regular_score()
        -- score without any indent or with the first system
        -- printed regularly, with others following.
        return not self.original_indent or
            nsystems > 1 and  #self.range > 1 and self.range[1] == 1
    end

    local function simple_noindent()
        -- score with indent and only one system
        return self.original_indent and nsystems == 1
    end

    if simple_noindent() then
        self.indent_offset = -self.indent
        warn('Deactivate indent for single-system score.')
    elseif self.autoindent then handle_autoindent()
    elseif regular_score() then self.indent_offset = 0
    else handle_indent()
    end
end

function Score:check_properties()
    ly_opts:validate_options(self)
    for _, k in pairs(TEXINFO_OPTIONS) do
        if self[k] then info([[Option %s is specific to Texinfo: ignoring it.]], k) end
    end
    if self.fragment then
        if (self.input_file or
            self.ly_code:find([[\book]]) or
            self.ly_code:find([[\header]]) or
            self.ly_code:find([[\layout]]) or
            self.ly_code:find([[\paper]]) or
            self.ly_code:find([[\score]])
        ) then
            warn([[
Found something incompatible with `fragment`
(or `relative`). Setting them to false.
]]
            )
            self.fragment = false
            self.relative = false
        end
    end
end

function Score:check_protrusion(bbox_func)
    self.range = self:calc_range()
    if self.insert ~= 'systems' then return self:is_compiled() end
    local bb = bbox_func(self.output, self['line-width'])
    if not bb then return end
    -- line_props lp
    local lp = {}
    -- Determine offset due to left protrusion
    lp.overflow_left = lib.max(bb.protrusion - math.floor(self['max-left-protrusion']), 0)
    self.protrusion_left = lp.overflow_left - bb.protrusion
    -- Determine further line properties
    lp.stave_extent = lp.overflow_left + lib.min(self['line-width'], bb.width)
    lp.available = self.original_lw + self['max-right-protrusion']
    lp.total_extent = lp.stave_extent + bb.r_protrusion
    -- Check if stafflines protrude into the right margin after offsetting
    -- Note: we can't *reliably* determine this with ragged one-system scores,
    -- possibly resulting in unnecessarily short lines when right protrusion is
    -- present
    lp.stave_overflow_right = lib.max(lp.stave_extent - self.original_lw, 0)
    -- Check if image as a whole protrudes over max-right-protrusion
    lp.overflow_right = lib.max(lp.total_extent - lp.available, 0)
    lp.shorten = lib.max(lp.stave_overflow_right, lp.overflow_right)
    lp.changed_indent = false
    self:check_indent(lp, bb)
    if lp.shorten > 0 or lp.changed_indent then
        self['line-width'] = self['line-width'] - lp.shorten
        -- recalculate hash to reflect the reduced line-width
        if lp.shorten > 0 then
            info('Compiled score exceeds protrusion limit(s)')
        end
        if lp.changed_indent then info([[Adjusted indent.]]) end
        self.output = self:output_filename()
        warn('Recompile or reuse cached score')
        return
    else return true
    end
end

function Score:clean_failed_compilation()
    for file in lfs.dir(self.tmpdir) do
        local filename = self.tmpdir..'/'..file
        if filename:find(self.output) then os.remove(filename) end
    end
end

function Score:content()
    local n = ''
    local ly_code = self.ly_code
    if self.relative then
        self.fragment = 'true'  -- in case it would serve later
        if self.relative < 0 then
            for _ = -1, self.relative, -1 do n = n..',' end
        elseif self.relative > 0 then
            for _ = 1, self.relative do n = n.."'" end
        end
        return string.format([[\relative c%s {%s}]], n, ly_code)
    elseif self.fragment then return [[{]]..ly_code..[[}]]
    else return ly_code
    end
end

function Score:count_systems(force)
    local count = self.system_count
    if force or not count then
        count = 0
        local systems = self.output:match("[^/]*$").."%-%d+%.eps"
        for f in lfs.dir(self.tmpdir) do
            if f:match(systems) then
                count = count + 1
            end
        end
        self.system_count = count
    end
    return count
end

function Score:delete_intermediate_files()
    for _, filename in pairs(self.output_names) do
        if self.insert == 'fullpage' then os.remove(filename..'.ps')
        else
            os.remove(filename..'-systems.tex')
            os.remove(filename..'-systems.texi')
            os.remove(filename..'.eps')
        end
    end
end

function Score:flatten_content(ly_code)
    --[[ Produce a flattend string from the original content,
        including referenced files (if they can be opened.
        Other files (from LilyPond's include path) are considered
        irrelevant for the purpose of a hashsum.) --]]

    -- Replace percent signs with another character that doesn't
    -- meddle with Lua's gsub escape character.
    ly_code = ly_code:gsub('%%', '#')
    local f
    local includepaths = self.includepaths..','..self.tmpdir
    if self.input_file then includepaths = self.includepaths..','..lib.dirname(self.input_file) end
    for iline in ly_code:gmatch('\\include%s*"[^"]*"') do
        f = io.open(locate(iline:match('\\include%s*"([^"]*)"'), includepaths, '.ly') or '')
        if f then
            ly_code = ly_code:gsub(iline, self:flatten_content(f:read('*a')))
            f:close()
        end
    end
    return ly_code
end

function Score:footer()
    return includes_parse(self.include_footer)
end

function Score:header()
    local header = LY_HEAD
    for element in LY_HEAD:gmatch('<<<(%w+)>>>') do
        header = header:gsub('<<<'..element..'>>>', self['ly_'..element](self) or '')
    end
    local wh_dest = self['write-headers']
    if wh_dest then
        if self.input_file then
            local _, ext = lib.splitext(wh_dest)
            local header_file = ext and wh_dest
                or wh_dest..'/'..lib.splitext(lib.basename(self.input_file), 'ly').."-lyluatex-headers.ily"
            lib.mkdirs(lib.dirname(header_file))
            local f = io.open(header_file, 'w')
            f:write(header
                :gsub([[%\include "lilypond%-book%-preamble.ly"]], '')
                :gsub([[%#%(define inside%-lyluatex %#t%)]], '')
                :gsub('\n+', '\n')
            )
            f:close()
        else
            warn([[Ignoring 'write-headers' for non-file score.]])
        end
    end
    return header
end

function Score:is_compiled()
    if self['force-compilation'] then return false end
    return lfs.isfile(self.output..'.pdf') or lfs.isfile(self.output..'.eps') or self:count_systems(true) ~= 0
end

function Score:is_odd_page() return tex.count['c@page'] % 2 == 1 end

function Score:lilypond_cmd()
    local input, mode = '-s -', 'w'
    if self.debug or lib.tex_engine.dist == 'MiKTeX' then
        local f = io.open(self.output..'.ly', 'w')
        f:write(self.complete_ly_code)
        f:close()
        input = self.output..".ly 2>&1"
        mode = 'r'
    end
    local cmd = '"'..self.program..'" '
        .. (self.insert == "fullpage" and "" or "-E ")
        .. "-dno-point-and-click -djob-count=2 -dno-delete-intermediate-files "
    if self:lilypond_version() >= ly.v{2, 24} then cmd = cmd.."-dtall-page-formats=pdf " end
    if self['optimize-pdf'] and self:lilypond_has_TeXGS() then cmd = cmd.."-O TeX-GS -dgs-never-embed-fonts " end
    if self.input_file then
        cmd = cmd..'-I "'..lib.dirname(self.input_file):gsub('^%./', lfs.currentdir()..'/')..'" '
    end
    for _, dir in ipairs(extract_includepaths(self.includepaths)) do
        cmd = cmd..'-I "'..dir:gsub('^%./', lfs.currentdir()..'/')..'" '
    end
    cmd = cmd..'-o "'..self.output..'" '..input
    debug("Command:\n"..cmd)
    return cmd, mode
end

function Score:lilypond_has_TeXGS()
    return lib.readlinematching('TeX%-GS', io.popen('"'..self.program..'" --help', 'r'))
end

function Score:lilypond_version()
    local version = self._lilypond_version
    if not version then
        version = lib.readlinematching('GNU LilyPond', io.popen('"'..self.program..'" --version', 'r'))
        info(
            "Compiling score %s with LilyPond executable '%s'.",
            self.output, self.program
        )
        if not version then return end
        version = ly.v{version:match('(%d+)%.(%d+)%.?(%d*)')}
        debug("VERSION " .. tostring(version))
        self._lilypond_version = version
    end
    return version
end

function Score:ly_fixbadlycroppedstaffgroupbrackets()
    return self.fix_badly_cropped_staffgroup_brackets and [[\context {
        \Score
        \override SystemStartBracket.after-line-breaking =
        #(lambda (grob)
            (let ((Y-off (ly:grob-property grob 'Y-extent)))
                (ly:grob-set-property! grob 'Y-extent
                  (cons (- (car Y-off) 1.7) (+ (cdr Y-off) 1.7)))))
    }]]
    or '%% no fix for badly cropped StaffGroup brackets'
end

function Score:ly_fonts()
    if self['pass-fonts'] then
        local fonts_def
        if self:lilypond_version() >= ly.v{2, 25, 6} then
            fonts_def = [[
property-defaults.fonts.serif = "%s"
property-defaults.fonts.sans = "%s"
property-defaults.fonts.typewriter = "%s"]]
        elseif self:lilypond_version() >= ly.v{2, 25, 5} then
            fonts_def = [[
fonts.serif = "%s"
fonts.sans = "%s"
fonts.typewriter = "%s"]]
        elseif self:lilypond_version() >= ly.v{2, 25, 4} then
            fonts_def = [[
fonts.roman = "%s"
fonts.sans = "%s"
fonts.typewriter = "%s"]]
        else
            fonts_def = [[
#(define fonts
    (make-pango-font-tree "%s"
                          "%s"
                          "%s"
                          (/ staff-height pt 20)))
]]
        end
        return fonts_def:format(self.rmfamily, self.sffamily, self.ttfamily)
    else
        return '%% fonts not set'
    end
end

function Score:ly_header()
    return includes_parse(self.include_header)
end

function Score:ly_indent()
    if not (self.indent == false and self.insert == 'fullpage') then
        return [[indent = ]]..(self.indent or 0)..[[\pt]]
    else
        return '%% no indent set'
    end
end

function Score:ly_language()
    if self.language then return '\\language "'..self.language..'"'..[[

]]
    else return '' end
end

function Score:ly_linewidth() return self['line-width'] end

function Score:ly_staffsize() return self.staffsize end

function Score:ly_margins()
    local horizontal_margins =
        self.twoside and string.format([[
            inner-margin = %f\pt]], self:tex_margin_inner())
        or string.format([[
            left-margin = %f\pt]], self:tex_margin_left())

    local tex_top = self['extra-top-margin'] + self:tex_margin_top()
    local tex_bottom = self['extra-bottom-margin'] + self:tex_margin_bottom()
    if self.fullpagealign == 'crop' then
        return string.format([[
    top-margin = %f\pt
    bottom-margin = %f\pt
    %s]],
            tex_top, tex_bottom, horizontal_margins
        )
    elseif self.fullpagealign == 'staffline' then
        local top_distance = 4 * tex_top / self.staffsize + 2
        local bottom_distance = 4 * tex_bottom / self.staffsize + 2
        return string.format([[
    top-margin = 0\pt
    bottom-margin = 0\pt
    %s
    top-system-spacing =
    #'((basic-distance . %f)
        (minimum-distance . %f)
        (padding . 0)
        (stretchability . 0))
    top-markup-spacing =
    #'((basic-distance . %f)
        (minimum-distance . %f)
        (padding . 0)
        (stretchability . 0))
    last-bottom-spacing =
    #'((basic-distance . %f)
        (minimum-distance . %f)
        (padding . 0)
        (stretchability . 0))
]],
            horizontal_margins,
            top_distance,
            top_distance,
            top_distance,
            top_distance,
            bottom_distance,
            bottom_distance
        )
    else
        err([[
Invalid argument for option 'fullpagealign'.
Allowed: 'crop', 'staffline'.
Given: %s
]],
            self.fullpagealign
        )
    end
end

function Score:ly_paper()
    local system_count =
        self['system-count'] == '0' and ''
        or 'system-count = '..self['system-count']..'\n    '

    local papersize = '#(set-paper-size "'..(self.papersize or 'lyluatexfmt')..'")'
    if self.insert == 'fullpage' then
        local first_page_number = self['first-page-number'] or tex.count['c@page']
        local pfpn = self['print-first-page-number'] and 't' or 'f'
        local ppn = self['print-page-number'] and 't' or 'f'
        return string.format([[
    %s%s
    print-page-number = ##%s
    print-first-page-number = ##%s
    first-page-number = %d
%s]],
            system_count, papersize, ppn, pfpn,
            first_page_number, self:ly_margins()
	    )
    else
        return string.format([[%s%s]], papersize..[[

]], system_count)
    end
end

function Score:ly_preamble()
    local result = string.format(
        [[#(set! paper-alist (cons '("lyluatexfmt" . (cons (* %f pt) (* %f pt))) paper-alist))]],
        self.paperwidth, self.paperheight
    )
    if self.insert == 'fullpage' then
        return result
    else
        return result..[[


\include "lilypond-book-preamble.ly"]]
    end
end

function Score:ly_raggedright()
    if self['ragged-right'] ~= 'default' then
        if self['ragged-right'] then return 'ragged-right = ##t'
        else return 'ragged-right = ##f'
        end
    else
        return '%% no alignment set'
    end
end

function Score:ly_staffprops()
    local clef, timing, timesig, staff =
        '%% no clef set',
        '    %% timing not suppressed',
        '    %% no time signature set',
        '    %% staff symbol not suppressed'
    if self.noclef then clef = [[\context { \Staff \remove "Clef_engraver" }]] end
    if self.notiming then timing = [[\context { \Score timing = ##f }]] end
    if self.notimesig then timesig = [[\context { \Staff \remove "Time_signature_engraver" }]] end
    if self.nostaffsymbol then staff = [[\context { \Staff \remove "Staff_symbol_engraver" }]] end
    return string.format('%s\n%s\n%s\n%s', clef, timing, timesig, staff)
end

function Score:ly_twoside() if self.twoside then return 't' else return 'f' end end

function Score:ly_version() return self['ly-version'] end

function Score:optimize_pdf()
    if not self['optimize-pdf'] then return end
    if self:lilypond_has_TeXGS() and not ly.final_optimization_message then
        ly.final_optimization_message = true
        luatexbase.add_to_callback(
            'stop_run',
            function()
                info(
                    [[Optimization enabled: remember to run
                    'gs -q -dBATCH -dNOPAUSE -sDEVICE=pdfwrite -sOutputFile=%s %s'.]],
                    tex.jobname..'-final.pdf', tex.jobname..'.pdf'
                )
            end,
            'lyluatex optimize-pdf'
        )
    else
        local pdf2ps, ps2pdf, path
        for file in lfs.dir(self.tmpdir) do
            path = self.tmpdir..'/'..file
            if path:match(self.output) and path:sub(-4) == '.pdf' then
                pdf2ps = io.popen(
                    'gs -q -sDEVICE=ps2write -sOutputFile=- -dNOPAUSE '..path..' -c quit',
                    'r'
                )
                ps2pdf = io.popen(
                    'gs -q -dBATCH -dNOPAUSE -sDEVICE=pdfwrite -sOutputFile='..path..'-gs -',
                    'w'
                )
                if pdf2ps then
                    ps2pdf:write(pdf2ps:read('*a'))
                    pdf2ps:close()
                    ps2pdf:close()
                    os.rename(path..'-gs', path)
                else
                    warn(
                        [[You have asked for pdf optimization, but gs wasn't found.]]
                    )
                end
            end
        end
    end
end

function Score:output_filename()
    local properties = ''
    for k, _ in lib.orderedpairs(ly_opts.declarations) do
        if (not lib.contains(HASHIGNORE, k)) and self[k] and type(self[k]) ~= 'function' then
            properties = properties..'\n'..k..'\t'..self[k]
        end
    end
    if self.insert == 'fullpage' then
        properties = properties..
            self:tex_margin_top()..self:tex_margin_bottom()..
            self:tex_margin_left()..self:tex_margin_right()
    end
    local filename = md5.sumhexa(self:flatten_content(self.ly_code)..properties)
    return self.tmpdir..'/'..filename
end

function Score:process()
    self:check_properties()
    self:calc_properties()
    if not self:lilypond_version() then
        local warning = [[
LilyPond could not be started.
Please check that LuaLaTeX is started with the
--shell-escape option, and that 'program'
points to a valid LilyPond executable.
]]
        if self.showfailed then
            warn(warning)
            tex.sprint(string.format([[
\begin{quote}
\minibox[frame]{LilyPond could not be started.}
\end{quote}

]]))
            return
        else
            err(warning)
        end
    end
    -- with bbox_read check_protrusion will only execute with
    -- a prior compilation, otherwise it will be ignored
    local do_compile = not self:check_protrusion(bbox_read)
    if self['force-compilation'] or do_compile then
        repeat
            self.complete_ly_code = self:header()..self:content()..self:footer()
            self:run_lilypond()
            self['force-compilation'] = false
            if self:is_compiled() then table.insert(self.output_names, self.output)
            else
                self:clean_failed_compilation()
                break
            end
        until self:check_protrusion(bbox_get)
        self:optimize_pdf()
    else table.insert(self.output_names, self.output)
    end
    set_lyscore(self)
    if self:count_systems() == 0 then
        warn([[
The score doesn't contain any music:
this will probably cause bad output.]]
        )
    end
    if not self['raw-pdf'] then self:write_latex(do_compile) end
    self:write_to_filelist()
    if not self.debug then self:delete_intermediate_files() end
end

function Score:run_lily_proc(p)
        if self.debug then
            local f = io.open(self.output..".log", 'w')
            f:write(p:read('*a'))
            f:close()
        else p:write(self.complete_ly_code)
        end
        return p:close()
    end

function Score:run_lilypond()
    if self:is_compiled() then return end
    lib.mkdirs(lib.dirname(self.output))
    if not self:run_lily_proc(io.popen(self:lilypond_cmd(self.complete_ly_code))) and not self.debug then
        self.debug = true
        self.lilypond_error = not self:run_lily_proc(io.popen(self:lilypond_cmd(self.complete_ly_code)))
    end
    local lilypond_pdf, mode = self:lilypond_cmd(self.complete_ly_code)
    if lilypond_pdf:match"-E" then
        lilypond_pdf = lilypond_pdf:gsub(" %-E", " --pdf")
        self:run_lily_proc(io.popen(lilypond_pdf, mode))
    end
end

function Score:tex_margin_bottom()
    self._tex_margin_bottom = self._tex_margin_bottom or
        lib.convert_unit(tex.dimen.paperheight..'sp')
        - self:tex_margin_top()
        - lib.convert_unit(tex.dimen.textheight..'sp')
    return self._tex_margin_bottom
end

function Score:tex_margin_inner()
    self._tex_margin_inner = self._tex_margin_inner or
        lib.convert_unit((
            tex.sp('1in') + tex.dimen.oddsidemargin + tex.dimen.hoffset
        )..'sp')
    return self._tex_margin_inner
end

function Score:tex_margin_outer()
    self._tex_margin_outer = self._tex_margin_outer or
        lib.convert_unit((tex.dimen.paperwidth - tex.dimen.textwidth)..'sp')
        - self:tex_margin_inner()
    return self._tex_margin_outer
end

function Score:tex_margin_left()
    if self:is_odd_page() or not self.twopage then return self:tex_margin_inner()
    else return self:tex_margin_outer()
    end
end

function Score:tex_margin_right()
    if self:is_odd_page() or not self.twopage then return self:tex_margin_outer()
    else return self:tex_margin_inner()
    end
end

function Score:tex_margin_top()
    self._tex_margin_top = self._tex_margin_top or
        lib.convert_unit((
            tex.sp('1in') + tex.dimen.voffset + tex.dimen.topmargin
            + tex.dimen.headheight + tex.dimen.headsep
        )..'sp')
    return self._tex_margin_top
end

function Score:write_latex(do_compile)
    latex_filename(self.printfilename, self.insert, self.input_file)
    latex_verbatim(self.verbatim, self.ly_code, self.intertext, self.addversion)
    if do_compile and not self:check_compilation() then return end
    --[[ Now we know there is a proper score --]]
    latex_fullpagestyle(self.fullpagestyle, self['print-page-number'])
    latex_label(self.label, self.labelprefix)
    if self.insert == 'fullpage' then
        latex_includepdf(self.output, self.range, self.papersize)
    elseif self.insert == 'systems' then
        latex_includesystems(
            self.output, self.range, self.protrusion_left,
            self.leftgutter, self.staffsize, self.indent_offset
        )
    else  -- inline
        if self:count_systems() > 1 then
            warn([[
Score with more than one system included inline.
This will probably cause bad output.]]
            )
        end
        local bb = self:bbox(1)
        if bb then
            latex_includeinline(
                self.output, bb.height, self.valign, self.hpadding, self.voffset
            )
        end
    end
end

function Score:write_to_filelist()
    local f = io.open(FILELIST, 'a')
    for _, file in pairs(self.output_names) do
        local _, filename = file:match('(./+)(.*)')
        f:write(filename, '\t', self.input_file or '', '\t', self.label or '', '\n')
    end
    f:close()
end


--[[ ========================== Public functions ========================== --]]


function ly.buffenv_begin()

    function ly.buffenv(line)
        table.insert(ly.score_content, line)
        if line:find([[\end{%w+}]]) then return end
        return ''
    end

    ly.score_content = {}
    luatexbase.add_to_callback('process_input_buffer', ly.buffenv, 'readline')
end


function ly.buffenv_end()
    luatexbase.remove_from_callback('process_input_buffer', 'readline')
    table.remove(ly.score_content)
end


function ly.clean_tmp_dir()
    local hash, file_is_used
    local hash_list = {}
    for file in lfs.dir(Score.tmpdir) do
        if file:sub(-5, -1) == '.list' then
            local i = io.open(Score.tmpdir..'/'..file)
            for _, line in ipairs(i:read('*a'):explode('\n')) do
                hash = line:explode('\t')[1]
                if hash ~= '' then table.insert(hash_list, hash) end
            end
            i:close()
        end
    end
    for file in lfs.dir(Score.tmpdir) do
        if file ~= '.' and file ~= '..' and file:sub(-5, -1) ~= '.list' then
            for _, lhash in ipairs(hash_list) do
                file_is_used = file:find(lhash)
                if file_is_used then break end
            end
            if not file_is_used then os.remove(Score.tmpdir..'/'..file) end
        end
    end
end


function ly.conclusion_text()
    info([[
Output written on %s.pdf.
Transcript written on %s.log.
]],
        tex.jobname, tex.jobname
    )
end


function ly.make_list_file()
    local tmpdir = ly_opts.tmpdir
    lib.mkdirs(tmpdir)
    FILELIST = tmpdir..'/'..lib.splitext(status.log_name, 'log')..'.list'
    os.remove(FILELIST)
end

function ly.file(input_file, options)
    --[[ Here, we only take in account global option includepaths,
    as it really doesn't mean anything as a local option. --]]
    local file = locate(input_file, Score.includepaths, '.ly')
    options = ly_opts:check_local_options(options)
    if not file then err("File %s doesn't exist.", input_file) end
    local i = io.open(file, 'r')
    ly.score = Score:new(i:read('*a'), options, file)
    i:close()
end


function ly.file_musicxml(input_file, options)
    --[[ Here, we only take in account global option includepaths,
    as it really doesn't mean anything as a local option. --]]
    local file = locate(input_file, Score.includepaths, '.xml')
    options = ly_opts:check_local_options(options)
    if not file then err("File %s doesn't exist.", input_file) end
    local xmlopts = ''
    for _, opt in pairs(MXML_OPTIONS) do
        if options[opt] ~= nil then
            if options[opt] then xmlopts = xmlopts..' --'..opt
                if options[opt] ~= 'true' and options[opt] ~= '' then
                    xmlopts = xmlopts..' '..options[opt]
                end
            end
        elseif ly_opts[opt] then xmlopts = xmlopts..' --'..opt
        end
    end
    local i = io.popen(ly_opts.xml2ly..' --out=-'..xmlopts..' "'..file..'"', 'r')
    if not i then
        err([[
%s could not be started.
Please check that LuaLaTeX is started with the
--shell-escape option.
]],
            ly_opts.xml2ly
        )
    end
    ly.score = Score:new(i:read('*a'), options, file)
    i:close()
end


function ly.fragment(ly_code, options)
    options = ly_opts:check_local_options(options)
    if type(ly_code) == 'string' then
        ly_code = ly_code:gsub('\\par ', '\n'):gsub('\\([^%s]*) %-([^%s])', '\\%1-%2')
    else ly_code = table.concat(ly_code, '\n')
    end
    ly.score = Score:new(ly_code, options)
end


function ly.get_font_family(font_id)
    local ft = lib.fontinfo(font_id)
    if ft.shared.rawdata then return ft.shared.rawdata.metadata.familyname
    else
        warn([[
Some useful informations aren’t available:
you probably loaded polyglossia
before defining the main font, and we have
to "guess" the font’s familyname.
If the text of your scores looks weird,
you should consider using babel instead,
or at least loading polyglossia
after defining the main font.
]])
        return ft.fullname:match("[^-]*")
    end
end


function ly.newpage_if_fullpage()
    if ly.score.insert == 'fullpage' then tex.sprint([[\newpage]]) end
end


function ly.set_fonts(rm, sf, tt)
    if ly.score.rmfamily..ly.score.sffamily..ly.score.ttfamily ~= '' then
        ly.score['pass-fonts'] = 'true'
        info("At least one font family set explicitly. Activate 'pass-fonts'")
    end
    if ly.score.rmfamily == '' then ly.score.rmfamily = ly.get_font_family(rm)
    else
        -- if explicitly set don't override rmfamily with 'current' font
        if ly.score['current-font-as-main'] then
            info("rmfamily set explicitly. Deactivate 'current-font-as-main'")
        end
        ly.score['current-font-as-main'] = false
    end
    if ly.score.sffamily == '' then ly.score.sffamily = ly.get_font_family(sf) end
    if ly.score.ttfamily == '' then ly.score.ttfamily = ly.get_font_family(tt) end
end


do
    local _ = {}
    function _:__sub(other)
        for i = 1, lib.max(#self, #other) do
            local diff = (self[i] or 0) - (other[i] or 0)
            if diff ~= 0 then return diff, i end
        end
        return 0
    end
    function _:__eq(other) return self - other == 0 end
    function _:__lt(other) return self - other < 0 end
    function _:__call(v)
        for i = 1, #v do v[i] = tonumber(v[i]) end
        return setmetatable(v, self)
    end
    function _:__tostring() return table.concat(self, ".") end
    ly.v = setmetatable(_, _)
end


function ly.write_to_file(file, content)
    local f = io.open(Score.tmpdir..'/'..file, 'w')
    if not f then err('Unable to write to file %s', file) end
    f:write(content)
    f:close()
end

return ly
