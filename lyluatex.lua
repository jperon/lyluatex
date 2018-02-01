-- luacheck: ignore ly self warn info log luatexbase internalversion font fonts tex kpse status
local err, warn, info, log = luatexbase.provides_module({
    name               = "lyluatex",
    version            = '0',
    greinternalversion = internalversion,
    date               = "2018/02/01",
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


--[[ ========================== Helper functions ========================== ]]

local function convert_unit(value, from, to)
    return tex.sp(value .. from) / tex.sp("1"..to)
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
    -- delete initial space (in case someone puts a space after the comma)
    for i, path in ipairs(includepaths) do
        includepaths[i] = path:gsub('^ ', '')
    end
    return includepaths
end


local function extract_unit(input)
    --[ split a TeX length into number and unit --]
    return {['n'] = input:match('%d+'), ['u'] = input:match('%a+')}
end


local fontdata = fonts.hashes.identifiers
local function fontinfo(id)
    local f = fontdata[id]
    if f then
        return f
    end
    return font.fonts[id]
end


local function mkdirs(str)
    local path = '.'
    for dir in string.gmatch(str, '([^%/]+)') do
        path = path .. '/' .. dir
        lfs.mkdir(path)
    end
end


local function pt_to_staffspaces(pt, staffsize)
    local s_sp = staffsize / 4
    return pt / s_sp
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

local Score = {}
-- Score class

function Score:new(ly_code, options)
    local o = options or {}
    setmetatable(o, self)
    self.__index = self
    o.ly_code = ly_code
    return o
end

function Score:apply_lilypond_header()
    local header = [[
%%File header
\version "2.18.2"
]]
    if not self.fullpage then
        header = header..[[\include "lilypond-book-preamble.ly"]]..'\n'
    else
        header = header..
            string.format(
                [[#(set! paper-alist (cons '("lyluatexfmt" . (cons (* %s %s) (* %s %s))) paper-alist))]],
                self.paperwidth.n, self.paperwidth.u,
                self.paperheight.n, self.paperheight.u
            )
    end
    header = header..
        string.format(
            [[
            #(define inside-lyluatex #t)

            #(set-global-staff-size %s)

            %%Score parameters

            \header {
              copyright = ""
              tagline = ##f
            }

            \paper{
            ]],
            self.staffsize
        )
    local lilymargin = ''
    if not self.fullpage then
        header = header..[[indent = 0\mm]]
    else
        local ppn = 'f'
        if self['print-page-number'] then ppn = 't' end
        header = header..string.format(
        [[#(set-paper-size "lyluatexfmt")
        print-page-number = ##%s
        print-first-page-number = ##t
        first-page-number = %s]],
        ppn,
        ly.PAGE)
        lilymargin = self:calc_margins()
    end
    header = header..
        string.format('\n'..
            [[
            two-sided = ##t
            line-width = %s\%s
            %s%s}
            %%Follows original score
            ]],
                      self['line-width'].n, self['line-width'].u,
            lilymargin..'\n',
            self:define_lilypond_fonts()
        )
    self.ly_code =
        header..'\n'..self.ly_code
end

function Score:calc_dimensions()
    local staffsize = tonumber(self.staffsize)
    if staffsize == 0 then staffsize = fontinfo(font.current()).size/39321.6 end
    self.staffsize = staffsize
    local value, n
    for _, dimension in pairs({'line-width', 'paperwidth', 'paperheight'}) do
        value = self[dimension]
        if value == 'default' then
            if dimension == 'line-width' then n = tex.dimen.linewidth
            else n = tex.dimen[dimension]
            end
            value = {
                ['u'] = 'pt',
                ['n'] = n / 65536
            }
        else
            value = extract_unit(value)
        end
        self[dimension] = value
    end
end

function Score:calc_margins()
    local tex_top = (
        tex.sp('1in') +
        tex.dimen.voffset +
        tex.dimen.topmargin +
        tex.dimen.headheight +
        tex.dimen.headsep
    )
    local tex_bottom = (
        tex.dimen.paperheight - (tex_top + tex.dimen.textheight)
    ) / 65536
    tex_top = (tex_top / 65536) + self['extra-top-margin']
    tex_bottom = tex_bottom + self['extra-bottom-margin']
    local inner = (
        tex.sp('1in') +
        tex.dimen.oddsidemargin +
        tex.dimen.hoffset
    ) / 65536
    if self.fullpagealign == 'crop' then
        return string.format([[
        top-margin = %s\pt
        bottom-margin = %s\pt
        inner-margin = %s\pt
        ]],
            tex_top,
            tex_bottom,
            inner
        )
    elseif self.fullpagealign == 'staffline' then
      local top_distance = pt_to_staffspaces(tex_top, self.staffsize) + 2
      local bottom_distance = pt_to_staffspaces(tex_bottom, self.staffsize) + 2
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

function Score:calc_protrusion()
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

function Score:define_lilypond_fonts()
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
            i = io.open(ly_file, 'r')
            if i then
                ly_code = ly_code:gsub(ly_code:sub(b, e), self:flatten_content(i:read('*a')))
            else
                if self.input_file then
                    i = io.open(dirname(self.input_file)..'/'..ly_file, 'r')
                end
                if i then
                    ly_code = ly_code:gsub(ly_code:sub(b, e), self:flatten_content(i:read('*a')))
                end
                for _, f in ipairs(extract_includepaths(self.includepaths)) do
                    i = io.open(f..'/'..ly_file, 'r')
                    if i then
                        ly_code = ly_code:gsub(ly_code:sub(b, e), self:flatten_content(i:read('*a')))
                        break
                    end
                end
            end
            if i then i:close() end
        end
    end
    return ly_code
end

function Score:fontify_output(output)
    if self['pass-fonts'] then
        return output..'_'..
          self:squash_fontname('rmfamily')..'_'..
          self:squash_fontname('sffamily')..'_'..
          self:squash_fontname('ttfamily')
    else return output end
end

function Score:hash_output_filename()
    local evenodd = ''
    local etm = 0
    local ebm = 0
    local ppn = ''
    if self.fullpage then
        evenodd = '_'..(ly.PAGE % 2)
        if self['print-page-number'] then ppn = '_ppn' end
        etm = self['extra-top-margin']
        ebm = self['extra-bottom-margin']
    end
    local filename = string.gsub(
        md5.sumhexa(self:flatten_content(self.ly_code))..
        '_'..
        self.staffsize..
        '_'..
        self['line-width'].n..self['line-width'].u..
        evenodd..
        ppn,
        '%.', '_'
    )
    if etm ~= 0 then filename = filename..'_etm_'..etm end
    if ebm ~= 0 then filename = filename..'_ebm_'..ebm end
    self:lilypond_set_roman_font()
    filename = self:fontify_output(filename)
    if self.fullpage then
        filename = filename..'-fullpage'
    end
    self:write_to_filelist(filename)
    return self.tmpdir..'/'..filename
end

function Score:is_compiled()
    if self.output:find('fullpage') then
        return lfs.isfile(self.output..'.pdf')
    else
        local f = io.open(self.output..'-systems.tex')
        if f then
            local head = f:read("*line")
            return not (head == "% eof")
        else return false
        end
    end
end

function Score:lilypond_set_roman_font()
    if self['current-font-as-main'] then
        self.rmfamily = self['current-font']
    end
end

function Score:process_extra_margins()
    local top = tonumber(self['extra-top-margin'])
    if not top then
        local margin = extract_unit(self['extra-top-margin'])
        top = convert_unit(margin.n, margin.u, 'pt')
    end
    self['extra-top-margin'] = top
    local bottom = tonumber(self['extra-bottom-margin'])
    if not bottom then
        local margin = extract_unit(self['extra-bottom-margin'])
        bottom = convert_unit(margin.n, margin.u, 'pt')
    end
    self['extra-bottom-margin'] = bottom
end

function Score:process_lilypond_code()
    self:calc_dimensions()
    self:process_extra_margins()
    self.output = self:hash_output_filename()
    local do_compile = not self:is_compiled()
    if do_compile then
        self:apply_lilypond_header()
        self:run_lilypond()
    end
    self:write_tex(do_compile)
end

function Score:run_lilypond()
    mkdirs(dirname(self.output))
    local cmd = self.program.." "..
        "-dno-point-and-click "..
        "-djob-count=2 "..
        "-dno-delete-intermediate-files "
    if self.input_file then cmd = cmd.."-I "..lfs.currentdir()..'/'..self.input_file.." " end
    for _, dir in ipairs(extract_includepaths(self.includepaths)) do
        cmd = cmd.."-I "..dir:gsub('^./', lfs.currentdir()..'/').." "
    end
    cmd = cmd.."-o "..self.output.." -"
    local p = io.popen(cmd, 'w')
    p:write(self.ly_code)
    p:close()
end

function Score:squash_fontname(fontfamily)
    return self[fontfamily]:gsub(' ', '')
end

function Score:write_tex(do_compile)
    if not self:is_compiled() then
      tex.print(
          [[
          \begin{quote}
          \fbox{Score failed to compile}
          \end{quote}

          ]]
      )
        err("\nScore failed to compile, please check LilyPond input.\n")
        --[[ ensure the score gets recompiled next time --]]
        os.remove(self.output..'-systems.tex')
    end
    --[[ Now we know there is a proper score --]]
    if self.fullpagestyle == 'default' then
        if self['print-page-number'] then
            set_fullpagestyle('empty')
        else set_fullpagestyle(nil)
        end
    else set_fullpagestyle(self.fullpagestyle)
    end
    local systems_file = io.open(self.output..'-systems.tex', 'r')
    if not systems_file then
        --[[ Fullpage score, use \includepdf ]]
        tex.sprint('\\includepdf[pages=-]{'..self.output..'}')
    else
        --[[ Fragment, use -systems.tex file]]
        local content = systems_file:read("*all")
        systems_file:close()
        if do_compile then
            --[[ new compilation, calculate protrusion
                 and update -systems.tex file]]
            local protrusion = self:calc_protrusion()
            local texoutput, _ = content:gsub([[\includegraphics{]],
                [[\noindent]]..' '..protrusion..[[\includegraphics{]]..dirname(self.output))
            tex.sprint(texoutput:explode('\n'))
            local f = io.open(self.output..'-systems.tex', 'w')
            f:write(texoutput)
            f:close()
            self:delete_intermediate_files()
        else
            -- simply reuse existing -systems.tex file
            tex.sprint(content:explode('\n'))
        end
    end
end

function Score:write_to_filelist(filename)
    local f = io.open(FILELIST, 'a')
    f:write(filename, '\t', self.input_file or '', '\n')
    f:close()
end


--[[ ========================== Public functions ========================== ]]

function ly.clean_tmp_dir()
    local hash, file_is_used
    local hash_list = {}
    for file in lfs.dir(OPTIONS.tmpdir) do
        if file:sub(-5, -1) == '.list' then
            local i = io.open(OPTIONS.tmpdir..'/'..file)
            for _, line in ipairs(i:read('*a'):explode('\n')) do
                hash = line:explode('\t')[1]
                if hash ~= '' then table.insert(hash_list, hash) end
            end
            i:close()
        end
    end
    for file in lfs.dir(OPTIONS.tmpdir) do
        file_is_used = false
        if file ~= '.' and file ~= '..' and file:sub(-5, -1) ~= '.list' then
            for _, lhash in ipairs(hash_list) do
                if file:find(lhash) then
                    file_is_used = true
                    break
                end
            end
            if not file_is_used then
                os.remove(OPTIONS.tmpdir..'/'..file)
            end
        end
    end
end


function ly.conclusion_text()
    print(
        string.format(
            '\nOutput written on %s.pdf.\nTranscript written on %s.log.',
            tex.jobname, tex.jobname
        )
    )
end


function ly.declare_package_options(options)
    OPTIONS = options
    for k, v in pairs(options) do
        tex.sprint(string.format([[\DeclareStringOption[%s]{%s}%%]], v, k))
    end
    tex.sprint([[\ProcessKeyvalOptions*]])
    mkdirs(OPTIONS.tmpdir)
    FILELIST = OPTIONS.tmpdir..'/'..splitext(status.log_name, 'log')..'.list'
    os.remove(FILELIST)
end


function ly.file(input_file, options)
    options = ly.set_local_options(options)
    local filename = splitext(input_file, 'ly')
    input_file = ly.CURRFILEDIR..filename..'.ly'
    if not lfs.isfile(input_file) then input_file = kpse.find_file(filename..'.ly') end
    if not lfs.isfile(input_file) then err("File %s.ly doesn't exist.", filename) end
    local i = io.open(input_file, 'r')
    ly.score = Score:new(i:read('*a'), options)
    i:close()
    end


function ly.fragment(ly_code, options)
    options = ly.set_local_options(options)
    ly.score = Score:new(
        ly_code:gsub('\\par ', '\n'):gsub('\\([^%s]*) %-([^%s])', '\\%1-%2'),
        options
    )
end


function ly.get_font_family(font_id)
    return fontinfo(font_id).shared.rawdata.metadata['familyname']
end


function ly.get_option(opt)
    return Score[opt]
end


function ly.newpage_if_fullpage()
    if ly.score.fullpage then tex.sprint([[\newpage]]) end
end


function ly.set_local_options(opts)
    local options = {}
    local a, b, c, d
    while true do
        a, b = opts:find('%w[^=]+=', d)
        c, d = opts:find('{{{%w*}}}', d)
        if not d then break end
        local k, v = opts:sub(a, b - 1), opts:sub(c + 3, d - 3)
        if v == 'false' then v = false end
        if v ~= '' then options[k] = v end
    end
    return options
end


function ly.set_default_options()
    for k, _ in pairs(OPTIONS) do
        tex.sprint(
            string.format(
                [[
                \directlua{
                  ly.set_property('%s', '\luatexluaescapestring{\lyluatex@%s}')
                }]], k, k
            )
        )
    end
end


function ly.set_property(name, value)
    if value == 'false' then value = false end
    Score[name] = value
end


return ly
