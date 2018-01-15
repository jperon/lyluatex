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


LILYPOND = 'lilypond'
TMP = 'tmp_ly'
N = 0


function ly_define_program(lilypond)
    if lilypond then LILYPOND = lilypond end
end


function flattenContent(original_content)
  --[[ Produce a flattend string from the original content,
       including referenced files (if they can be opened.
       Other files (from LilyPond's include path) are considered
       irrelevant for the purpose of a hashsum.) --]]
    local content =""
    for i, Line in ipairs(original_content:explode('\n')) do
	if Line:find("^%s*[^%%]*\\include") then
	    local i = io.open(Line:gsub('%s*\\include%s*"(.*)"%s*$', "%1"), 'r')
	    if i then
		content = content .. flattenContent(i:read('*a'))
	    else
		content = content .. Line .. "\n"
	    end
	else
	    content = content .. Line .. "\n"
	end
    end
    return content
end


function lilypond_fragment(ly_code, line_width, staffsize)
    N = N + 1
    line_width = {['n'] = line_width:match('%d+'), ['u'] = line_width:match('%a+')}
    staffsize = calc_staffsize(staffsize)
    ly_code = ly_code:gsub('\\par ', '\n'):gsub('\\([^%s]*) %-([^%s])', '\\%1-%2')
    local output =
    TMP..'/'..string.gsub(md5.sumhexa(flattenContent(ly_code))..'-'..staffsize..'-'..line_width.n..line_width.u, '%.', '-')
    if not lfs.isfile(output..'-systems.tex') then
        run_lilypond(lilypond_fragment_header(staffsize, line_width)..'\n'..ly_code, output, true)
    end
    retour_tex(output, staffsize)
end


function lilypond_file(input_file, currfiledir, line_width, staffsize, fullpage)
    line_width = {['n'] = line_width:match('%d+'), ['u'] = line_width:match('%a+')}
    staffsize = calc_staffsize(staffsize)
    filename = splitext(input_file, 'ly')
    input_file = currfiledir..filename..'.ly'
    if not lfs.isfile(input_file) then input_file = kpse.find_file(filename..'.ly') end
    if not lfs.isfile(input_file) then err("File %s.ly doesn't exist.", filename) end
    local i = io.open(input_file, 'r')
    ly_code = i:read('*a')
    i:close()
    local output = TMP..'/'..string.gsub(md5.sumhexa(flattenContent(ly_code))..'-'..staffsize..'-'..line_width.n..line_width.u..'-', '%.', '-')
    if fullpage then output = output..'-fullpage' end
    if not lfs.isfile(output..'-systems.tex') then
        if fullpage then
            run_lilypond(ly_code, output, false, dirname(input_file))
            i = io.open(output..'-systems.tex', 'w')
            i:write('\\includepdf[pages=-]{'..output..'}')
            i:close()
        else
            run_lilypond(lilypond_fragment_header(staffsize, line_width)..'\n'..ly_code, output, true, dirname(input_file))
        end
    end
    retour_tex(output, staffsize)
end


function run_lilypond(ly_code, output, eps, include)
    mkdirs(dirname(output))
    local cmd = LILYPOND.." "..
        "-dno-point-and-click "..
        "-djob-count=2 "..
        "-ddelete-intermediate-files "
    if eps then cmd = cmd.."-dbackend=eps " end
    if include then cmd = cmd.."-I '"..lfs.currentdir().."/"..include.."' " end
    cmd = cmd.."-o "..output.." -"
    local p = io.popen(cmd, 'w')
    p:write(ly_code)
    p:close()
end


function lilypond_fragment_header(staffsize, line_width)
    return string.format(
[[%%File header
\version "2.18.2"
#(define default-toplevel-book-handler
  print-book-with-defaults-as-systems )

#(define toplevel-book-handler
  (lambda ( . rest)
  (set! output-empty-score-list #f)
  (apply print-book-with-defaults rest)))

#(define toplevel-music-handler
  (lambda ( . rest)
   (apply collect-music-for-book rest)))

#(define toplevel-score-handler
  (lambda ( . rest)
   (apply collect-scores-for-book rest)))

#(define toplevel-text-handler
  (lambda ( . rest)
   (apply collect-scores-for-book rest)))

#(define inside-lyluatex #t)

#(set-global-staff-size %s)


%%Score parameters
\paper{
    indent = 0\mm
    line-width = %s\%s
}

%%Follows original score
]],
staffsize,
line_width.n, line_width.u
)
end


function calc_staffsize(staffsize)
    if staffsize == 0 then staffsize = fontinfo(font.current()).size/39321.6 end
    return staffsize
end


function retour_tex(output, staffsize)
    local i = io.open(output..'-systems.tex', 'r')
    local contenu = i:read("*all")
    i:close()
    local texoutput, nbre = contenu:gsub([[\includegraphics{]],
        [[\includegraphics{]]..dirname(output))
    tex.print(([[\noindent]]..texoutput):explode('\n'))
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


mkdirs(TMP)
