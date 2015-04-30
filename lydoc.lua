local err, warn, info, log = luatexbase.provides_module({
    name               = "lydoc",
    version            = '0',
    greinternalversion = internalversion,
    date               = "2015/04/29",
    description        = "Module lydoc.",
    author             = "The Gregorio Project (see CONTRIBUTORS.md)",
    copyright          = "2008-2015 - The Gregorio Project",
    license            = "MIT",
})

function InclureLy(entree, largeur, facteur)
    entree = splitext(entree, 'ly') .. '.ly'
    if not lfs.isfile(entree) then err("Le fichier %s n'existe pas.", entree) end
    strlargeur = string.gsub(largeur, '%.', '-')
    sortie = 'tmp_ly/' .. splitext(entree, 'ly') .. '-' .. facteur .. '-' .. strlargeur .. '.ly'
    mkdirs(dirname(sortie))
    if not lfs.isfile(sortie)
    or lfs.attributes(sortie).modification < lfs.attributes(entree).modification
    then
	i = io.open(entree, 'r')
	o = io.open(sortie, 'w')
	o:write(string.format(
[[%%En-tête copié depuis lilypond-book-preamble.ly
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

#(set! output-empty-score-list #t)


#(ly:set-option 'backend 'eps)
#(ly:set-option (quote no-point-and-click))
#(define inside-lilypond-book #t)
#(define version-seen #t)


%%Paramètres de la partition
#(set-global-staff-size %s)
\paper{
    indent = 0\mm
    line-width = %s\pt
    line-width = #(- line-width (* mm  3.000000) (* mm 1))
}

%%Partition originale
]],
	    facteur,
	    largeur - 6)
	)
	o:write(i:read('*a'))
	o:close()
	i:close()
	os.execute(string.format(
	    "lilypond -o %s -djob-count=2 -ddelete-intermediate-files %s",
	    splitext(sortie, "ly"),
	    sortie
	))
    end
    i = io.open(splitext(sortie, 'ly') .. '-systems.tex', 'r')
    texoutput = i:read("*all")
    i:close()
    texoutput, _ = string.gsub(texoutput, [[includegraphics{]], [[includegraphics{]] .. dirname(sortie))
    o = io.open(splitext(sortie, 'ly') .. '-systems.tex', 'w')
    o:write(texoutput)
    o:close()
    tex.sprint([[\noindent\input{]] .. splitext(sortie, 'ly') .. '-systems' .. [[}]])
--    ))
end

function BaseName(str)
    tex.sprint(basename(str))
end

function DirName(str)
    tex.sprint(dirname(str))
end

function basename(str)
    local name = string.gsub(str, "(.*/)(.*)", "%2")
    return name
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
