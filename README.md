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

Vous pouvez aussi (mais ce n'est pas recommandé, sauf pour des fragments vraiment courts) saisir directement la musique au sein de votre document, grâce à l'environnement `ly`. Par exemple :

    \begin{ly}
    \relative c' { c d e f g a b c }
    \end{ly}

Voyez le document `test.tex` pour un exemple.


## Migration depuis `lilypond-book`

Afin de faciliter la migration depuis `lilypond-book`, `lyluatex` définit une commande `\lilypondfile` acceptant les mêmes arguments que `\includely`. De même, l'environnement `lilypond` est défini comme dans `lilypond-book`.
