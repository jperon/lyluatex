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


function contenuIntegral(contenu)
    local content =""
    for i, Line in ipairs(contenu:explode('\n')) do
	if Line:find("^%s*[^%%]*\\include") then
	    local i = io.open(Line:gsub('%s*\\include%s*"(.*)"%s*$', "%1"), 'r')
	    if i then
		content = content .. contenuIntegral(i:read('*a'))
	    else
		content = content .. Line .. "\n"
	    end
	else
	    content = content .. Line .. "\n"
	end
    end
    return content
end


function direct_ly(ly, largeur, facteur)
    N = N + 1
    largeur = {['n'] = largeur:match('%d+'), ['u'] = largeur:match('%a+')}
    facteur = calcul_facteur(facteur)
    ly = ly:gsub('\\par ', '\n'):gsub('\\([^%s]*) %-([^%s])', '\\%1-%2')
    local sortie =
    TMP..'/'..string.gsub(md5.sumhexa(contenuIntegral(ly))..'-'..facteur..'-'..largeur.n..largeur.u, '%.', '-')
    if not lfs.isfile(sortie..'-systems.tex') then
        compiler_ly(entete_lilypond(facteur, largeur)..'\n'..ly, sortie, true)
    end
    retour_tex(sortie, facteur)
end


function inclure_ly(entree, currfiledir, largeur, facteur, pleinepage)
    largeur = {['n'] = largeur:match('%d+'), ['u'] = largeur:match('%a+')}
    facteur = calcul_facteur(facteur)
    nom = splitext(entree, 'ly')
    entree = currfiledir..nom..'.ly'
    if not lfs.isfile(entree) then entree = kpse.find_file(nom..'.ly') end
    if not lfs.isfile(entree) then err("Le fichier %s.ly n'existe pas.", nom) end
    local i = io.open(entree, 'r')
    ly = i:read('*a')
    i:close()
    local sortie = TMP..'/'..string.gsub(md5.sumhexa(contenuIntegral(ly))..'-'..facteur..'-'..largeur.n..largeur.u..'-', '%.', '-')
    if pleinepage then sortie = sortie..'-pleinepage' end
    if not lfs.isfile(sortie..'-systems.tex') then
        if pleinepage then
            compiler_ly(ly, sortie, false, dirname(entree))
            i = io.open(sortie..'-systems.tex', 'w')
            i:write('\\includepdf[pages=-]{'..sortie..'}')
            i:close()
        else
            compiler_ly(entete_lilypond(facteur, largeur)..'\n'..ly, sortie, true, dirname(entree))
        end
    end
    retour_tex(sortie, facteur)
end


function compiler_ly(ly, sortie, eps, include)
    mkdirs(dirname(sortie))
    local commande = LILYPOND.." "..
        "-dno-point-and-click "..
        "-djob-count=2 "..
        "-ddelete-intermediate-files "
    if eps then commande = commande.."-dbackend=eps " end
    if include then commande = commande.."-I '"..lfs.currentdir().."/"..include.."' " end
    commande = commande.."-o "..sortie.." -"
    local p = io.popen(commande, 'w')
    p:write(ly)
    p:close()
end


function entete_lilypond(facteur, largeur)
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
facteur,
largeur.n, largeur.u
)
end


function calcul_facteur(facteur)
    if facteur == 0 then facteur = fontinfo(font.current()).size/39321.6 end
    return facteur
end


function retour_tex(sortie, facteur)
    local i = io.open(sortie..'-systems.tex', 'r')
    local contenu = i:read("*all")
    i:close()
    local texoutput, nbre = contenu:gsub([[\includegraphics{]],
        [[\includegraphics{]]..dirname(sortie))
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
