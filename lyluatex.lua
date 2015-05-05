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


function Ecrire(entree, fichier)
    fichier = splitext(fichier, 'ly') .. '.ly'
    o = io.open(fichier, 'w')
    o:write(entree)
    o:close()
end

function InclureLy(entree, largeur, facteur)
    entree = splitext(entree, 'ly') .. '.ly'
    if not lfs.isfile(entree) then err("Le fichier %s n'existe pas.", entree) end
    strlargeur = string.gsub(largeur, '%.', '-')
    sortie = 'tmp_ly/' .. splitext(entree, 'ly') .. '-' .. facteur .. '-' .. strlargeur .. '.ly'
    mkdirs(dirname(sortie))
    if not lfs.isfile(splitext(sortie, 'ly') .. '-systems.tex')
    or lfs.attributes(sortie).modification < lfs.attributes(entree).modification
    then
	i = io.open(entree, 'r')
	o = io.open(sortie, 'w')
	o:write(string.format(
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

#(ly:set-option 'safe '#t)


%%Paramètres de la partition
#(set-global-staff-size %s)
\paper{
    indent = 0\mm
    line-width = %s\pt
}

%%Partition originale
]],
	    facteur,
	    largeur - 10)
	)
	o:write(i:read('*a'))
	o:close()
	i:close()
	os.execute(string.format(
	    "lilypond -o %s -dno-point-and-click -dbackend=eps -djob-count=2 -ddelete-intermediate-files %s",
	    splitext(sortie, "ly"),
	    sortie
	))
    i = io.open(splitext(sortie, 'ly') .. '-systems.tex', 'r')
    texoutput = i:read("*all")
    i:close()
    texoutput, _ = string.gsub(texoutput, [[includegraphics{]], [[includegraphics{]] .. dirname(sortie))
    o = io.open(splitext(sortie, 'ly') .. '-systems.tex', 'w')
    o:write(texoutput)
    o:close()
    end
    tex.sprint([[\noindent\input{]] .. splitext(sortie, 'ly') .. '-systems' .. [[}]])
--    ))
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

mkdirs('tmp_ly')
