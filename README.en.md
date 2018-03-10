# lyluatex

Alternative to lilypond-book for lualatex

## Installation

### For a single document

Copy `lyluatex.sty` and `lyluatex.lua` into the folder containing the document
you wish to typeset.

### For all documents compiled with your LaTeX distribution

#### TeXLive version

Just run this command :

```bash
tlmgr install lyluatex
```

#### Last version

Copy `lyluatex.sty` and `lyluatex.lua` from this repository into your texmf
tree, then run `mktexlsr`.

## Usage

In the preable of your document, include the package `lyluatex`:

```TeX
\usepackage{lyluatex}
```

The `program` option permits the definition of an alternative path to
`lilypond`, for example:

```TeX
\usepackage[program=/opt/lilypond-dev/lilypond]{lyluatex}
```

Thereafter, you can include a lilypond file with the command:

```TeX
\lilypondfile[staffsize=17]{PATH/TO/THE/FILE}
```

The argument `staffsize`, which is optional, changes the size of the score.  You
can change the size for all the subsequent scores in a document by placing the
following command before your first include statement to be so affected:

```TeX
\lysetoption{staffsize}{24}
```

Next, you simply need to compile the document normally with the command
`lualatex -shell-escape` :

```bash
lualatex -shell-escape DOCUMENT.TEX
```

Another "more secure" option is to add `lilypond` and `gs` to default allowed commands :

```bash
shell_escape_commands=$(kpsewhich -expand-var '$shell_escape_commands'),lilypond,gs lualatex DOCUMENT.TEX
```

On systems with low RAM, when working on big documents, you could encounter
*buffer overflows* in `lilypond` calls. In that case, first compile with option
`-draftmode`, then compile again without this option.

You can also input music directly into your docoment with the `lilypond` environment.
This is only recommended for relatively short snippets.  For example:

```TeX
\begin{lilypond}
\relative c' { c d e f g a b c }
\end{lilypond}
```

Finally, for truly short snippets, there is also the `\lily` command.  Example:

```TeX
\lilypond[staffsize=12]{c' d' g'}
```

**Nota bene:** The `\lilypond` command *does not* support blocks of LilyPond
code with explicit `\score` blocks.  Such code must be included with the
`lilypond` environment or as a separate file.

## Migration from `lilypond-book`

In order to facilitate the migration from `lilypond-book`, `\lilypondfile`,
the environment `lilypond` and the command `\lilypond` should work nearly
as with `lilypond-book` ; for even more identical behaviour, call `lyluatex`
like follows:

```TeX
\usepackage[program=/opt/lilypond-dev/lilypond]{lyluatex}
```

That way, documents typeset with `lilypond-book` can be adapted to use
`lyluatex` without much difficulty.
