# lyluatex
Alternative à lilypond-book pour lualatex


## Installation

### Pour un document isolé

Copiez `lyluatex.sty` et `lyluatex.lua` dans le dossier contenant le document concerné.

### Pour l'ensemble de votre distribution de LaTeX

Copiez `lyluatex.sty` et `lyluatex.lua` quelque part dans votre texmf, puis lancez `mktexlsr`.


## Utilisation

Dans le préambule de votre document, incluez le package `lyluatex` :

    \usepackage{lyluatex}

Dès lors, vous pouvez inclure une partition lilypond grâce à la commande :

    \includely[staffsize=17]{CHEMIN/VERS/LA/PARTITION}

L'argument `staffsize`, optionnel, influe sur la taille de la partition. Vous pouvez changer la taille pour l'ensemble des partitions en saisissant, avant l'inclusion des partitions concernées :

    \setcounter{staffsize}{24}

Dès lors, il ne vous reste plus qu'à compiler le document comme d'habitude, avec `lualatex -shell-escape` :

    lualatex -shell-escape DOCUMENT.TEX

Voyez le document `test.tex` pour un exemple.


## Migration depuis `lilypond-book`

Afin de faciliter la migration depuis `lilypond-book`, `lyluatex` définit une commande `\lilypondfile` acceptant les mêmes arguments que `\includely`. Toutefois, il n'est pas possible pour le moment de mimer le comportement de l'environnement `lilypond` défini par `lilypond-book`.
