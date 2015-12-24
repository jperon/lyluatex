# lyluatex
Alternative to lilypond-book for lualatex


## Installation

### For a single document

Copy `lyluatex.sty` and `lyluatex.lua` into the folder containing the document you wish to typeset.

### For all documents compiled with your LaTeX distribution

Copy `lyluatex.sty` and `lyluatex.lua` into your texmf tree, then run `mktexlsr`.


## Usage

In the preable of your document, include the pacakge `lyluatex`:

    \usepackage{lyluatex}
    
The `program` option permits the definition of an alternative path to `lilypond`, for examples:

    \usepackage[program=/opt/lilypond-dev/lilypond]{lyluatex}

Thereafter, you can include a lilypond file with the command:

    \includely[staffsize=17]{CHEMIN/VERS/LA/PARTITION}

The argument `staffsize`, which is optional, changes the size of the score.  You can change the size for all the subsequent scores in a document by placing the following command before your first include statement to be so affected:

    \setcounter{staffsize}{24}

Next, you simply need to compile the document normally with the command `lualatex -shell-escape` :

    lualatex -shell-escape DOCUMENT.TEX

Another "more secure" option is to add `lilypond` to default allowed commands :

    shell_escape_commands=$(kpsewhich -expand-var '$shell_escape_commands'),lilypond lualatex DOCUMENT.TEX

On systems with low RAM, when working on big documents, you could encounter *buffer overflows* in `lilypond` calls. In that case, first compile with option `-draftmode`, then compile again without this option.

You can also input music directly into your docoment with the `ly` environment.  This is only recommended for very short snippets.  For example:

    \begin{ly}
    \relative c' { c d e f g a b c }
    \end{ly}

See the document `test.en.tex` for an example.


## Migration from `lilypond-book`

In order to facilitate the migration from `lilypond-book`, `lyluatex` defines the command `\lilypondfile` with the same arguments as `\includely`.  There is also the environment `lilypond` which is the same as `ly`, and the command `\lily` should be used inplace of the command `\lilypond` of `lilypond-book`.

In this manner, documents typeset with `lilypond-book` can be adapted to use `lyluatex` with out much difficulty.  Just keep in mind the following points:

- apart from the `staffsize` parameter, the optional parameters that `lilypond-book` supports are not supported by `lyluatex` (at least for now);
- commands like `\lilypond[fragment]{c d e f}` should be changed to: `\lily{{c d e f}}`.
