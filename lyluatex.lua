-- luacheck: ignore ly log self luatexbase internalversion font fonts tex kpse status
local err, warn, info, log = luatexbase.provides_module({
    name               = "lyluatex",
    version            = '0',
    date               = "2018/02/02",
    description        = "Module lyluatex.",
    author             = "The Gregorio Project  − Jacques Peron <cataclop@hotmail.com>",
    copyright          = "2008-2018 - The Gregorio Project",
    license            = "MIT",
})

local md5 = require 'md5'
local lfs = require 'lfs'

local ly = {}
local latex = {}

local FILELIST
local OPTIONS = {}
local DIM_OPTIONS = {
    'extra-bottom-margin',
    'extra-top-margin',
    'gutter',
    'indent',
    'leftgutter',
    'rightgutter',
    'line-width',
    'paperwidth',
    'paperheight',
    'protrusion'
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
local TEX_UNITS = {'bp', 'cc', 'cm', 'dd', 'in', 'mm', 'pc', 'pt', 'sp'}
local LY_HEAD = [[
%%File header
\version "<<<VERSION>>>"
<<<LANGUAGE>>>

<<<PREAMBLE>>>

#(define inside-lyluatex #t)
#(set-global-staff-size <<<STAFFSIZE>>>)

\header {
    copyright = ""
    tagline = ##f
}
\paper{
    <<<PAPER>>>
    <<<PAPERSIZE>>>
    two-sided = ##<<<TWOSIDE>>>
    line-width = <<<LINEWIDTH>>>\pt
    <<<INDENT>>>
    <<<RAGGEDRIGHT>>>
    <<<FONTS>>>
}
\layout{
    <<<STAFFPROPS>>>
}

%%Follows original score
]]
local Score = {}


--[[ ========================== Helper functions ========================== ]]
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


local function contains(table_var, value)
    for _, v in pairs(table_var) do
        if v == value then return true
        elseif v == 'false' and value == false then return true
        end
    end
end


local function contains_key(table_var, key)
    for k in pairs(table_var) do
        if k == key then return true end
    end
end


local function convert_unit(value)
    if not value then return 0
    elseif value == '' then return false
    elseif value:match('\\') then
        local n, u = value:match('^%d*%.?%d*'), value:match('%a+')
        if n == '' then n = 1 end
        return tonumber(n) * tex.dimen[u] / tex.sp("1pt")
    else
        return tonumber(value) or tex.sp(value) / tex.sp("1pt")
    end
end


local function dirname(str)
    return str:gsub("(.*/)(.*)", "%1") or ''
end


local function extract_includepaths(includepaths)
    includepaths = includepaths:explode(',')
    if Score.currfiledir == '' then Score.currfiledir = './' end
    table.insert(includepaths, 1, Score.currfiledir)
    for i, path in ipairs(includepaths) do
        -- delete initial space (in case someone puts a space after the comma)
        includepaths[i] = path:gsub('^ ', ''):gsub('^~', os.getenv("HOME"))
    end
    return includepaths
end


local fontdata = fonts.hashes.identifiers
local function fontinfo(id)
    return fontdata[id] or font.fonts[id]
end


local function locate(file, includepaths, ext)
    local result
    for _, d in ipairs(extract_includepaths(includepaths)) do
        if d:sub(-1) ~= '/' then d = d..'/' end
        result = d..file
        if lfs.isfile(result) then break end
    end
    if not lfs.isfile(result) then result = kpse.find_file(file) end
    if not result and ext and file:match('%.[^%.]+$') ~= ext then return locate(file..ext, includepaths) end
    return result
end


local function mkdirs(str)
    local path = '.'
    for dir in string.gmatch(str, '([^%/]+)') do
        path = path .. '/' .. dir
        lfs.mkdir(path)
    end
end


local function __genorderedindex(t)
    local orderedIndex = {}
    for key in pairs(t) do
        table.insert(orderedIndex, key)
    end
    table.sort( orderedIndex )
    return orderedIndex
end
local function __orderednext(t, state)
    local key = nil
    if state == nil then
        t.__orderedIndex = __genorderedindex(t)
        key = t.__orderedIndex[1]
    else
        for i = 1, #t.__orderedIndex do
            if t.__orderedIndex[i] == state then
                key = t.__orderedIndex[i+1]
            end
        end
    end
    if key then
        return key, t[key]
    end
    t.__orderedIndex = nil
    return
end
local function orderedpairs(t)
    return __orderednext, t, nil
end


local function process_options(k, v)
    -- aliases
    if OPTIONS[k] and OPTIONS[k][2] == ly.is_alias then
        if OPTIONS[k][1] == v then return
        else k = OPTIONS[k][1]
        end
    end
    -- boolean
    if v == 'false' then v = false end
    -- negation (for example, noindent is the negation of indent)
    if ly.is_neg(k) then
        if v ~= nil and v ~= 'default' then
            k = k:gsub('^no(.*)', '%1')
            v = not v
        else
            return
        end
    end
    return k, v
end


local function range_parse(range, nsystems)
    local num = tonumber(range)
    if num then return {num} end
    -- if nsystems is set, we have insert=systems
    if range:sub(-1) == '-' then range = range..nsystems end
    if not range:match('^%d+%s*-%s*%d*$') then
        warn([[
Invalid value '%s' for item
in list of page ranges. Possible entries:
- Single number
- Range (M-N, N-M or N-)
This item will be skipped!
      ]], range)
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


local function splitext(str, ext)
    if str:match(".-%..-") then
        local name = string.gsub(str, "(.*)(%." .. ext .. ")", "%1")
        return name
    else
        return str
    end
end


--[[ =============== Functions that output LaTeX code ===================== ]]

function latex.filename(score)
    if score.printfilename and score.input_file then
        if score.insert == 'fullpage' then
            warn('`printfilename` ignored with `insert=fullpage`')
        else
            local filename = score.input_file:gsub("(.*/)(.*)", "\\lyFilename{%2}\\par")
            tex.sprint(filename)
        end
    end
end

function latex.fullpagestyle(score)
    local function texoutput(s) tex.print('\\includepdfset{pagecommand='..s..'}') end
    if score.fullpagestyle == '' then
        if score['print-page-number'] then
            texoutput('\\thispagestyle{empty}')
        else texoutput('')
        end
    else texoutput('\\thispagestyle{'..score.fullpagestyle..'}')
    end
end

function latex.includepdf(score)
    if score.caption ~= '' then warn([[Captions are not supported with
fullpage scores.]]) end
    local noautoscale = ''
    if score.papersize then noautoscale = 'noautoscale' end
    tex.sprint(string.format(
        [[\includepdf[pages={%s},%s]{%s}]],
        table.concat(range, ','), noautoscale, score.pdfname)
    )
end

function latex.includesystems(score)
    local filename = score.output
    local range = score:_range()
    local protrusion = score:_protrusion()
    local staffsize = score.staffsize
    local indent = score.indent
    local halign = score.halign
    if protrusion then
        local f = io.open(filename..'.protrusion', 'w')
        f:write(protrusion)
        f:close()
    else
        local f = io.open(filename..'.protrusion', 'r')
        protrusion = f:read('*a')
        f:close()
    end
    if #range == 1 and range[1] == "1" and indent then
        warn([[Only one system, deactivating indentation.]])
        protrusion = protrusion - indent
    end
    local texoutput = ''
    if ly.pre_lilypond then
        texoutput = texoutput..'\\preLilyPondExample'
    end
    local left_fill = '\\hfill'
    local right_fill = '\\hfill'
    if halign == 'left' then left_fill = '' end
    if halign == 'right' then right_fill = '' end
    for index, system in pairs(range) do
        if not lfs.isfile(filename..'-'..system..'.pdf') then break end
        texoutput = texoutput..string.format([[
        \noindent\hspace*{%spt}%s\includegraphics{%s}%s
        ]],
        protrusion,
        left_fill,
        filename..'-'..system,
        right_fill)
        if ly.between_lilypond then
            texoutput = texoutput..string.format([[
            \betweenLilyPondSystem{%s}
            ]], index)
        else
            texoutput = texoutput..string.format([[
\par\vspace{%spt plus %spt minus %spt}
            ]],
            staffsize / 4,
            staffsize / 12,
            staffsize / 16)
        end
    end
    if ly.post_lilypond then
        texoutput = texoutput..'\n\\postLilyPondExample'
    end
    tex.sprint(latex.wrap_figure(texoutput, score))
end

function latex.label(score)
    if score.label then tex.sprint('\\label{'..
        score.labelprefix..score.label..'}%%') end
end

ly.verbenv = {[[\begin{verbatim}]], [[\end{verbatim}]]}
function latex.verbatim(score)
    if score.verbatim then
        if score.version then tex.sprint('\\lyVersion{'..score.version..'}') end
        local content = table.concat(score.ly_code:explode('\n'), '\n'):gsub(
          '.*%%%s*begin verbatim', ''):gsub(
          '%%%s*end verbatim.*', '')
        --[[ We unfortunately need an external file,
             as verbatim environments are quite special. ]]
        local fname = ly.get_option('tmpdir')..'/verb.tex'
        local f = io.open(fname, 'w')
        f:write(
            ly.verbenv[1]..'\n'..
            content..
            '\n'..ly.verbenv[2]:gsub([[\end {]], [[\end{]])..'\n'
        )
        f:close()
        tex.sprint('\\input{'..fname..'}')
        if score.intertext then tex.sprint('\\lyIntertext{'..score.intertext..'}') end
    end
end

function latex.wrap_figure(systems, score)
    if score.environment == '' then return systems end
    local b_caption = ''
    local a_caption = ''
    if score.captionbefore then
        b_caption = string.format([[\caption{%s}
]], score.caption)
    else
        a_caption = string.format([[\caption{%s}
]], score.caption)
    end
    return string.format([[
\begin{%s}[%s]
%s%s%s
\end{%s}
]],
    score.environment,
    score['env-opts'],
    b_caption,
    systems,
    a_caption,
    score.environment)
end


--[[ =============================== Classes =============================== ]]

-- Score class
function Score:new(ly_code, options, input_file)
    local o = options or {}
    setmetatable(o, self)
    self.__index = self
    o.input_file = input_file
    o.ly_code = ly_code
    o.orig_ly_code = ly_code
    return o
end

function Score:calc_environment()
    -- caption implies environment
    if self.caption ~= '' and self.environment == ''
    then
        self.environment = 'figure'
    end
    if self.environment ~= '' and self['env-opts'] == ''
    then
        self['env-opts'] = 'tbp'
    end
    -- horizontal alignment
    if self.halign == '' then
        if self.environment == '' then self.halign = 'left'
        else self.halign = 'center'
        end
    end
end

function Score:calc_properties()
    self:calc_staff_properties()
    self:calc_environment()
    -- relative
    if self.relative then
        if self.relative == '' then
            self.relative = 1
        else
            self.relative = tonumber(self.relative)
        end
    end
    -- staffsize
    local staffsize = tonumber(self.staffsize)
    if staffsize == 0 then staffsize = fontinfo(font.current()).size/39321.6 end
    self.staffsize = staffsize
    -- dimensions that can be given by LaTeX
    for _, dimension in pairs(DIM_OPTIONS) do
        self[dimension] = convert_unit(self[dimension])
    end
    if not self.leftgutter then self.leftgutter = self.gutter end
    if not self.rightgutter then self.rightgutter = self.gutter end
    if self.quote then
        self['line-width'] = self['line-width'] - self.leftgutter - self.rightgutter
    end
    -- score fonts
    if self['current-font-as-main'] then
        self.rmfamily = self['current-font']
    end
    -- LilyPond version
    if self.addversion then self.addversion = self:lilypond_version(true) end
    -- temporary file name
    self.output = self:output_filename()
end

function Score:calc_staff_properties()
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

function Score:check_properties()
    local unexpected = false
    for k, _ in orderedpairs(OPTIONS) do
        if self[k] == 'default' then
            self[k] = OPTIONS[k][1] or nil
            unexpected = not self[k]
        end
        if not contains(OPTIONS[k], self[k]) and OPTIONS[k][2] then
            if type(OPTIONS[k][2]) == 'function' then OPTIONS[k][2](k, self[k])
            else unexpected = true
            end
        end
        if unexpected then
            err(
                'Unexpected value "%s" for option %s:\n'..
                'authorized values are "%s"',
                self[k], k, table.concat(OPTIONS[k], ', ')
            )
        end
    end
    for _, k in pairs(TEXINFO_OPTIONS) do
        if self[k] then
            info([[Option ]]..k..[[ is specific to Texinfo: ignoring it.]])
        end
    end
    if self.fragment or self.relative then
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
            ]])
            self.fragment = false
            self.relative = false
        end
    end
end

function Score:content()
    local n = ''
    if self.relative then
        self.fragment = true  -- in case it would serve later
        if self.relative < 0 then
            for _ = -1, self.relative, -1 do n = n..',' end
        elseif self.relative > 0 then
            for _ = 1, self.relative do n = n.."'" end
        end
        return string.format([[\relative c%s {%s}]], n, self.ly_code)
    elseif self.fragment then return [[{]]..self.ly_code..[[}]]
    else return self.ly_code
    end
end

function Score:delete_intermediate_files()
  local i = io.open(self.output..'-systems.count', 'r')
  if i then
      local n = tonumber(i:read('*all'))
      i:close()
      for j = 1, n, 1 do
          os.remove(self.output..'-'..j..'.eps')
      end
      os.remove(self.output..'-systems.tex')
      os.remove(self.output..'-systems.texi')
      os.remove(self.output..'.eps')
      if self.lilypond_error then
          -- ensure score gets recompiled next time
          os.remove(self.output..'-systems.tex')
          os.remove(self.output..'.pdf')
      end
  end
end

function Score:flatten_content(ly_code)
    --[[ Produce a flattend string from the original content,
        including referenced files (if they can be opened.
        Other files (from LilyPond's include path) are considered
        irrelevant for the purpose of a hashsum.) --]]
    local b, e, i, ly_file
    while true do
        b, e = ly_code:find('\\include%s*"[^"]*"', e)
        if not e then break
        else
            ly_file = ly_code:match('\\include%s*"([^"]*)"', b)
            ly_file = locate(ly_file, self.includepaths, '.ly')
            if ly_file then
                i = io.open(ly_file, 'r')
                ly_code = ly_code:sub(1, b - 1)..
                    self:flatten_content(i:read('*a'))..
                    ly_code:sub(e + 1)
                i:close()
            end
        end
    end
    return ly_code
end

function Score:fonts()
    if self['pass-fonts'] then
        return string.format(
            [[
        #(define fonts
          (make-pango-font-tree "%s"
                                "%s"
                                "%s"
                                (/ staff-height pt 20)))
        ]],
            self.rmfamily,
            self.sffamily,
            self.ttfamily
        )
    else return '' end
end

function Score:is_compiled()
    if self.insert == 'fullpage' then
        return lfs.isfile(self.output..'.pdf')
    elseif self.insert == 'systems' then
        local f = io.open(self.output..'-systems.count')
        if not f then return false end
        local head = f:read("*line")
        return not (head == "% eof")
    else
        err('"inline" insertion mode not implemented yet')
    end
end

function Score:is_compiled_without_error()
    local debug_msg, doc_debug_msg
    if self.debug then
        debug_msg = string.format([[
Please check the log file
and the generated LilyPond code in
%s
%s
]],
        self.output..'.log',
        self.output..'.ly')
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
    if self.fragment or self.relative then
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
        return true
    else
        --[[ ensure the score gets recompiled next time --]]
        self:delete_intermediate_files()
        if self.showfailed then
            tex.sprint(string.format([[
                \begin{quote}
                \minibox[frame]{LilyPond failed to compile a score.\\
%s}
                \end{quote}

]],
                doc_debug_msg))
            warn([[

LilyPond failed to compile the score.
%s
]],
            debug_msg)
        else
            err([[

LilyPond failed to compile the score.
%s
]],
          debug_msg)
        end
    end
end

function Score:header()
    local header = LY_HEAD:gsub(
        [[<<<FONTS>>>]], self:fonts()):gsub(
        [[<<<INDENT>>>]], self:ly_indent()):gsub(
        [[<<<LANGUAGE>>>]], self:ly_language()):gsub(
        [[<<<LINEWIDTH>>>]], self['line-width']):gsub(
        [[<<<PAPERSIZE>>>]], self:ly_papersize()):gsub(
        [[<<<RAGGEDRIGHT>>>]], self:ly_raggedright()):gsub(
        [[<<<STAFFPROPS>>>]], self:ly_staffprops()):gsub(
        [[<<<STAFFSIZE>>>]], self.staffsize):gsub(
        [[<<<TWOSIDE>>>]], self:ly_twoside()):gsub(
        [[<<<VERSION>>>]], self['ly-version'])
    if self.insert == 'fullpage' then
        local ppn = 'f'
        if self['print-page-number'] then ppn = 't' end
        header = header:gsub(
	    [[<<<PREAMBLE>>>]],
            string.format(
                [[#(set! paper-alist (cons '("lyluatexfmt" . (cons (* %s pt) (* %s pt))) paper-alist))]],
                self.paperwidth, self.paperheight
	    )
	):gsub(
	    [[<<<PAPER>>>]],
            string.format(
		[[#(set-paper-size "lyluatexfmt")
                print-page-number = ##%s
                print-first-page-number = ##t
                first-page-number = %s
                %s]],
                ppn, ly.PAGE, self:ly_margins()
	    )
        )
    elseif self.insert == 'systems' then
	header = header:gsub(
	    [[<<<PREAMBLE>>>]], [[\include "lilypond-book-preamble.ly"]]):gsub(
	    [[<<<PAPER>>>]], '')
    else
        header = header:gsub(
        [[<<<PREAMBLE>>>]], [[#(ly:set-option 'preview #t)]]):gsub(
        [[<<<PAPER>>>]], '')
        err('"inline" insertion mode not implemented yet')
    end
    return header
end

function Score:lilypond_cmd()
    local input, mode
    if self.debug then
        local f = io.open(self.output..'.ly', 'w')
        f:write(self.ly_code)
        f:close()
        input = self.output..".ly 2>&1"
        mode = 'r'
    else
        input = '-s -'
        mode = 'w'
    end
    local cmd = self.program.." "..
        "-dno-point-and-click "..
        "-djob-count=2 "..
        "-dno-delete-intermediate-files "
    if self.input_file then
        cmd = cmd..'-I "'..dirname(self.input_file):gsub('%./', lfs.currentdir()..'/')..'" '
    end
    for _, dir in ipairs(extract_includepaths(self.includepaths)) do
        cmd = cmd..'-I "'..dir:gsub('^%./', lfs.currentdir()..'/')..'" '
    end
    cmd = cmd..'-o "'..self.output..'" '..input
    debug("Command:\n"..cmd)
    return cmd, mode
end

function Score:lilypond_version(number)
    local p = io.popen(self.program..' --version', 'r')
    if not p then
      err([[
      LilyPond could not be started.
      Please check that LuaLaTeX is
      started with the --shell-escape option.
      ]])
    end
    local result = p:read()
    p:close()
    if result and result:match('GNU LilyPond') then
        if number then return result:match('%d+%.%d+%.?%d*')
        else
            info(
                "Compiling score %s with LilyPond executable '%s'.",
                self.output, self.program
            )
            debug(result)
        end
    else
        err([[
        LilyPond could not be started.
        Please check that 'program' points
        to a valid LilyPond executable
        ]])
    end
end

function Score:ly_indent()
    if self.indent == '' and self.insert == 'fullpage' then return ''
    else return [[indent = ]]..(self.indent or 0)..[[\pt]]
    end
end

function Score:ly_language()
    if not self.language then return ''
    else return '\\language "'..self.language..'"'
    end
end

function Score:ly_margins()
    local tex_top = self['extra-top-margin'] + convert_unit((
        tex.sp('1in') + tex.dimen.voffset + tex.dimen.topmargin +
        tex.dimen.headheight + tex.dimen.headsep
    )..'sp')
    local tex_bottom = self['extra-bottom-margin'] + (
        convert_unit(tex.dimen.paperheight..'sp') -
        (tex_top + convert_unit(tex.dimen.textheight..'sp'))
    )
    local inner = convert_unit((
        tex.sp('1in') +
        tex.dimen.oddsidemargin +
        tex.dimen.hoffset
    )..'sp')
    if self.fullpagealign == 'crop' then
        return string.format([[
            top-margin = %s\pt
            bottom-margin = %s\pt
            inner-margin = %s\pt
            left-margin = %s\pt
            ]],
            tex_top, tex_bottom, inner, inner
        )
    elseif self.fullpagealign == 'staffline' then
      local top_distance = 4 * tex_top / self.staffsize + 2
      local bottom_distance = 4 * tex_bottom / self.staffsize + 2
        return string.format([[
        top-margin = 0\pt
        bottom-margin = 0\pt
        inner-margin = %s\pt
        left-margin = %s\pt
        top-system-spacing =
        #'((basic-distance . %s)
           (minimum-distance . %s)
           (padding . 0)
           (stretchability . 0))
        top-markup-spacing =
        #'((basic-distance . %s)
           (minimum-distance . %s)
           (padding . 0)
           (stretchability . 0))
        last-bottom-spacing =
        #'((basic-distance . %s)
           (minimum-distance . %s)
           (padding . 0)
           (stretchability . 0))
        ]],
        inner,
        inner,
        top_distance,
        top_distance,
        top_distance,
        top_distance,
        bottom_distance,
        bottom_distance
      )
    else
        err(
            [[
        Invalid argument for option 'fullpagealign'.
        Allowed: 'crop', 'staffline'.
        Given: %s
        ]],
            self.fullpagealign
        )
    end
end

function Score:ly_papersize()
    if self.papersize then return '#(set-paper-size "'..self.papersize..'")'
    else return ''
    end
end

function Score:ly_raggedright()
    if self['ragged-right'] == 'default' then return ''
    elseif self['ragged-right'] then return 'ragged-right = ##t'
    else return 'ragged-right = ##f'
    end
end

function Score:ly_twoside()
    if self.twoside then return 't' else return 'f' end
end

function Score:ly_staffprops()
    local clef, timing, timesig, staff = '', '', '', ''
    if self.noclef then
        clef = [[\context { \Staff \remove "Clef_engraver" }
        ]]
    end
    if self.notiming then
        timing = [[\context { \Score timing = ##f }
        ]]
    end
    if self.notimesig then
        timesig = [[\context { \Staff \remove "Time_signature_engraver" }
        ]]
    end
    if self.nostaffsymbol then
        staff = [[\context { \Staff \remove "Staff_symbol_engraver" }
        ]]
    end
    return string.format([[%s%s%s%s
    ]], clef, timing, timesig, staff)
end

function Score:optimize_pdf()
    if self['optimize-pdf'] then
        local pdf2ps, ps2pdf, path
        for file in lfs.dir(self.tmpdir) do
            path = self.tmpdir..'/'..file
            if path:match(self.output) and path:sub(-4) == '.pdf' then
                pdf2ps = io.popen(
                    'gs -q -sDEVICE=ps2write -sOutputFile=- -dNOPAUSE '..path..' -c quit',
                    'r'
                )
                ps2pdf = io.popen(
                    'gs -q -dBATCH -dNOPAUSE -sDEVICE=pdfwrite -sOutputFile='..
                    path..'-gs -',
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

local HASHIGNORE = {
  'cleantmp',
  'print-only'
}
function Score:output_filename()
    local properties = ''
    for k, _ in orderedpairs(OPTIONS) do
        if (not contains(HASHIGNORE, k)) and  self[k] and type(self[k]) ~= 'function' then
            properties = properties..'_'..k..'_'..self[k]
        end
    end
    local filename = md5.sumhexa(self:flatten_content(self.ly_code)..properties)
    self:write_to_filelist(filename)
    return self.tmpdir..'/'..filename
end

function Score:process()
    self:check_properties()
    self:calc_properties()
    local do_compile = not self:is_compiled()
    if do_compile then
        self.ly_code = self:header()..self:content()
        self:run_lilypond()
        self:optimize_pdf()
    end
    self:write_latex(do_compile)
    if not self.debug then self:delete_intermediate_files() end
end

function Score:_protrusion()
    --[[ Determine the amount of space used to the left of the staff lines
      and generate a horizontal offset command. ]]
    local gutter = 0
    if self.quote then gutter = self.leftgutter end
    local protrusion = self.protrusion
    if protrusion then return protrusion + gutter
    elseif self.protrusion then
        local f = io.open(self.output..'.eps')
        if not f then return end
        local bbline = ''
        while not bbline:find('^%%%%BoundingBox') do bbline = f:read() end
        f:close()
        protrusion = bbline:match('-?%d+')
        return tonumber(protrusion) + gutter
    else return gutter
    end
end

function Score:_range()
    local nsystems = ''
    local f = io.open(self.output..'-systems.count', 'r')
    if f then nsystems = f:read('*a') f:close() end
    if self['print-only'] == '' then self['print-only'] = '1-'..nsystems end
    if tonumber(self['print-only']) then return {self['print-only']} end
    local result = {}
    for _, r in pairs(self['print-only']:explode(',')) do
        local range = range_parse(r:gsub('^%s', ''):gsub('%s$', ''), nsystems)
        if range then
            for _, v in pairs(range) do table.insert(result, v) end
        end
    end
    return result
end

function Score:run_lilypond()
    mkdirs(dirname(self.output))
    self:lilypond_version()
    local p = io.popen(self:lilypond_cmd())
    if self.debug then
        local f = io.open(self.output..".log", 'w')
        f:write(p:read('*a'))
        f:close()
    else
        p:write(self.ly_code)
    end
    self.lilypond_error = not p:close()
end

function Score:write_latex(do_compile)
    latex.filename(self)
    latex.verbatim(self)
    if do_compile then
        if not self:is_compiled_without_error() then return end
    end
    --[[ Now we know there is a proper score --]]
    latex.fullpagestyle(self)
    latex.label(self)
    if not lfs.isfile(self.output..'-systems.count') then  -- fullpage score
        latex.includepdf(self)
    else  -- fragment
        latex.includesystems(self)
    end
end

function Score:write_to_filelist(filename)
    local f = io.open(FILELIST, 'a')
    f:write(filename, '\t', self.input_file or '', '\t', self.label or '', '\n')
    f:close()
end


--[[ ========================== Public functions ========================== ]]

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
        Transcript written on %s.log.]],
        tex.jobname, tex.jobname
    )
end


function ly.declare_package_options(options)
    OPTIONS = options
    local exopt = ''
    for k, v in pairs(options) do
        tex.sprint(string.format(
            [[\DeclareOptionX{%s}{\directlua{
                ly.set_property('%s', '\luatexluaescapestring{#1}')
                }}%%
            ]],
            k, k))
            exopt = exopt..k..'='..v[1]..','
    end
    tex.sprint([[\ExecuteOptionsX{]]..exopt..[[}%%]])
    tex.sprint([[\ProcessOptionsX]])
    mkdirs(options.tmpdir[1])
    FILELIST = options.tmpdir[1]..'/'..splitext(status.log_name, 'log')..'.list'
    os.remove(FILELIST)
end


ly.score_content = {}
function ly.env_begin(envs)
    function ly.process_buffer(line)
        table.insert(ly.score_content, line)
        for _, env in pairs(envs:explode(',')) do
            if line:find([[\end{]]..env:gsub('^ ', '')..[[}]]) then return nil end
        end
        return ''
    end
    ly.score_content = {}
    luatexbase.add_to_callback(
        'process_input_buffer',
        ly.process_buffer,
        'readline'
    )
end


function ly.env_end()
    luatexbase.remove_from_callback(
        'process_input_buffer',
        'readline'
    )
    table.remove(ly.score_content)
end


function ly.file(input_file, options)
    --[[ Here, we only take in account global option includepaths,
    as it really doesn't mean anything as a local option. ]]
    local filename = input_file
    input_file = locate(input_file, Score.includepaths, '.ly')
    options = ly.set_local_options(options)
    if not input_file then err("File %s doesn't exist.", filename) end
    local i = io.open(input_file, 'r')
    ly.score = Score:new(i:read('*a'), options, input_file)
    i:close()
end


function ly.file_musicxml(input_file, options)
    --[[ Here, we only take in account global option includepaths,
    as it really doesn't mean anything as a local option. ]]
    local filename = input_file
    input_file = locate(input_file, Score.includepaths, '.xml')
    options = ly.set_local_options(options)
    if not input_file then err("File %s doesn't exist.", filename) end
    local xmlopts = ''
    for _, opt in pairs(MXML_OPTIONS) do
        if options[opt] ~= nil then
            if options[opt] then xmlopts = xmlopts..' --'..opt
                if options[opt] ~= 'true' and options[opt] ~= '' then
                    xmlopts = xmlopts..' '..options[opt]
                end
            end
        elseif Score[opt] then xmlopts = xmlopts..' --'..opt
        end
    end
    local xml2ly = ly.get_option('xml2ly')
    local i = io.popen(xml2ly..' --out=-'..xmlopts..' "'..input_file..'"', 'r')
    ly.score = Score:new(i:read('*a'), options, input_file)
    i:close()
end


function ly.fragment(ly_code, options)
    options = ly.set_local_options(options)
    if type(ly_code) == 'string' then
        ly_code = ly_code:gsub('\\par ', '\n'):gsub('\\([^%s]*) %-([^%s])', '\\%1-%2')
    else
        ly_code = table.concat(ly_code, '\n')
    end
    ly.score = Score:new(
        ly_code,
        options
    )
end


function ly.get_font_family(font_id)
    return fontinfo(font_id).shared.rawdata.metadata['familyname']
end


function ly.get_option(opt)
    return Score[opt]
end


function ly.is_alias() end


function ly.is_dim(k, v)
    if v == '' or v == false or tonumber(v) then return true end
    local n, sl, u = v:match('^%d*%.?%d*'), v:match('\\'), v:match('%a+')
    -- a value of number - backslash - length is a dimension
    -- invalid input will be prevented in by the LaTeX parser already
    if n and sl and u then return true end
    if n and contains(TEX_UNITS, u) then return true end
    err(
        [[
Unexpected value "%s" for dimension %s:
should be either a number (for example "12"),
a number with unit, without space ("12pt"),
or a (multiplied) TeX length (".8\linewidth")
        ]],
        v, k
    )
end


function ly.is_neg(k, _)
    local _, i = k:find('^no')
    return i and contains_key(OPTIONS, k:sub(i + 1))
end


function ly.is_num(_, v)
    return v == '' or tonumber(v)
end


function ly.newpage_if_fullpage()
    if ly.score.insert == 'fullpage' then tex.sprint([[\newpage]]) end
end


function ly.set_local_options(opts)
    local options = {}
    local a, b, c, d
    opts = opts:gsub(' }}}', '}}}')
    while true do
        a, b = opts:find('%w[^=]+=', d)
        c, d = opts:find('{{{[^=]*}}}', d)
        if not d then break end
        local k, v = process_options(
            opts:sub(a, b - 1), opts:sub(c + 3, d - 3)
        )
        if k then
            if options[k] then err('Option %s is set two times for the same score.', k)
            else options[k] = v
            end
        end
    end
    return options
end


function ly.set_property(k, v)
    k, v = process_options(k, v)
    if k then Score[k] = v end
end


return ly
