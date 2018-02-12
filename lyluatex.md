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

\lyluatex\ is a \LaTeX\ package that manages the inclusion of musical scores in
\LaTeX\ documents.  It uses the GNU LilyPond^[\url{http://lilypond.org}] score
writer to produce beautiful music elements in beautifully typeset text documents.
\lyluatex\ supports a wide range of use cases and lends itself equally well to
authoring musicological texts with music examples and preparing musical editions
with interspersed text parts, to creating song booklets used in service and to
provide work sheets for teaching and exams.

\lyluatex\ is inspired by and provides a fully compatible drop-in replacement to
[lilypond-book](http://lilypond.org/doc/v2.18/Documentation/usage/invoking-lilypond_002dbook.html),
a \LaTeX\ document preprocessor shipping with LilyPond.  However, thanks to the
use of \LuaLaTeX\ it can overcome substantial limitations of the scripted solution,
and it actually is a *superset* of `lilypond-book`, providing numerous additional
features.

\lyluatex's main features include:

* Fully automatic management of using LilyPond to compile musical scores from
  within the \LaTeX\ run
* Intelligent caching of engraved scores, avoiding recompilation when possible
* Fully automatic matching of layout and appearance to perfectly fit the scores
  into the text document
* Comprehensive configuration of the scores through options which work on global
  or per-score level
* (Planned: intelligent interaction with other packages such as
  [musicexamples](https://github.com/uliska/musicexamples),
  [lilyglyphs](https://github.com/uliska/lilyglyphs) or
  [scholarLY](https://github.com/openlilylib/scholarLY))

## Installation

# Usage

\lyluatex\ is loaded with the command `\usepackage{lyluatex}` which also accepts
a number of `key=value` options.  Their general use is described in the [Option
Handling](#option-handling) section below.

\lyIssue{Note:} \lyluatex\ can only be used with \LuaLaTeX, and compiling with
any other \LaTeX\ engine will fail.

\lyIssue{Note:} In order to avoid unexpected behaviour it is strongly suggested
that documents are generally compiled from their actual directory, i.e. without
referring to it through a path.

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
automatically included within the current paragraph, in their own paragraphs
or as full pages, but more sophisticated integrations are possible in combination
with the `musicexamples`
package^[[https://github.com/uliska/musicexamples](https://github.com/uliska/musicexamples)]
(see section [musicexamples](#musicexamples)).


\lyluatex\ aims at being an upwards-compatible drop-in replacement for the
`lilypond-book` preprocessor shipping with
LilyPond.^[[http://lilypond.org/doc/v2.18/Documentation/usage/lilypond_002dbook](http://lilypond.org/doc/v2.18/Documentation/usage/lilypond_002dbook)]
which means that any documents prepared for use with `lilypond-book` should
be directly usable with \lyluatex.


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

Fragments specified with \cmd{lilypond} are by default inserted as *inline*
scores like individual characters, while the other types are by default includes
system per system.  For further information about the
different insertion modes read the section about [insertion modes](#insertion-mode).

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
External files of arbitrary complexity can be referenced with

```lilypond
\lilypondfile{path/to/file}
```

Absolute and relative paths can be given.  Relative paths are searched in the
following order:

* relative to the current file's directory
* relative to all given include paths (see [LilyPond Include Paths](#include-paths)))
* relative to all paths visible to \LaTeX\ (like the package search)

\lyCmd{musicxmlfile}
Finally there is a command to include scores encoded as
[MusicXML](https://www.musicxml.com/) files.  These will be converted to
LilyPond input by LilyPond's `musicxml2ly` script and then compiled by
LilyPond.

\lyIssue{Note:]
This command has been added to provide compatibility with `lilypond-book`,
but it is discouraged to use it since its use implies substantial problems:

* The conversion process with `musicxml2ly` is somewhat fragile and can crash
  in unpredictable ways due to encoding problems between various versions of
  Python and Lua involved
* `musicxml2ly` itself doesn't provide totally reliable conversion results,
  even if the conversion reports successful operation.  In this case LilyPond
  may produce inferior results or may fail to compile the score completely

If there is the need to include music scores that are only available as
MusicXML files it will nearly always be the better option to independently
convert the source using `musicxml2ly` and then manually post-process the
resulting Lilypond input files.

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


## System-by-System, Fullpage, and Inline Scores (Insertion Mode){#insertion-mode}

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

One of the most obvious features of \lyluatex\ is its ability to configure the
layout and appearance of LilyPond scores from within the `.tex` document.
Without further configuration \lyluatex\ will try to match the score as closely
as possible to the layout of the surrounding text, but there are numerous
options to tweak the layout in detail.

### Dimensions

If not stated otherwise dimensions can be given in arbitrary \TeX\ units, e.g.
`200pt`, `1ex` or `3cm`.

#### General

\lyOption{line-width}{default}
Set the line width of the score.  By default this exactly matches the current
actual line width of the text, which also works in multicolumn settings.  See
[Alignment](#alignment) for a discussion of the details of the alignment of
staves to the text.

\lyOption{staffsize}{default}
Set the staffsize of the score.  By default (`[staffsize=default]` or simply
`[staffsize]`) this is calculated relative to the size of the current text font,
so it will give a consistent relation to the text at any font size.  Absolute
sizes can be given as a number, which is interpreted as `pt`. For example
LilyPond's own default staff size is `20`.

\lyOption{ragged-right}{false}
Set the score to ragged-right systems.  Single-system scores will not be
justified but printed at their “natural” width, while scores with multiple
systems be default wil be justified.  With this option that default can be
changed so that all systems are printed at their natural width.

#### Fullpage

There are several options that can change the basic page layout of full-page
scores.  However, by default all these options inherit their values from the
`.tex` document, and there should very rarely be the need to explicitly change
the values for these options.

\lyOption{papersize}{default}
Not implemented yet

\lyOption{paperwidth}{\cmd{paperwidth}}

\lyOption{paperheight}{\cmd{paperheight}}

\lyOption{twoside}{default}


### Alignment {#alignment}

#### Protrusion

#### Vertical Alignment of Fullpage Scores

\lyOption{extra-bottom-margin}{0}

\lyOption{extra-top-margin}{0}

\lyOption{fullpagealign}{staffline}

## Score Options

### Font Handling

\lyOption{pass-fonts}{false}
Use the text document's fonts in the LilyPond score.

\lyOption{current-font-as-main}{true}
Use the font family *currently* used for typesetting as LilyPond's main font
if \option{pass-fonts=false}.

The choice of fonts is arguably the most obvious factor in the appearance of any
document, be it text or music.  In text documents with interspersed scores the
text fonts should be consistent between text and music sections. \lyluatex\ can
handle this automatically by passing the used text fonts to LilyPond, so the
user doesn't have to worry about keeping the scores' fonts in sync with the text
document.

The following steps are taken when \option{pass-fonts} is `true`:
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
Therefore \option{pass-fonts} defaults to `false`. However, it doesn't matter
whether the fonts are selected by their family or file names.

### Staff Display

There are a number of options that directly affect how staves are displayed,
basically removing parts of the staff elements.  The options can be freely
combined, and a few presets have been prepared.

\lyOption{noclef}{false}
Don't print clefs.

\lyOption{notimesig}{false}
Don't print time signatures.

\lyOption{nostaffsymbol}{false}
Don't print staff lines.

\lyOption{notiming}{false}
Don't use any timing information, e.g. don't print automatic barlines.

\lyOption{notime}{false}
Preset: don't print time signatures and don't use timing (`lilypond-book`
option).

\lyOption{nostaff}{false}
Preset: suppress staff lines, clefs, and time signatures (but do use timing).

Note that there is no option to suppress key signatures because since a key
signature is not *implicitly* printed. *If* there should be the need to *have* a
key signature and at the same time suppress it, it's reasonable to expect this
to be explicitly done in the LilyPond code.

### Input Language {#language}

\lyOption{language}{}
Specify the language for LilyPond input, defaulting to LilyPond's default
language Dutch.

### Labels {#labels}

\lyOption{label}{}
If the \option{label} option is set a \cmd{label} is inserted directly before
the image.  The label name is prepended with the value of the
\option{labelprefix} option, so any references to the score have to take that
into account.

\lyIssue{Note:}
It should be obvious but \option{label} can only be used as a *local* option
since multiple labels will trigger \LaTeX\ errors.

\lyOption{labelprefix}{ly\_}
Sets the prefix to be prepended to each label.

\lyIssue{Note:}
When using \option{musicexamples} (see [musicexamples](#musicexamples)) the
prefix will be hard-coded to `xmp:`.

### Captions {#captions}

\lyOption{caption}{}
If the \option{caption} option is set then a \cmd{caption} is inserted after the
score.

\lyOption{captionbefore}{false}
If \option{captionbefore} is set to `true` then the caption is inserted *before*
the scores instead of after it.

\lyIssue{Note:}
It may seem like this option is unnecessary since entering the captions can be
entered manually just the same.  However, when using `musicexamples` (see
[musicexamples](#musicexamples)) the score is automatically wrapped in an
environment and the caption properly applied.

\lyIssue{NOTE:}
Presumably the caption suffers the same issues as \option{intertext} for
\option{verbatim}.

\lyIssue{NOTE:}
Captions haven't been implemented yet.

### Printing the Filename

For scores included by \cmd{lilypondfile} it is possible to print the filename
before the score.  This is activated by the

\lyOption{printfilename}{false}
option.  It will print the actual filename only, without any path information.

By default the filename is printed in its own unindented paragraph, including
\cmd{bigskip} between the text and the score.  However, the appearance can be
modified by renewing the command

\lyCmd{lyFilename}

The following redefinition removes any indent and prints the text
in monospace:

```TeX
\renewcommand{\lyFilename}[1]{%
\noindent \texttt{#1}\par\bigskip%
}
```

### Printing LilyPond Code

\lyOption{verbatim}{false}
Depending on the use case it may be desired to not only include the score into
the document but to also print the LilyPond input verbatim.  This can be
achieved by setting the \option{verbatim} option to `true`.  In this case first
the input code will be printed in a `verbatim` environment, followed by the
score.

\lyIssue{Note:}
Please note that input from LilyPond fragments entered with the \cmd{lilypond}
command will be printed on a single line.  But as such fragments are intended to
contain short snippets anyway this shouldn't be an issue.

\lyMargin{Partial printing}
If the LilyPond input contains a comment with the character sequence `% begin
verbatim` then everything up to and including this comment will *not* be printed
verbatim (but still used for engraving the score).  If after that `% end
verbatim` is found then the remainder of the input will be skipped too,
otherwise the code is printed to the end.

\lyOption{intertext}{}
If \option{intertext} is set to a string its value will be printed between the
verbatim code and the score.

\lyCmd{lyIntertext}
By default the intertext will be printed in its own paragraph, with a
\cmd{bigskip} glue space between it and the score.  The appearance is controlled
by the macro \cmd{lyIntertext}, and by renewing this macro the appearance can be
modified.  The following redefinition removes any indent and prints the text
blue:

```TeX
\renewcommand{\lyIntertext}[1]{%
\noindent \textcolor{blue}{#1}\par\bigskip%
}
```

\lyMargin{Syntax Highlighting}
By default printed LilyPond code will be wrapped in a \option{verbatim}
environment.  It is possible to change the way how the code is wrapped through
the command

\lyCmd{lysetverbenv}
which works very much like \cmd{newenvironment} and expects the code to be
inserted before and after the LilyPond code as its two arguments.  Typical use
cases would be to enable some syntax highlighting, although it may also be of
interest to wrap the `verbatim` environment into a `quote` environment.

So far no proper syntax highlighting for LilyPond is available in
\LaTeX\ (which is why it is not switched on by default), and the closest match today is to use the `TeX` highlighting of the \option{minted} package.

```TeX
% In the document header:
\usepackage{minted}

% anywhere in the header or the body:
\lysetverbenv{\begin{minted}{TeX}}{\end{minted}}
```

## Miscellaneous Options

### Include Paths {#include-paths}

When referencing external files with \cmd{lilypondfile} \lyluatex\ understands
absolute and relative paths.  Relative paths are considered relative to the
current `.tex` document's directory by default, and additionally \lyluatex\ will
find any file that is visible to \LaTeX\ itself, i.e. all files in the
\texttt{\textsc{texmf}} tree.  A special case are paths that start with a tilde
(\textasciitilde). This tilde (which has to be input as
\cmd{string\textasciitilde} in \LaTeX) will be expanded to the user's `HOME`
directory, which should work equally in UNIX/Linux and Windows.

\lyOption{includepaths}{./}

With the \option{includepaths} option a comma-separated list of search paths can
be specified.  These paths will be used by \lyluatex\ to locate external files,
and relative paths are searched for in the following order:

* relative to the current `.tex` file's directory
* relative to each `includepath`, in the order of their definition in the list
* using \LaTeX's search mechansim

Additionally the list of include paths is passed to LilyPond's include path, so
they can be used for including files from within the LilyPond code.  Paths
starting with the tilde will ibe mplicitly expanded to absolute paths in that
process.

### LilyPond Executable

By default \lyluatex\ will invoke LilyPond through the `lilypond` command, which
will work in many situations for default installations. However, in order to
accomodate specific installations (Windows?) or to use specific versions of
LilyPond the command to be used can be specified with the

\lyOption{program}{lilypond}

option.  If given this must point to a valid LilyPond *executable* (and not,
say, to the installation directory).  If LilyPond can be started the version
string will be printed to the console for every score, otherwise an error is
raised, as is described in [Handling LilyPond Failures](#lilypond-failures).

\lyOption{ly-version}{2.18.2} The LilyPond version to be written to the
generated LilyPond code.  This option is partially redundant with the
\option{program} option but may serve as a guard against using outdated LilyPond
versions.  This can for example be relevant when sharing documents and
\option{program} is set to its default `lilypond`, which may be something
different on another computer.

### Temporary Directory for Scores

\lyluatex\ uses a temporary directory to store LilyPond scores.  For each score
a unique name will be created using its *content* and the state of all options.
LilyPond will only be invoked to compile a score when no corresponding file is
present in the temporary directory, an approach that avoids unnecessary
recompilation while ensuring that any updates to the content or the parameters
of a score will trigger a new score.

\lyOption{tmpdir}{tmp\_ly}
The directory that is used for this purpose can be set with the \option{tmpdir}
option.  Its value is a relative path starting from the *current working
directory*, i.e. the directory from which \LuaLaTeX\ has been started, not
necessarily that of the `.tex` document. Note that for several reasons it is
strongly suggested to always compile documents from the current directory.

\lyOption{cleantmp}{false}
While the caching mechanism is great for avoiding redundant LilyPond
compilations it can quickly produce a significant number of unused score files
since *any* change will cause a new set of image files to be generated.
Therefore the \option{cleantmp} option can be used to trigger some garbage
collection after the \LaTeX\ document has been completed.

\lyluatex\ writes a `<documentname>.list` log file to the temporary directory,
listing the hashed filenames of all scores produced in the document.  If the
score has been given a \option{label} (see [Labels](#labels)) or if it is
generated from an external file this information is added to the list entry for
use in any later inspection.

With the \option{cleantmp} option in place \lyluatex\ will remove *all* files
that have not been generated from the current document. Note that this will also
remove scores that may become useful again in the future if changes to the
document will be reverted (for example if a document is created for different
output formats).  But of course these will simply be regenerated when necessary.

When the temporary directory is shared by several documents purging files might
remove scores needed by *other* documents. Therefore \lyluatex\ will read *all*
`<documentname>.list` files and only remove scores that are not referenced by
*any* list file.

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

# Cooperations

## `musicexamples`{#musicexamples}

# Appendix

\printindex
