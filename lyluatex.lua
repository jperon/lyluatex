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

ly = {}

local FILELIST
local OPTIONS = {}
local TEX_UNITS = {'bp', 'cc', 'cm', 'dd', 'in', 'mm', 'pc', 'pt', 'sp'}
local LY_HEAD = [[
%%File header
\version "2.18.2"

<<<PREAMBLE>>>

#(define inside-lyluatex #t)
#(set-global-staff-size <<<STAFFSIZE>>>)

\header {
    copyright = ""
    tagline = ##f
}
\paper{
    <<<PAPER>>>
    two-sided = ##t
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

local function contains (table_var, value)
    for _, v in pairs(table_var) do
        if v == value then return true
        elseif v == 'false' and value == false then return true
        end
    end
end


local function contains_key (table_var, key)
    for k in pairs(table_var) do
        if k == key then return true end
    end
end


local function convert_unit(value)
    if not value then return 0 end
    value = value:gsub([[\]], '')
    return tonumber(value) or tex.sp(value) / tex.sp("1pt")
end


local function dirname(str)
    if str:match(".-/.-") then
        local name = string.gsub(str, "(.*/)(.*)", "%1")
        return name
    else
        return ''
    end
end


local function extract_includepaths(includepaths)
    includepaths = includepaths:explode(',')
    for i, path in ipairs(includepaths) do
        -- delete initial space (in case someone puts a space after the comma)
        includepaths[i] = path:gsub('^ ', ''):gsub('^~', os.getenv("HOME"))
    end
    return includepaths
end


local fontdata = fonts.hashes.identifiers
local function fontinfo(id)
    local f = fontdata[id]
    if f then
        return f
    end
    return font.fonts[id]
end


local function locate(file, includepaths)
    local result = ly.CURRFILEDIR..file
    if not lfs.isfile(result) then result = file end
    if not lfs.isfile(result) then
        for _, d in ipairs(extract_includepaths(includepaths)) do
            result = d..'/'..file
            if lfs.isfile(result) then break end
        end
    end
    if not lfs.isfile(result) then result = kpse.find_file(file) end
    if not result and file:sub(-3) ~= '.ly' then return locate(file..'.ly', includepaths) end
    return result
end


local function mkdirs(str)
    local path = '.'
    for dir in string.gmatch(str, '([^%/]+)') do
        path = path .. '/' .. dir
        lfs.mkdir(path)
    end
end


local function __genorderedindex( t )
    local orderedIndex = {}
    for key in pairs(t) do
        table.insert( orderedIndex, key )
    end
    table.sort( orderedIndex )
    return orderedIndex
end
local function __orderednext(t, state)
    local key = nil
    if state == nil then
        t.__orderedIndex = __genorderedindex( t )
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
    if v == 'false' then v = false end
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


local function set_fullpagestyle(style)
    if style then
        tex.sprint('\\includepdfset{pagecommand=\\thispagestyle{'..style..'}}')
    else
        tex.sprint('\\includepdfset{pagecommand=}')
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


--[[ =============================== Classes =============================== ]]

-- Score class
function Score:new(ly_code, options, input_file)
    local o = options or {}
    setmetatable(o, self)
    self.__index = self
    o.input_file = input_file
    o.ly_code = ly_code
    return o
end

function Score:calc_properties()
    self:calc_verbatim()
    -- staff display
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
    -- set templates
    if self.noclef then
        self.l_clef = [[
            \context { \Staff \remove "Clef_engraver" }
        ]]
    else self.l_clef = ''
    end
    if self.notiming then
        self.l_timing = [[
            \context { \Score timing = ##f }
        ]]
    else self.l_timing = ''
    end
    if self.notimesig then
        self.l_timesig = [[
            \context { \Staff \remove "Time_signature_engraver" }
        ]]
    else self.l_timesig = ''
    end
    if self.nostaffsymbol then
        self.l_staff = [[
            \context { \Staff \remove "Staff_symbol_engraver" }
        ]]
    else self.l_staff = ''
    end
    self.staff_props = string.format([[
    %s
    %s
    %s
    %s
    ]],
    self.l_clef,
    self.l_timing,
    self.l_timesig,
    self.l_staff
    )
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
    local value
    for _, dimension in pairs({'line-width', 'paperwidth', 'paperheight'}) do
        value = self[dimension]
        if value == '' then
            if dimension == 'line-width' then value = tex.dimen.linewidth..'sp'
            else value = tex.dimen[dimension]..'sp'
            end
        end
        self[dimension] = convert_unit(value)
    end
    -- dimensions specific to LilyPond
    self['extra-top-margin'] = convert_unit(self['extra-top-margin'])
    self['extra-bottom-margin'] = convert_unit(self['extra-bottom-margin'])
    -- score fonts
    if self['current-font-as-main'] then
        self.rmfamily = self['current-font']
    end
    -- temporary file name
    self.output = self:output_filename()
end

function Score:check_failed_compilation()
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
            return false
        else
            err([[

LilyPond failed to compile the score.
%s
            ]],
          debug_msg)
        end
    end
end

function Score:calc_verbatim()
    local intertext = ''
    if self.verbatim then
        if self.intertext ~= '' then
            intertext = string.format([[
\lyIntertext{%s}
            ]],
            self.intertext)
        end
        self.verbatim = string.format([[
\begin{verbatim}
%s
  \end{verbatim}
%s
        ]],
        self.ly_code:gsub('.*%%%s*begin verbatim', ''):gsub(
            '%%%s*end verbatim.*', ''),
        intertext)
    else self.verbatim = ''
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
    if self.input_file or self.ly_code:find([[\score]]) then
        if self.fragment or self.relative then
            if self.input_file then
                warn([[
You may not set `fragment` (or `relative`)
with \lilypondfile. Setting them to false.
                ]])
            else
                warn([[
Found a \score block: setting `fragment`
and `relative` to false.
                ]])
            end
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
      os.remove(self.output..'-systems.count')
      os.remove(self.output..'-systems.texi')
      os.remove(self.output..'.eps')
      os.remove(self.output..'.pdf')
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
            ly_file = locate(ly_file, self.includepaths)
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
        local f = io.open(self.output..'-systems.tex')
        if f then
            local head = f:read("*line")
            return not (head == "% eof")
        else return false
        end
    else
        err('"inline" insertion mode not implemented yet')
    end
end

function Score:header()
    local header = LY_HEAD:gsub(
        [[<<<STAFFSIZE>>>]], self.staffsize):gsub(
        [[<<<LINEWIDTH>>>]], self['line-width']):gsub(
        [[<<<INDENT>>>]], self:ly_indent()):gsub(
        [[<<<RAGGEDRIGHT>>>]], self:ly_raggedright()):gsub(
        [[<<<FONTS>>>]], self:fonts()):gsub(
        [[<<<STAFFPROPS>>>]], self.staff_props)
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
                ppn, ly.PAGE, self:margins()
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
        cmd = cmd.."-I "..lfs.currentdir()..'/'..dirname(self.input_file).." "
    end
    for _, dir in ipairs(extract_includepaths(self.includepaths)) do
        cmd = cmd.."-I "..dir:gsub('^./', lfs.currentdir()..'/').." "
    end
    cmd = cmd.."-o "..self.output.." "..input
    debug("Command:\n"..cmd)
    return cmd, mode
end

function Score:lilypond_version()
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
        info(
            "Compiling score %s with LilyPond executable '%s'.",
            self.output, self.program
        )
        debug(result)
    else
        err([[
        LilyPond could not be started.
        Please check that 'program' points
        to a valid LilyPond executable
        ]])
    end
end

function Score:ly_indent()
    if self.indent == '' then
        if self.insert == 'fullpage' then return ''
        else return [[ indent = 0\cm ]]
        end
    else
        return [[indent = ]]..convert_unit(self.indent)..[[\pt]]
    end
end

function Score:ly_raggedright()
    if self['ragged-right'] == 'default' then return ''
    elseif self['ragged-right'] then return 'ragged-right = ##t'
    else return 'ragged-right = ##f'
    end
end

function Score:margins()
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
            ]],
            tex_top, tex_bottom, inner
        )
    elseif self.fullpagealign == 'staffline' then
      local top_distance = 4 * tex_top / self.staffsize + 2
      local bottom_distance = 4 * tex_bottom / self.staffsize + 2
        return string.format([[
        top-margin = 0\pt
        bottom-margin = 0\pt
        inner-margin = %s\pt
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

function Score:output_filename()
    local properties = ''
    for k, _ in orderedpairs(OPTIONS) do
        if k ~= 'cleantmp' and self[k] and type(self[k]) ~= 'function' then
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
    end
    self:write_tex(do_compile)
end

function Score:protrusion()
    --[[
      Determine the amount of space used to the left of the staff lines
      and generate a horizontal offset command.
    --]]
    local protrusion = ''
    local f = io.open(self.output..'.eps')
    --[[ The information we need is in the third line --]]
    f:read(); f:read()
    local bb_line = f:read()
    f:close()
    local cropped = bb_line:match('%d+')
    if cropped ~= 0 then
        protrusion = string.format('\\hspace*{-%spt}', cropped)
    end
    return protrusion
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

function Score:write_tex(do_compile)
    if do_compile then
        if not self:check_failed_compilation() then return end
    end
    if self.verbatim ~= '' then tex.print(self.verbatim:explode('\n')) end
    --[[ Now we know there is a proper score --]]
    if self.fullpagestyle == '' then
        if self['print-page-number'] then
            set_fullpagestyle('empty')
        else set_fullpagestyle(nil)
        end
    else set_fullpagestyle(self.fullpagestyle)
    end
    local label = ''
    if self.label then label = '\\label{'..self.labelprefix..self.label..'}' end
    local systems_file = io.open(self.output..'-systems.tex', 'r')
    if not systems_file then
        --[[ Fullpage score, use \includepdf ]]
        tex.sprint(label..'\\includepdf[pages=-]{'..self.output..'}')
    else
        --[[ Fragment, use -systems.tex file]]
        local content = systems_file:read("*all")
        local texoutput
        systems_file:close()
        if do_compile then
            --[[ new compilation, calculate protrusion
                 and update -systems.tex file]]
            local protrusion = self:protrusion()
            texoutput = content:gsub([[\includegraphics{]],
                [[\noindent]]..' '..protrusion..[[\includegraphics{]]..dirname(self.output))
            local f = io.open(self.output..'-systems.tex', 'w')
            f:write(texoutput)
            f:close()
            self:delete_intermediate_files()
        else
            -- simply reuse existing -systems.tex file
            texoutput = content
        end
        texoutput = label..
            [[\ifx\preLilyPondExample\undefined\else\expandafter\preLilyPondExample\fi]]..
            texoutput..
            [[\ifx\postLilyPondExample\undefined\else\expandafter\postLilyPondExample\fi]]
        tex.sprint(texoutput:explode('\n'))
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


function ly.file(input_file, options)
    --[[ Here, we only take in account global option includepaths,
    as it really doesn't mean anything as a local option. ]]
    input_file = locate(input_file, Score.includepaths)
    options = ly.set_local_options(options)
    if not input_file then err("File %s.ly doesn't exist.", input_file) end
    local i = io.open(input_file, 'r')
    ly.score = Score:new(i:read('*a'), options, input_file)
    i:close()
end


function ly.fragment(ly_code, options)
    options = ly.set_local_options(options)
    info(ly_code:gsub('\\par ','\n\n'):gsub('\r', '\n'):gsub('\\([^%s]*) %-([^%s])', '\\%1-%2'))
    ly.score = Score:new(
        ly_code:gsub('\\par ','\n\n'):gsub('\r', '\n'):gsub('\\([^%s]*) %-([^%s])', '\\%1-%2'),
        options
    )
end


function ly.get_font_family(font_id)
    return fontinfo(font_id).shared.rawdata.metadata['familyname']
end


function ly.get_option(opt)
    return Score[opt]
end


function ly.is_dim (k, v)
    if v == '' or v == false then return true end
    local n, u = v:match('%d*%.?%d*'), v:match('%a+')
    if tonumber(v) or n and contains(TEX_UNITS, u) then return true end
    err(
        [[Unexpected value "%s" for dimension %s:
        should be either a number (for example "12"), or a number with unit, without space ("12pt")
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
        if k then options[k] = v end
    end
    return options
end


function ly.set_property(k, v)
    k, v = process_options(k, v)
    if k then Score[k] = v end
end


return ly
