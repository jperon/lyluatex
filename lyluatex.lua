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


function flatten_content(ly_code, input_file)
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

function extract_unit(input)
    --[ split a TeX length into number and unit --]
    return {['n'] = input:match('%d+'), ['u'] = input:match('%a+')}
end


function extract_includepaths(includepaths)
    includepaths = includepaths:explode(',')
    -- delete initial space (in case someone puts a space after the comma)
    for i, path in ipairs(includepaths) do
        includepaths[i] = path:gsub('^ ', '')
    end
    return includepaths
end

function hash_output_filename(ly_code, line_width, staffsize, input_file)
    local evenodd = ''
    if get_local_option('fullpage') then evenodd = '_'..(PAGE % 2) end
    local filename = string.gsub(
        md5.sumhexa(flatten_content(ly_code), input_file)..
        '_'..staffsize..'_'..line_width.n..line_width.u..evenodd, '%.', '_'
    )
    lilypond_set_roman_font()
    filename = fontify_output(filename)
    if not input_file then input_file = '' end
    local f = io.open(FILELIST, 'a')
    f:write(filename, '\t', input_file, '\n')
    f:close()
    return OPTIONS.tmpdir..'/'..filename
end


function is_compiled(output)
    if output:find('fullpage') then
        if lfs.isfile(output..'.pdf') then
            return true else return false end
    end
    local f = io.open(output..'-systems.tex')
    if not f then return false end
    local head = f:read("*line")
    if head == "% eof" then return false else return true end
end


function process_lilypond_code(ly_code, input_file)
    local fullpage = get_local_option('fullpage')
    local line_width = extract_unit(get_local_option('line-width'))
    local staffsize = calc_staffsize(get_local_option('staffsize'))
    local output = hash_output_filename(ly_code, line_width, staffsize, input_file)
    if fullpage then output = output..'-fullpage' end
    local new_score = not is_compiled(output)
    if new_score then
        local input
        if input_file then input = dirname(input_file) end
            compile_lilypond_fragment(
                ly_code, staffsize, line_width, output, input, fullpage
            )
    end
    write_tex(output, new_score)
end


function lilypond_fragment(ly_code)
    ly_code = ly_code:gsub('\\par ', '\n'):gsub('\\([^%s]*) %-([^%s])', '\\%1-%2')
    process_lilypond_code(ly_code, nil)
end


function lilypond_file(input_file, currfiledir, fullpage)
    filename = splitext(input_file, 'ly')
    input_file = currfiledir..filename..'.ly'
    if not lfs.isfile(input_file) then input_file = kpse.find_file(filename..'.ly') end
    if not lfs.isfile(input_file) then err("File %s.ly doesn't exist.", filename) end
    local i = io.open(input_file, 'r')
    ly_code = i:read('*a')
    i:close()
    process_lilypond_code(ly_code, input_file)
end


function run_lilypond(ly_code, output, include)
    mkdirs(dirname(output))
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
    p:write(ly_code)
    p:close()
end

function compile_lilypond_fragment(
        ly_code, staffsize, line_width, output, include, fullpage)
    ly_code = lilypond_fragment_header(staffsize, line_width, fullpage)..'\n'..ly_code
    run_lilypond(ly_code, output, include)
end


function lilypond_fragment_header(staffsize, line_width, fullpage)
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
            \paper{
            ]],
            staffsize
        )
    local lilymargin = ''
    if not fullpage then
        header = header..[[indent = 0\mm]]
    else
        header = header..[[#(set-paper-size "lyluatexfmt")]]
        lilymargin = 'top-margin = %s\\pt\nbottom-margin = %s\\pt\n'
        if PAGE % 2 == 1 then
            lilymargin = lilymargin..[[inner-margin = %s\pt]]
        else
            lilymargin = lilymargin..[[outer-margin = %s\pt]]
        end
        local margins = {}
        margins.top = (
            tex.sp('1in') +
            tex.dimen.voffset +
            tex.dimen.topmargin +
            tex.dimen.headheight +
            tex.dimen.headsep
        )
        margins.bottom = (
            tex.dimen.paperheight -
            (margins.top + tex.dimen.textheight + tex.dimen.footskip)
        )
        margins.inner = (
            tex.sp('1in') +
            tex.dimen.oddsidemargin +
            tex.dimen.hoffset
        )
        lilymargin = string.format(
            lilymargin,
            margins.top / 65536, margins.bottom / 65536, margins.inner / 65536
        )
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
    print('\n', header)
    return header
end


function calc_staffsize(staffsize)
    staffsize = tonumber(staffsize)
    if staffsize == 0 then staffsize = fontinfo(font.current()).size/39321.6 end
    return staffsize
end


function delete_intermediate_files(output)
  local i = io.open(output..'-systems.count', 'r')
  if i then
      local n = tonumber(i:read('*all'))
      i:close()
      for i = 1, n, 1 do
          os.remove(output..'-'..i..'.eps')
      end
      os.remove(output..'-systems.count')
      os.remove(output..'-systems.texi')
      os.remove(output..'.eps')
      os.remove(output..'.pdf')
  end
end


function clean_tmp_dir()
    local hash, file_is_used
    local hash_list = {}
    for file in lfs.dir(get_option('tmpdir')) do
        if file:sub(-5, -1) == '.list' then
            local i = io.open(get_option('tmpdir')..'/'..file)
            for _, line in ipairs(i:read('*a'):explode('\n')) do
                hash = line:explode('\t')[1]
                if hash ~= '' then table.insert(hash_list, hash) end
            end
            i:close()
        end
    end
    for file in lfs.dir(get_option('tmpdir')) do
        file_is_used = false
        if file ~= '.' and file ~= '..' and file:sub(-5, -1) ~= '.list' then
            for _, hash in ipairs(hash_list) do
                if file:find(hash) then
                    file_is_used = true
                    break
                end
            end
            if not file_is_used then
                os.remove(get_option('tmpdir')..'/'..file)
            end
        end
    end
end


function conclusion_text()
    print(
        string.format(
            '\nOutput written on %s.pdf.\nTranscript written on %s.log.',
            tex.jobname, tex.jobname
        )
    )
end


function calc_protrusion(output)
    --[[
      Determine the amount of space used to the left of the staff lines
      and generate a horizontal offset command.
    --]]
    local protrusion = ''
    local systems_file = output..'.eps'
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

function write_tex(output, new_score)
    if not is_compiled(output) then
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
    local systems_file = io.open(output..'-systems.tex', 'r')
    if not systems_file then
        --[[ Fullpage score, use \includepdf ]]
        tex.print('\\includepdf[pages=-]{'..output..'}')
    else
        --[[ Fragment, use -systems.tex file]]
        local content = systems_file:read("*all")
        systems_file:close()
        if new_score then
            --[[ new compilation, calculate protrusion
                 and update -systems.tex file]]
            local protrusion = calc_protrusion(output)
            local texoutput, _ = content:gsub([[\includegraphics{]],
                [[\noindent]]..' '..protrusion..[[\includegraphics{]]..dirname(output))
            tex.print(texoutput:explode('\n'))
            local f = io.open(output..'-systems.tex', 'w')
            f:write(texoutput)
            f:close()
            delete_intermediate_files(output)
        else
            -- simply reuse existing -systems.tex file
            tex.print(content:explode('\n'))
        end
    end
end


function declare_package_options(options)
    OPTIONS = options
    for k, v in pairs(options) do
        tex.sprint(string.format([[\DeclareStringOption[%s]{%s}%%]], v, k))
    end
    tex.sprint([[\ProcessKeyvalOptions*]])
    mkdirs(OPTIONS.tmpdir)
    FILELIST = OPTIONS.tmpdir..'/'..splitext(status.log_name, 'log')..'.list'
    os.remove(FILELIST)
end


function set_option(name, value)
    if value == 'false' then value = false end
    OPTIONS[name] = value
end


function get_option(name)
    return OPTIONS[name]
end


function set_default_options()
    for k, v in pairs(OPTIONS) do
        tex.sprint(
            string.format(
                [[
                \directlua{
                  set_option('%s', '\luatexluaescapestring{\lyluatex@%s}')
                }]], k, k
            )
        )
    end
end


function get_local_option(name)
    if LOCAL_OPTIONS[name] then
        return LOCAL_OPTIONS[name]
    else
        return OPTIONS[name]
    end
end

local LOC_OPT_NAMES = {
    'current-font-as-main',
    'fullpage',
    'includepaths',
    'line-width',
    'pass-fonts',
    'program',
    'staffsize',
}
function process_local_options()
    tex.sprint([[\directlua{set_local_options({]])
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

function set_local_options(opts)
    for k,v in pairs(opts) do
        if v == 'false' then v = false end
        if v ~= '' then LOCAL_OPTIONS[k] = v end
    end
end

function reset_local_options()
    LOCAL_OPTIONS = {}
end


function basename(str)
    if str:match(".-/.-") then
        local name = string.gsub(str, "(.*/)(.*)", "%2")
        return name
    else
        return ''
    end
end


function dirname(str)
    if str:match(".-/.-") then
        local name = string.gsub(str, "(.*/)(.*)", "%1")
        return name
    else
        return ''
    end
end


function splitext(str, ext)
    if str:match(".-%..-") then
        local name = string.gsub(str, "(.*)(%." .. ext .. ")", "%1")
        return name
    else
        return str
    end
end


function mkdirs(str)
    local path = '.'
    for dir in string.gmatch(str, '([^%/]+)') do
        path = path .. '/' .. dir
        lfs.mkdir(path)
    end
end


local fontdata = fonts.hashes.identifiers
function fontinfo(id)
    local f = fontdata[id]
    if f then
        return f
    end
    return font.fonts[id]
end

function get_font_family(font_id)
    return fontinfo(font_id).shared.rawdata.metadata['familyname']
end

function define_lilypond_fonts()
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

function lilypond_set_roman_font()
    if get_local_option('current-font-as-main') == 'true' then
        LOCAL_OPTIONS.rmfamily = get_local_option('current-font') end
end

function squash_fontname(family)
    return get_local_option(family):gsub(' ', '')
end

function fontify_output(output)
    if get_local_option('pass-fonts') == 'true' then
        return output..'_'..
          squash_fontname('rmfamily')..'_'..
          squash_fontname('sffamily')..'_'..
          squash_fontname('ttfamily')
    else return output end
end
