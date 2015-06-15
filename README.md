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

L'option facultative `program` permet de définir un chemin alternatif vers `lilypond`, par exemple :

    \usepackage[program=/opt/lilypond-dev/lilypond]{lyluatex}

Dès lors, vous pouvez inclure une partition lilypond grâce à la commande :

    \includely[staffsize=17]{CHEMIN/VERS/LA/PARTITION}

L'argument `staffsize`, optionnel, influe sur la taille de la partition. Vous pouvez changer la taille pour l'ensemble des partitions en saisissant, avant l'inclusion des partitions concernées :

    \def\staffsize{24}

Si `staffsize` est défini à 0 (sa valeur par défaut), la taille de partition sera calculée automatiquement de façon à ce que le texte de la partition ait la même taille que la police de caractères à l'endroit concerné.

Dès lors, il ne vous reste plus qu'à compiler le document comme d'habitude, avec `lualatex -shell-escape` :

    lualatex -shell-escape DOCUMENT.TEX

Une autre possibilité, plus "sécurisée", est d'ajouter `lilypond` aux commandes autorisées par défaut :

    shell_escape_commands=$(kpsewhich -expand-var '$shell_escape_commands'),lilypond lualatex DOCUMENT.TEX

Vous pouvez aussi (mais ce n'est pas recommandé, sauf pour des fragments vraiment courts) saisir directement la musique au sein de votre document, grâce à l'environnement `ly`. Par exemple :

    \begin{ly}
    \relative c' { c d e f g a b c }
    \end{ly}

Voyez le document `test.tex` pour un exemple.


## Migration depuis `lilypond-book`

Afin de faciliter la migration depuis `lilypond-book`, `lyluatex` définit une commande `\lilypondfile` acceptant les mêmes arguments que `\includely`. De même, l'environnement `lilypond` est défini comme `ly`, et la commande `\lily` peut remplacer la commande `\lilypond` de `lilypond-book`.

De la sorte, les documents saisis auparavant avec l'aide de `lilypond-book` devraient s'utiliser sans grande difficulté avec `lyluatex`, en prenant cependant en considération que :

- à part le paramètre `staffsize`, les paramètres optionnels sont pour l'instant ignorés ;
- les commandes telles que `\lilypond[fragment]{c d e f}` doivent être adaptées comme suit : `\lily{{c d e f}}`.
