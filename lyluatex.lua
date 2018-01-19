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

function ly_define_program(lilypond)
    if lilypond then LILYPOND = lilypond end
end


function flatten_content(ly_code)
  --[[ Produce a flattend string from the original content,
       including referenced files (if they can be opened.
       Other files (from LilyPond's include path) are considered
       irrelevant for the purpose of a hashsum.) --]]
    local result =""
    for _, Line in ipairs(ly_code:explode('\n')) do
	if Line:find("^%s*[^%%]*\\include") then
	    local i = io.open(Line:gsub('%s*\\include%s*"(.*)"%s*$', "%1"), 'r')
	    if i then
		result = result .. flatten_content(i:read('*a'))
	    else
		result = result .. Line .. "\n"
	    end
	else
	    result = result .. Line .. "\n"
	end
    end
    return result
end

function extract_unit(input)
  --[ split a TeX length into number and unit --]
    return {['n'] = input:match('%d+'), ['u'] = input:match('%a+')}
end

function extract_size_arguments(line_width, staffsize)
    line_width = extract_unit(line_width)
    staffsize = calc_staffsize(staffsize)
    return line_width, staffsize
end

function hash_output_filename(ly_code, line_width, staffsize)
    filename = string.gsub(
        md5.sumhexa(flatten_content(ly_code))..
        '-'..staffsize..'-'..line_width.n..line_width.u, '%.', '-'
    )
    local f = io.open(FILELIST, 'a')
    f:write(filename, '\n')
    f:close()
    return TMP..'/'..filename
end

function lilypond_fragment(ly_code, line_width, staffsize)
    line_width, staffsize = extract_size_arguments(line_width, staffsize)
    ly_code = ly_code:gsub('\\par ', '\n'):gsub('\\([^%s]*) %-([^%s])', '\\%1-%2')
    local output = hash_output_filename(ly_code, line_width, staffsize)
    local compiled = false
    if not lfs.isfile(output..'-systems.tex') then
        compile_lilypond_fragment(ly_code, staffsize, line_width, output, include)
        compiled = true
    end
    write_tex(output, compiled)
end


function lilypond_file(input_file, currfiledir, line_width, staffsize, fullpage)
    line_width, staffsize = extract_size_arguments(line_width, staffsize)
    filename = splitext(input_file, 'ly')
    input_file = currfiledir..filename..'.ly'
    if not lfs.isfile(input_file) then input_file = kpse.find_file(filename..'.ly') end
    if not lfs.isfile(input_file) then err("File %s.ly doesn't exist.", filename) end
    local i = io.open(input_file, 'r')
    ly_code = i:read('*a')
    i:close()
    local output = hash_output_filename(ly_code, line_width, staffsize)
    if fullpage then output = output..'-fullpage' end
    local compiled = false
    if not ( lfs.isfile(output..'-systems.tex') or
        lfs.isfile(output..'-fullpage.pdf') ) then
        compiled = true
        if fullpage then
            run_lilypond(ly_code, output, false, dirname(input_file))
        else
            compile_lilypond_fragment(ly_code, staffsize, line_width, output, include)
        end
    end
    write_tex(output, compiled)
end


function run_lilypond(ly_code, output, include)
    mkdirs(dirname(output))
    local cmd = LILYPOND.." "..
        "-dno-point-and-click "..
        "-djob-count=2 "..
        "-dno-delete-intermediate-files "
    if include then cmd = cmd.."-I '"..lfs.currentdir().."/"..include.."' " end
    cmd = cmd.."-o "..output.." -"
    local p = io.popen(cmd, 'w')
    p:write(ly_code)
    p:close()
end

function compile_lilypond_fragment(ly_code, staffsize, line_width, output, include)
    ly_code = lilypond_fragment_header(staffsize, line_width)..'\n'..ly_code
    run_lilypond(ly_code, output, include)
end


function lilypond_fragment_header(staffsize, line_width)
    local fontdef = get_fonts()
    return string.format(
[[%%File header
\version "2.18.2"

\include "lilypond-book-preamble.ly"

#(define inside-lyluatex #t)

#(set-global-staff-size %s)


%%Score parameters
\paper{
    indent = 0\mm
    line-width = %s\%s
    #(define fonts
      (make-pango-font-tree "%s"
                            "%s"
                            "%s"
                            (/ staff-height pt 20)))
}

%%Follows original score
]],
staffsize,
line_width.n, line_width.u,
fontdef.rm, fontdef.sf, fontdef.tt
)
end


function calc_staffsize(staffsize)
    if staffsize == 0 then staffsize = fontinfo(font.current()).size/39321.6 end
    return staffsize
end


function delete_intermediate_files(output)
  i = io.open(output..'-systems.count', 'r')
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

function write_tex(output, compiled)
    local systems_file = io.open(output..'-systems.tex', 'r')
    if not systems_file then
        --[[ Fullpage score, use \includepdf ]]
        tex.print('\\includepdf[pages=-]{'..output..'}')
    else
        --[[ Fragment, use -systems.tex file]]
        local content = systems_file:read("*all")
        systems_file:close()
        if compiled then
            --[[ new compilation, calculate protrusion
                 and update -systems.tex file --]]
            local protrusion = calc_protrusion(output)
            local texoutput, nbre = content:gsub([[\includegraphics{]],
                [[\noindent]]..' '..protrusion..[[\includegraphics{]]..dirname(output))
            tex.print(texoutput:explode('\n'))
            local f = io.open(output..'-systems.tex', 'w')
            f:write(texoutput)
            f:close()
            delete_intermediate_files(output)
        else
            --[[ simply reuse existing -systems.tex file --]]
            tex.print(content:explode('\n'))
        end
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
    path = '.'
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


function get_fonts()
    --[[ This is preliminary and simply retrieves then
         font that is *currently* in use. --]]
    local family = fontinfo(font.current()).shared.rawdata.metadata['familyname']
    return {
      ['rm'] = family,
      ['sf'] = family,
      ['tt'] = family,
    }
end


mkdirs(TMP)
FILELIST = TMP..'/'..splitext(status.log_name, 'log')..'.list'
os.remove(FILELIST)
