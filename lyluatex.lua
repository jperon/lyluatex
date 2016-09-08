local err, warn, info, log = luatexbase.provides_module({
    name               = "lyluatex",
    version            = '0',
    greinternalversion = internalversion,
    date               = "2016/09/08",
    description        = "Module lyluatex.",
    author             = "The Gregorio Project (see CONTRIBUTORS.md)",
    copyright          = "2008-2016 - The Gregorio Project",
    license            = "MIT",
})

local md5 = require 'md5'


LILYPOND = 'lilypond'
TMP = 'tmp_ly'
N = 0


function ly_definir_programme(lilypond)
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
    facteur = calcul_facteur(facteur)
    ly = ly:gsub('\\par ', '\n')
    local sortie = TMP..'/'..string.gsub(md5.sumhexa(contenuIntegral(ly))..'-'..facteur..'-'..largeur, '%.', '-')
    if not lfs.isfile(sortie..'-systems.tex') then
        compiler_ly(entete_lilypond(facteur, largeur - 10)..'\n'..ly, sortie)
    end
    retour_tex(sortie)
end


function inclure_ly(entree, currfiledir, largeur, facteur)
    facteur = calcul_facteur(facteur)
    nom = splitext(entree, 'ly')
    entree = currfiledir..nom..'.ly'
    if not lfs.isfile(entree) then entree = kpse.find_file(nom..'.ly') end
    if not lfs.isfile(entree) then err("Le fichier %s.ly n'existe pas.", nom) end
    local i = io.open(entree, 'r')
    ly = i:read('*a')
    i:close()
    local sortie = TMP..'/' ..string.gsub(md5.sumhexa(contenuIntegral(ly))..'-'..facteur..'-'..largeur, '%.', '-')
    if not lfs.isfile(sortie..'-systems.tex') then
        compiler_ly(entete_lilypond(facteur, largeur - 10)..'\n'..ly, sortie, dirname(entree))
    end
    retour_tex(sortie)
end


function compiler_ly(ly, sortie, include)
    mkdirs(dirname(sortie))
    local commande = LILYPOND.." "..
        "-dno-point-and-click "..
        "-dbackend=eps "..
        "-djob-count=2 "..
        "-ddelete-intermediate-files "
    if include then commande = commande.."-I "..lfs.currentdir()..'/'..include.." " end
    commande = commande.."-o "..sortie.." -"
    local p = io.popen(commande, 'w')
    p:write(ly)
    p:close()
end


function entete_lilypond(facteur, largeur)
    return string.format(
[[%%En-tête
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


#(set-global-staff-size %s)


%%Paramètres de la partition
\paper{
    indent = 0\mm
    line-width = %s\pt
}

%%Partition originale
]],
facteur,
largeur
)
end


function calcul_facteur(facteur)
    if facteur == 0 then facteur = fontinfo(font.current()).size/39321.6 end
    return facteur
end


function retour_tex(sortie)
    local i = io.open(sortie..'-systems.tex', 'r')
    contenu = i:read("*all")
    i:close()
    texoutput, _ = string.gsub(
        contenu,
        [[includegraphics{]], [[includegraphics{]]..dirname(sortie)
    )
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
