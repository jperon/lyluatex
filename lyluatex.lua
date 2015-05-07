local err, warn, info, log = luatexbase.provides_module({
    name               = "lyluatex",
    version            = '0',
    greinternalversion = internalversion,
    date               = "2015/04/29",
    description        = "Module lyluatex.",
    author             = "The Gregorio Project (see CONTRIBUTORS.md)",
    copyright          = "2008-2015 - The Gregorio Project",
    license            = "MIT",
})


TMP = 'tmp_ly'
N = 0


local function lilypond(entree, sortie)
    os.execute(string.format(
	"lilypond "
	.."-dno-point-and-click "
	.."-dbackend=eps "
	.."-djob-count=2 "
	.."-ddelete-intermediate-files "
	.."-o %s %s",
	sortie,
	entree
    ))
end


local function entete_lilypond(facteur, largeur)
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

#(ly:set-option 'safe '#t)


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


function direct_ly(ly, largeur, facteur)
    N = N + 1
    tmp = TMP..'/f'..N..'.ly'
    f = io.open(tmp, 'w')
    f:write(ly)
    f:close()
    inclure_ly(tmp, largeur, facteur)
end


function inclure_ly(entree, largeur, facteur)
    nom = splitext(entree, 'ly')
    entree = nom..'.ly'
    if not lfs.isfile(entree) then err("Le fichier %s n'existe pas.", entree) end
    sortie = TMP..'/' ..nom..'-'..facteur..'-'..string.gsub(largeur, '%.', '-')..'.ly'
    snom = splitext(sortie, 'ly')
    mkdirs(dirname(sortie))
    if not lfs.isfile(snom..'-systems.tex')
    or lfs.attributes(sortie).modification < lfs.attributes(entree).modification
    then
	i = io.open(entree, 'r')
	o = io.open(sortie, 'w')
	o:write(entete_lilypond(facteur, largeur - 10))
	o:write(i:read('*a'))
	o:close()
	i:close()
	lilypond(sortie, snom)
    end
    i = io.open(snom..'-systems.tex', 'r')
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


mkdirs(TMP)
