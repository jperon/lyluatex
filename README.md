# lyluatex

Alternative à lilypond-book pour lualatex

## Installation

### Pour un document isolé

Copiez `lyluatex.sty` et `lyluatex.lua` dans le dossier contenant le document concerné.

### Pour l'ensemble de votre distribution de LaTeX

#### Version disponible sur TeXLive

La commande suivante devrait faire l'affaire :

    tlmgr install lyluatex

#### Version la plus récente

Copiez depuis ce dépôt `lyluatex.sty` et `lyluatex.lua` quelque part dans votre
texmf, puis lancez `mktexlsr`.

## Utilisation

Dans le préambule de votre document, incluez le package `lyluatex` :

    \usepackage{lyluatex}

L'option facultative `program` permet de définir un chemin alternatif vers
`lilypond`, par exemple :

    \usepackage[program=/opt/lilypond-dev/lilypond]{lyluatex}

Dès lors, vous pouvez inclure une partition lilypond grâce à la commande :

    \lilypondfile[staffsize=17]{CHEMIN/VERS/LA/PARTITION}

L'argument `staffsize`, optionnel, influe sur la taille de la partition. Vous
pouvez changer la taille pour l'ensemble des partitions en saisissant, avant
l'inclusion des partitions concernées :

    \lysetoption{staffsize}{24}

Si `staffsize` est défini à 0 (sa valeur par défaut), la taille de partition
sera calculée automatiquement de façon à ce que le texte de la partition ait la
même taille que la police de caractères à l'endroit concerné.

Dès lors, il ne vous reste plus qu'à compiler le document comme d'habitude, avec
`lualatex -shell-escape` :

    lualatex -shell-escape DOCUMENT.TEX

Une autre possibilité, plus "sécurisée", est d'ajouter `lilypond` et `gs` aux commandes
autorisées par défaut :

    shell_escape_commands=$(kpsewhich -expand-var '$shell_escape_commands'),lilypond,gs lualatex DOCUMENT.TEX

Sur de gros documents, si votre ordinateur a peu de RAM, il est possible que
surgissent des erreurs *buffer overflow* dans les appels à `lilypond`. Pour
éviter cela, ajoutez d'abord l'option `-draftmode` à la commande précédente,
puis relancez la compilation sans cette option.

Vous pouvez aussi (mais ce n'est pas recommandé, sauf pour des fragments
relativement courts) saisir directement la musique au sein de votre document, grâce
à l'environnement `lilypond`. Par exemple :

    \begin{lilypond}
    \relative c' { c d e f g a b c }
    \end{lilypond}

Enfin, il est possible d'intégrer des fragments vraiment courts grâce à la
commande `\lilypond`.
Par exemple :

    \lilypond[staffsize=12]{c' d' g'}

Voyez les documents dans le dossier `examples` pour un exemple, et la
documentation complète dans `lyluatex.md`.

## Migration depuis `lilypond-book`

Afin de faciliter la migration depuis `lilypond-book`, la commande
`\lilypondfile` accepte les mêmes options que ce dernier. De même,
l'environnement `lilypond` et la commande `\lilypond` fonctionnent
à peu près comme avec `lilypond-book` ; pour un fonctionnement plus
identique encore, utilisez la commande suivante pour appeler `lyluatex` :

    \usepackage[nofragment, insert=systems]{lyluatex}

De la sorte, les documents saisis auparavant avec l'aide de `lilypond-book`
devraient s'utiliser sans grande difficulté avec `lyluatex`.
