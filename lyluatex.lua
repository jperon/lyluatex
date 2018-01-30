-- luacheck: ignore ly warn info log luatexbase internalversion font fonts tex kpse status
local err, warn, info, log = luatexbase.provides_module({
    name               = "lyluatex",
    version            = '0',
    greinternalversion = internalversion,
    date               = "2017/12/05",
    description        = "Module lyluatex.",
    author             = "The Gregorio Project  − Jacques Peron <cataclop@hotmail.com>",
    copyright          = "2008-2017 - The Gregorio Project",
    license            = "MIT",
})

local md5 = require 'md5'
local lfs = require 'lfs'
local FILELIST, OPTIONS, LOCAL_OPTIONS
ly = {}


local function dirname(str)
    if str:match(".-/.-") then
        local name = string.gsub(str, "(.*/)(.*)", "%1")
        return name
    else
        return ''
    end
end


local function mkdirs(str)
    local path = '.'
    for dir in string.gmatch(str, '([^%/]+)') do
        path = path .. '/' .. dir
        lfs.mkdir(path)
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


local function extract_includepaths(includepaths)
    includepaths = includepaths:explode(',')
    -- delete initial space (in case someone puts a space after the comma)
    for i, path in ipairs(includepaths) do
        includepaths[i] = path:gsub('^ ', '')
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


local function get_local_option(name, default)
    if LOCAL_OPTIONS[name] then
        return LOCAL_OPTIONS[name]
    elseif OPTIONS[name] then
        return OPTIONS[name]
    elseif default then
        return default
    end
end


local function set_fullpagestyle(style)
    if style then
        tex.sprint('\\includepdfset{pagecommand=\\thispagestyle{'..style..'}}')
    else
        tex.sprint('\\includepdfset{pagecommand=}')
    end
end


local function lilypond_set_roman_font()
    if get_local_option('current-font-as-main') == 'true' then
        LOCAL_OPTIONS.rmfamily = get_local_option('current-font') end
end


local function squash_fontname(family)
    return get_local_option(family):gsub(' ', '')
end


local function fontify_output(output)
    if get_local_option('pass-fonts') == 'true' then
        return output..'_'..
          squash_fontname('rmfamily')..'_'..
          squash_fontname('sffamily')..'_'..
          squash_fontname('ttfamily')
    else return output end
end


local function define_lilypond_fonts()
    if get_local_option('pass-fonts') then
        return string.format([[
        #(define fonts
          (make-pango-font-tree "%s"
                                "%s"
                                "%s"
                                (/ staff-height pt 20)))
        ]],
        get_local_option('rmfamily'),
        get_local_option('sffamily'),
        get_local_option('ttfamily'))
    else return '' end
end


local function flatten_content(ly_code, input_file)
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
                ly_code = ly_code:gsub(ly_code:sub(b, e), flatten_content(i:read('*a'), input_file))
            else
                if input_file then
                    i = io.open(dirname(input_file)..'/'..ly_file, 'r')
                end
                if i then
                    ly_code = ly_code:gsub(ly_code:sub(b, e), flatten_content(i:read('*a'), input_file))
                end
                for _, f in ipairs(extract_includepaths(get_local_option('includepaths'))) do
                    i = io.open(f..'/'..ly_file, 'r')
                    if i then
                        ly_code = ly_code:gsub(ly_code:sub(b, e), flatten_content(i:read('*a'), input_file))
                        break
                    end
                end
            end
            if i then i:close() end
        end
    end
    return ly_code
end

local CONVERSIONS = {
    ['pt'] = {
        ['mm'] = 0.351459804,
        ['cm'] = 0.0351459804,
        ['in'] = 0.013837
    },
    ['mm'] = {
        ['pt'] = 2.845275591,
        ['cm'] = 0.1,
        ['in'] = 0.039370079
    },
    ['cm'] = {
        ['pt'] = 28,346456693,
        ['mm'] = 10,
        ['in'] = 0.393700787
    },
    ['in'] = {
        ['pt'] = 72.27,
        ['mm'] = 25.4,
        ['cm'] = 2.54
    }
}
local function convert_unit(value, from, to)
    return value * CONVERSIONS[from][to]
end

local function extract_unit(input)
    --[ split a TeX length into number and unit --]
    return {['n'] = input:match('%d+'), ['u'] = input:match('%a+')}
end

local function write_to_filelist(filename)
    local input_file = get_local_option('input-file', '')
    local f = io.open(FILELIST, 'a')
    f:write(filename, '\t', input_file, '\n')
    f:close()
end

local function hash_output_filename()
    local line_width = get_local_option('line-width')
    local fullpage = get_local_option('fullpage')
    local evenodd = ''
    local etm = 0
    local ebm = 0
    local ppn = ''
    if fullpage then
        evenodd = '_'..(ly.PAGE % 2)
        if get_local_option('print-page-number') then ppn = '_ppn' end
        etm = get_local_option('extra-top-margin')
        ebm = get_local_option('extra-bottom-margin')
    end
    local filename = string.gsub(
        md5.sumhexa(flatten_content(
            get_local_option('ly-code'),
            get_local_option('input-file')))..
        '_'..
        get_local_option('staffsize')..
        '_'..
        line_width.n..line_width.u..
        evenodd..
        ppn,
        '%.', '_'
    )
    if etm ~= 0 then filename = filename..'_etm_'..etm end
    if ebm ~= 0 then filename = filename..'_ebm_'..ebm end
    lilypond_set_roman_font()
    filename = fontify_output(filename)
    if fullpage then
        filename = filename..'-fullpage'
    end
    write_to_filelist(filename)
    return OPTIONS.tmpdir..'/'..filename
end


local function is_compiled()
    local output = get_local_option('output')
    if output:find('fullpage') then
        if lfs.isfile(output..'.pdf') then
            return true else return false end
    end
    local f = io.open(output..'-systems.tex')
    if not f then return false end
    local head = f:read("*line")
    if head == "% eof" then return false else return true end
end


local function calc_staffsize(staffsize)
    staffsize = tonumber(staffsize)
    if staffsize == 0 then staffsize = fontinfo(font.current()).size/39321.6 end
    return staffsize
end


function ly.set_local_option(name, value)
    if value == 'false' then value = false end
    LOCAL_OPTIONS[name] = value
end


local function process_extra_margins()
    local top_extra = get_local_option('extra-top-margin')
    local top = tonumber(top_extra)
    if not top then
        local margin = extract_unit(top_extra)
        top = convert_unit(margin.n, margin.u, 'pt')
    end
    ly.set_local_option('extra-top-margin', top)
    local bottom_extra = get_local_option('extra-bottom-margin')
    local bottom = tonumber(bottom_extra)
    if not bottom then
        local margin = extract_unit(bottom_extra)
        bottom = convert_unit(margin.n, margin.u, 'pt')
    end
    ly.set_local_option('extra-bottom-margin', bottom)
end


local function pt_to_staffspaces(pt, staffsize)
    local s_sp = staffsize / 4
    return pt / s_sp
end


local function calc_margins()
    local staffsize = get_local_option('staffsize')
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
    tex_top = (tex_top / 65536) + get_local_option('extra-top-margin')
    tex_bottom = tex_bottom + get_local_option('extra-bottom-margin')
    local inner = (
        tex.sp('1in') +
        tex.dimen.oddsidemargin +
        tex.dimen.hoffset
    ) / 65536
    local v_align = get_local_option('fullpagealign')
    if v_align == 'crop'
    then
        return string.format([[
        top-margin = %s\pt
        bottom-margin = %s\pt
        inner-margin = %s\pt
        ]],
          tex_top,
          tex_bottom,
          inner
        )
    elseif v_align == 'staffline' then
      local top_distance = pt_to_staffspaces(tex_top, staffsize) + 2
      local bottom_distance = pt_to_staffspaces(tex_bottom, staffsize) + 2
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
        err([[
        Invalid argument for option 'fullpagealign'.
        Allowed: 'crop', 'staffline'.
        Given: %s
        ]],
        v_align)
    end
end


local function calc_protrusion()
    --[[
      Determine the amount of space used to the left of the staff lines
      and generate a horizontal offset command.
    --]]
    local protrusion = ''
    local systems_file = get_local_option('output')..'.eps'
    local f = io.open(systems_file)
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


local function apply_lilypond_header()
    local line_width = get_local_option('line-width')
    local staffsize = get_local_option('staffsize')
    local fullpage = get_local_option('fullpage')
    local header = [[
%%File header
\version "2.18.2"
]]
    if not fullpage then
        header = header..[[\include "lilypond-book-preamble.ly"]]..'\n'
    else
        header = header..
            string.format(
                [[#(set! paper-alist (cons '("lyluatexfmt" . (cons (* %s pt) (* %s pt))) paper-alist))]],
                get_local_option('pagewidth'):sub(1,-3),
                get_local_option('paperheight'):sub(1,-3)
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
            staffsize
        )
    local lilymargin = ''
    if not fullpage then
        header = header..[[indent = 0\mm]]
    else
        local ppn = 'f'
        if get_local_option('print-page-number') then ppn = 't' end
        header = header..string.format(
        [[#(set-paper-size "lyluatexfmt")
        print-page-number = ##%s
        print-first-page-number = ##t
        first-page-number = %s]],
        ppn,
        ly.PAGE)
        lilymargin = calc_margins()
    end
    header = header..
        string.format('\n'..
            [[
            two-sided = ##t
            line-width = %s\%s
            %s%s}
            %%Follows original score
            ]],
            line_width.n, line_width.u,
            lilymargin..'\n',
            define_lilypond_fonts()
        )
    ly.set_local_option('ly-code',
        header..'\n'..get_local_option('ly-code'))
end


local function run_lilypond()
    local output = get_local_option('output')
    mkdirs(dirname(output))
    local include = get_local_option('input-file')
    local cmd = get_local_option('program').." "..
        "-dno-point-and-click "..
        "-djob-count=2 "..
        "-dno-delete-intermediate-files "
    if include then cmd = cmd.."-I "..lfs.currentdir()..'/'..include.." " end
    for _, dir in ipairs(extract_includepaths(get_local_option('includepaths'))) do
        cmd = cmd.."-I "..dir:gsub('^./', lfs.currentdir()..'/').." "
    end
    cmd = cmd.."-o "..output.." -"
    local p = io.popen(cmd, 'w')
    p:write(get_local_option('ly-code'))
    p:close()
end


local function delete_intermediate_files()
  local output = get_local_option('output')
  local i = io.open(output..'-systems.count', 'r')
  if i then
      local n = tonumber(i:read('*all'))
      i:close()
      for j = 1, n, 1 do
          os.remove(output..'-'..j..'.eps')
      end
      os.remove(output..'-systems.count')
      os.remove(output..'-systems.texi')
      os.remove(output..'.eps')
      os.remove(output..'.pdf')
  end
end


local function write_tex(do_compile)
    local output = get_local_option('output')
    if not is_compiled() then
      tex.print(
          [[
          \begin{quote}
          \fbox{Score failed to compile}
          \end{quote}

          ]]
      )
        err("\nScore failed to compile, please check LilyPond input.\n")
        --[[ ensure the score gets recompiled next time --]]
        os.remove(output..'-systems.tex')
    end
    --[[ Now we know there is a proper score --]]
    local fullpagestyle = get_local_option('fullpagestyle')
    if fullpagestyle == 'default' then
        if get_local_option('print-page-number') then
            set_fullpagestyle('empty')
        else set_fullpagestyle(nil)
        end
    else set_fullpagestyle(fullpagestyle)
    end
    local systems_file = io.open(output..'-systems.tex', 'r')
    if not systems_file then
        --[[ Fullpage score, use \includepdf ]]
        tex.sprint('\\includepdf[pages=-]{'..output..'}')
    else
        --[[ Fragment, use -systems.tex file]]
        local content = systems_file:read("*all")
        systems_file:close()
        if do_compile then
            --[[ new compilation, calculate protrusion
                 and update -systems.tex file]]
            local protrusion = calc_protrusion()
            local texoutput, _ = content:gsub([[\includegraphics{]],
                [[\noindent]]..' '..protrusion..[[\includegraphics{]]..dirname(output))
            tex.print(texoutput:explode('\n'))
            local f = io.open(output..'-systems.tex', 'w')
            f:write(texoutput)
            f:close()
            delete_intermediate_files()
        else
            -- simply reuse existing -systems.tex file
            tex.sprint(content:explode('\n'))
        end
    end
end


local function process_lilypond_code()
    ly.set_local_option('staffsize', calc_staffsize(get_local_option('staffsize')))
    ly.set_local_option('line-width', extract_unit(get_local_option('line-width')))
    process_extra_margins()
    ly.set_local_option('output', hash_output_filename())
    local do_compile = not is_compiled()
    if do_compile then
        apply_lilypond_header()
        run_lilypond()
    end
    write_tex(do_compile)
end


function ly.clean_tmp_dir()
    local hash, file_is_used
    local hash_list = {}
    for file in lfs.dir(ly.get_option('tmpdir')) do
        if file:sub(-5, -1) == '.list' then
            local i = io.open(ly.get_option('tmpdir')..'/'..file)
            for _, line in ipairs(i:read('*a'):explode('\n')) do
                hash = line:explode('\t')[1]
                if hash ~= '' then table.insert(hash_list, hash) end
            end
            i:close()
        end
    end
    for file in lfs.dir(ly.get_option('tmpdir')) do
        file_is_used = false
        if file ~= '.' and file ~= '..' and file:sub(-5, -1) ~= '.list' then
            for _, lhash in ipairs(hash_list) do
                if file:find(lhash) then
                    file_is_used = true
                    break
                end
            end
            if not file_is_used then
                os.remove(ly.get_option('tmpdir')..'/'..file)
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


function ly.file(input_file)
    local filename = splitext(input_file, 'ly')
    input_file = ly.CURFILEDIR..filename..'.ly'
    if not lfs.isfile(input_file) then input_file = kpse.find_file(filename..'.ly') end
    if not lfs.isfile(input_file) then err("File %s.ly doesn't exist.", filename) end
    ly.set_local_option('input-file', input_file)
    local i = io.open(input_file, 'r')
    ly.set_local_option('ly-code', i:read('*a'))
    i:close()
    process_lilypond_code()
end


function ly.fragment(ly_code)
    ly.set_local_option('ly-code', ly_code:gsub('\\par ', '\n'):gsub('\\([^%s]*) %-([^%s])', '\\%1-%2'))
    process_lilypond_code()
end


function ly.get_font_family(font_id)
    return fontinfo(font_id).shared.rawdata.metadata['familyname']
end


function ly.get_option(name)
    return OPTIONS[name]
end


function ly.newpage_if_fullpage()
    if get_local_option('fullpage') then tex.sprint([[\newpage]]) end
end

local LOC_OPT_NAMES = {
    'current-font-as-main',
    'extra-bottom-margin',
    'extra-top-margin',
    'fullpage',
    'fullpagealign',
    'fullpagestyle',
    'includepaths',
    'line-width',
    'pass-fonts',
    'print-page-numbers',
    'program',
    'staffsize',
}
function ly.process_local_options()
    tex.sprint([[\directlua{ly.set_local_options({]])
    for _, v in ipairs(LOC_OPT_NAMES) do
        tex.sprint(
            string.format(
                [[['%s'] = '\luatexluaescapestring{\commandkey{%s}}',]],
                v, v
            )
        )
    end
    tex.sprint([[})}]])
end


function ly.reset_local_options()
    LOCAL_OPTIONS = {}
end


function ly.set_default_options()
    for k, _ in pairs(OPTIONS) do
        tex.sprint(
            string.format(
                [[
                \directlua{
                  ly.set_option('%s', '\luatexluaescapestring{\lyluatex@%s}')
                }]], k, k
            )
        )
    end
end


function ly.set_local_options(opts)
    for k,v in pairs(opts) do
        if v == 'false' then v = false end
        if v ~= '' then LOCAL_OPTIONS[k] = v end
    end
end


function ly.set_option(name, value)
    if value == 'false' then value = false end
    OPTIONS[name] = value
end

return ly
