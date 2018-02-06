---
documentclass: lyluatexmanual
title: "\\lyluatex"
author:
- Fr. Jacques Peron
- Urs Liska
- Br. Samuel Springuel
toc: yes
abstract: >
  \lyluatex\ is a \LaTeX package that \dots
---

# Introduction

* General idea
* Main features
* lilypond-book
* Minimal Working Example

## Installation

# Usage

\lyluatex\ is loaded with the command `\usepackage{lyluatex}` which also accepts
a number of `key=value` options.  Their general use is described in the [Option
Handling](#option-handling) section below.

\lyIssue{Note:} \lyluatex\ can only be used with \LuaLaTeX, and compiling with
any other \LaTeX\ engine will fail.

\lyIssue{NOTE:} \lyluatex\ requires that \LuaLaTeX\ is started with the
`--shell-escape` command line option to enable the execution of arbitrary shell
commands, which is necessary to let LilyPond compile the inserted scores
on-the-fly.  However, this opens a significant security hole, and only fully
trusted input files should be compiled.

## Basic Operation

Once \lyluatex\ is loaded it provides commands and environments to include
musical scores and score fragments which are produced using the GNU LilyPond
score writer.  They are encoded in LilyPond input language, either directly in
the `.tex` document or in referenced standalone files.  \lyluatex\ will
automatically take care of compiling the scores if necessary -- making use of an
intelligent caching mechansim --, and it will match the score's layout to that
of the text document.  \lyluatex\ will produce PDF image files which are
automatically included in their own paragraphs or as full pages, but more
sophisticated integrations are possible in combination with the `musicexamples`
package^[[https://github.com/uliska/musicexamples](https://github.com/uliska/musicexamples)]
(see section [musicexamples](#musicexamples)).


 \lyluatex\ aims at being a drop-in replacement for the `lilypond-book`
 preprocessor shipping with
 LilyPond.^[[http://lilypond.org/doc/v2.18/Documentation/usage/lilypond_002dbook](http://lilypond.org/doc/v2.18/Documentation/usage/lilypond_002dbook)]


\lyCmd{lilypond}
Very short fragments of LilyPond code can directly be input using the \cmd{lilypond} command:

```lilypond
\lilypond{ c' d' e' }
```

\lilypond{ c' d' e' }

Note that the sequence of notes is implicitly wrapped in a LilyPond music expression, but it is also possible to pass a “real” music expression:

```lilypond
\lilypond{ \relative { c' d e }}
```

\lilypond{ \relative { c' d e }}

\lyMargin{lilypond\index{lilypond}}
More elaborate scores can be enclosed in the `lilypond` environment:

```lilypond
\begin{lilypond}
music = \relative {
  c d e
}

\score {
  \new ChoirStaff \with {
    instrumentName = "2 Fl."
  } <<
    \new Staff \transpose c c' \music
    \new Staff {
      \clef bass
      \music
    }
    >>
}
\end{lilypond}
```

\begin{lilypond}
music = \relative {
  c d e
}

\score {
  \new ChoirStaff \with {
    instrumentName = "2 Fl."
  } <<
    \new Staff \transpose c c' \music
    \new Staff {
      \clef bass
      \music
    }
    >>
}
\end{lilypond}

Note that the automatic wrapping does *not* work in the environment and that the
content of the environment must represent a compilable LilyPond file.

\lyCmd{lilypondfile}
Finally external files of arbitrary complexity can be referenced with

```lilypond
\lilypondfile{path/to/file}
```

Absolute and relative paths can be given.  Relative paths are searched in the
following order:

* relative to the current file's directory
* relative to all given include paths (see [LilyPond Include Paths](#include-paths)))
* relative to all paths visible to \LaTeX\ (like the package search)


## Option Handling {#option-handling}

All aspects of \lyluatex's behaviour can be configured in detail through
*options*.  Through a unified interface all options can be set as *package
options* or as *local options*, and they can be changed anywhere in the
document.  Note that not each approach is suitable for every option: the option
to clean the temporary directory only makes sense as a package option for
example, or you can't reasonably apply a label other than locally to a single
score.

All options are `key=value` options, and options that are *not* set explicitly
will use their default value which is documented with each option.  Boolean
options don't have to be set to `true` explicitly, using the option alone will
do that as well, for example: `[debug=true]` is equivalent to `[debug]`.

\lyMargin{Package Options\index{Package Options}}
Options can be set globally through package options, which are used with

```tex
\usepackage[key1=value1,key2=value2]{lyluatex}
```

\lyMargin{Local Options\index{Local Options}}

Options can also be applied on a per-score basis through optional arguments to
the individual command or environments:

```tex
\lilypondfile[key1=value1]{path/to/file.ly}

\lilypond[key1=value1]{ c' d' e' }

\begin{lilypond}[key1=value1]
{
  c' d' e'
}
\end{lilypond}
```

\lyCmd{lysetoption}
At any place in the document the value of an option can be changed using

```tex
\lysetoption{key}{new-value}
```

The option will take effect from now on as a package option until it is changed
again.  Note that this may or may not make sense with a given option.  For
example the \option{tmpdir} option should only be modified in very special and
sophisticated set-ups.

Local options will override this value as with package options.


## System-by-System, Fullpage, and Inline Scores

\lyOption{insert}{systems}
Scores can be included in documents in three basic modes: system-by-system,
fullpage, and inline.  The system-by-system mode is the default and includes a
score as a sequence of images, one for each system.  This allows \LaTeX\ to have
the systems flow over page breaks and to adjust the space between systems to
vertically justify the systems on the page.

Insertion mode can be controlled with the \option{insert} option, whose three
valid values are \option{systems} (default), \option{fullpage}, and
\option{inline}.

### System-by-System

\lyMargin{\texttt{insert=systems}}
With this default option each score is compiled as a sequence of PDF files
representing one system each. By default the systems are separated by a
`\linebreak` and form one paragraph together.

\lyCmd{betweenLilyPondSystem}
However, if a macro \cmd{betweenLilyPondSystem} is defined it will be expanded
between each system. This macro must accept one argument, which will be the
number of systems already printed in the score (‘1’ after the first system).
With this information it is possible to resond individually to systems (e.\,g.
“print a horizontal rule after each third system”).  But a more typical use case
is to insert some vertical glue space between the systems, ignoring the system
count:

```tex
\newcommand{\betweenLilyPondSystem}[1]{%

\medskip
}
```

\lyCmd{preLilyPondExample, \cmd{postLilyPondExample}}
If either of these macros is defined it will be expanded immediately before or
after the score.  This may for example be used to wrap the example in
environments, but usually it will make more sense to use the
\option{musicexamples} integration (see [musicexamples](#musicexamples)).

### Fullpage

\lyMargin{\texttt{insert=fullpage}}
With \option{insert} set to `fullpage` the score is compiled to a single PDF
file that is included through \cmd{includepdf}.  The layout of such scores can
be configured through a number of [alignment options](#alignment).

\lyOption{fullpagestyle}{}

\lyOption{print-page-number}{false}

These two options work together basically deciding who is responsible for
printing headers and footers, LilyPond or \LaTeX.  \option{fullpagestyle} is
equivalent to \LaTeX's \cmd{pagestyle} and accepts anything that the current
pagestyle can be set to. By default the current pagestyle will be continued
throughout the score. *NOTE:* This is different from the usual behaviour of
\cmd{includepdf} which sets the pagestyle to `empty`. So by default \LaTeX\ will
continue to print headers and footers, including page numbers.

\option{print-page-number} decides whether LilyPond prints page numbers in the
score.  By default this is set to `false`, so the default setting of these two
options means that LilyPond does *not* print page numbers while
\LaTeX\ continues to print headers and footers.

### Inline

\lyMargin{\texttt{insert=inline}}
This option, which is intended to insert musical notation inline in the
continuous text, has not been implemented yet.


## Score Layout

### `line-width`

### `staffsize`

### Alignment {#alignment}

## Miscellaneous Options

### LilyPond Include Paths {#include-paths}

The default reference point for \lyluatex's operations is the current `.tex`
file.  It will look in its directory for referenced LilyPond input files, and
include directives in LilyPond code will initially search there too.  As a
specialty \lyluatex\ also finds all files that \LaTeX\ can see, i.\\,e. all files
in the `\textsc{texmf}` tree.

\lyOption{includepaths}{./}

The \option{includepaths} option accepts a comma-separated list of paths that
will serve as paths for both \lyluatex\ and LilyPond.  The given paths are
passed along to LilyPond's include path so any \cmd{include} in a LilyPond file
will start its relative searches on any of its paths.

\lyluatex\ will use these paths when searching for external LilyPond files
referenced by \cmd{lilypondfile}.  Absolute paths can of course be used, and
relative pahts are interpreted in the following order:

* relative to the current `.tex` file
* relative

**TODO:** What actually happens when an include path is given as relative? Will all lookups go through all the variants? Or is the assignment of a relative "inlcudepath" really clear?

### LilyPond Executable

### Temp Directory for scores

* tmpdir
* cleantmp

### Handling LilyPond Failures{#lilypond-failures}

Compiling a score with LilyPond can produce several types of problems which will
be detected and handled (if possible) by \lyluatex.  The most basic problem is
when LilyPond can't be started at all.  \lyluatex\ will correctly determine and
report an error if \LuaLaTeX\ has been started without the
\option{--shell-escape} option or if the \option{program} option doesn't point
to a valid LilyPond executable.

Two other situations that are correctly recognized are when LilyPond *reports* a
compilation failure but still produces a (potentially useful) score, and when
LilyPond actually fails to engrave a score. How this is handled is controlled by
the \option{debug} and \option{showfailed} options.

\lyOption{debug}{false}
If LilyPond reports an error and \option{debug} is set to `true` then
\lyluatex\ will save both the generated LilyPond code and the complete log
output to a `.ly` and a `.log` file in the temporary directory. The file names
are printed to the console for easy reference.  Otherwise only a general warning
will be issued.  This will happen regardless of whether a score file is produced
or not.

\lyOption{showfailed}{false}

If LilyPond failed to produce a score and \option{showfailed} is set to `false`
then the \LaTeX\ compilation will stop with an error.  If on the other hand
\option{showfailed} is set to `true` only a warning is issued and a box with an
informative text is typeset into the resulting document.

## Font Handling

\lyOption{pass-fonts}{true}
User the text document's fonts in the LilyPond score.

\lyOption{current-font-as-main}{true}
Use the font family *currently* used for typesetting as LilyPond's main font.

The choice of fonts is arguably the most obvious factor in the appearance of any
document, be it text or music.  In text documents with interspersed scores the
text fonts should be consistent between text and music sections. \lyluatex\ can
handle this automatically by passing the used text fonts to LilyPond, so the
user doesn't have to worry about keeping the scores' fonts in sync with the text
document.

Before generating any score \lyluatex\ retrieves the currently defined fonts for
\cmd{rmfamily}, \cmd{sffamily}, and \cmd{ttfamily}, as well as the font that is
currently in use for typesetting.  By default the *current* font is used as the
roman font in LilyPond, while `sans` and `mono` fonts are passed to their
corresponding families.  This ensures that the score's main font is consistent
with the surrounding text.  However, this behaviour may not be desirable because
it effectively removes the roman font from the LilyPond score, and it may make
the *scores* look inconsistent with each other.  Therefore \lyluatex\ can also
just pass the three font families to their LilyPond counterparts by setting
\option{current-font-as-main} to `false`.

If fonts are explicitly defined in a \cmd{paper \{\}} block in the LilyPond
input this takes precedence over the automatically transferred fonts.

\lyIssue{Note:} So far only the main *font family* is used by LilyPond, but it is intended to add support for OpenType features in the future.

\lyIssue{Note:} LilyPond handles font selection differently from \LuaTeX and can
only look up fonts that are installed as system fonts. For any font that is
installed in the `texmf` tree LilyPond will use an arbitrary fallback font.
However, it doesn't matter whether the fonts are selected by their family or
file names.

Scores that differ *only* by their fonts are considered different by
\lyluatex\ and therefore recompiled correctly.

# Cooperations

## `musicexamples`{#musicexamples}

# Appendix

\printindex
