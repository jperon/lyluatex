# lyluatex

Alternative à lilypond-book pour lualatex

[![Build Status](https://travis-ci.com/jperon/lyluatex.svg?branch=master)](https://travis-ci.com/jperon/lyluatex)

## Installation

### Pour un document isolé

Copiez `lyluatex.sty` et `lyluatex.lua` dans le dossier contenant le document concerné.

### Pour l'ensemble de votre distribution de LaTeX

#### Version disponible sur TeXLive

La commande suivante devrait faire l'affaire :

```bash
tlmgr install lyluatex
```

#### Version la plus récente

Copiez depuis ce dépôt `lyluatex.sty` et `lyluatex.lua` quelque part dans votre
texmf, puis lancez `mktexlsr`.

## Utilisation

Dans le préambule de votre document, incluez le package `lyluatex` :

```TeX
\usepackage{lyluatex}
```

L'option facultative `program` permet de définir un chemin alternatif vers
`lilypond`, par exemple :

```TeX
\usepackage[program=/opt/lilypond-dev/lilypond]{lyluatex}
```

Dès lors, vous pouvez inclure une partition lilypond grâce à la commande :

```TeX
\lilypondfile[staffsize=17]{CHEMIN/VERS/LA/PARTITION}
```

L'argument `staffsize`, optionnel, influe sur la taille de la partition. Vous
pouvez changer la taille pour l'ensemble des partitions en saisissant, avant
l'inclusion des partitions concernées :

```TeX
\setluaoption{ly}{staffsize}{24}
```

Si `staffsize` est défini à 0 (sa valeur par défaut), la taille de partition
sera calculée automatiquement de façon à ce que le texte de la partition ait la
même taille que la police de caractères à l'endroit concerné.

Dès lors, il ne vous reste plus qu'à compiler le document comme d'habitude, avec
`lualatex -shell-escape` :

```TeX
lualatex -shell-escape DOCUMENT.TEX
```

Une autre possibilité, plus "sécurisée", est d'ajouter `lilypond` et `gs` aux commandes
autorisées par défaut :

```bash
shell_escape_commands=$(kpsewhich -expand-var '$shell_escape_commands'),lilypond,gs lualatex DOCUMENT.TEX
```

Sur de gros documents, si votre ordinateur a peu de RAM, il est possible que
surgissent des erreurs *buffer overflow* dans les appels à `lilypond`. Pour
éviter cela, ajoutez d'abord l'option `-draftmode` à la commande précédente,
puis relancez la compilation sans cette option.

Vous pouvez aussi (mais ce n'est pas recommandé, sauf pour des fragments
relativement courts) saisir directement la musique au sein de votre document, grâce
à l'environnement `lilypond`. Par exemple :

```TeX
\begin{lilypond}
\relative c' { c d e f g a b c }
\end{lilypond}
```

Enfin, il est possible d'intégrer des fragments vraiment courts grâce à la
commande `\lilypond`.
Par exemple :

```TeX
\lilypond[staffsize=12]{c' d' g'}
```

Voyez les documents dans le dossier `examples` pour un exemple, et la
documentation complète dans `lyluatex.md`.

## Migration depuis `lilypond-book`

Afin de faciliter la migration depuis `lilypond-book`, la commande
`\lilypondfile` accepte les mêmes options que ce dernier. De même,
l'environnement `lilypond` et la commande `\lilypond` fonctionnent
à peu près comme avec `lilypond-book` ; pour un fonctionnement plus
identique encore, utilisez la commande suivante pour appeler `lyluatex` :

```TeX
\usepackage[nofragment, insert=systems]{lyluatex}
```

De la sorte, les documents saisis auparavant avec l'aide de `lilypond-book`
devraient s'utiliser sans grande difficulté avec `lyluatex`.

## À propos de MiKTeX

L’auteur principal de lyluatex n’utilise pas MiKTeX et ne fera pas d’effort
particulier pour assurer la compatibilité avec ce dernier. Si néanmoins vous
voulez proposer une *pull request* en ce sens, elle sera examinée et intégrée.

En l’état des choses, lyluatex fonctionne avec MiKTeX à condition d’utiliser
LilyPond 2.22. Il y a un bug connu avec LilyPond 2.24 sous MiKTeX: #301.

# Remerciements

Cf. [Contributors.md](Contributors.md)

# Contribuer

Si vous souhaitez des améliorations ou rencontrez une erreur, n'hésitez pas
à [signaler le problème](https://github.com/jperon/lyluatex/issues).
Vous pouvez aussi, si vous maîtrisez la programmation, proposer vos changements
via une [*pull request*](https://github.com/jperon/lyluatex/pulls).

Cette extension est et demeurera libre et gratuite ; si elle vous est utile et
que vous souhaitez en encourager le développement par un
[don](https://www.paypal.me/abjperon), vous en êtes vivement remercié !
