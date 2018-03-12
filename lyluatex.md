---
documentclass: lyluatexmanual
title: "\\lyluatex"
subtitle: "1.0b"
author:
- Fr. Jacques Peron
- Urs Liska
- Br. Samuel Springuel
toc: yes
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

* Using LilyPond to compile musical scores directly from within the \LaTeX\ run
* Intelligent caching of engraved scores, avoiding recompilation when possible
* Matching of layout and appearance to perfectly fit the scores into the text document
* Comprehensive configuration through global and per-score options

## Installation

### For a single document

Copy `lyluatex.sty` and `lyluatex.lua` into the folder containing the document
you wish to typeset.

### For all documents compiled with your LaTeX distribution

#### TeXLive version

Just run this command :

```
tlmgr install lyluatex
```

#### Latest version

Copy `lyluatex.sty` and `lyluatex.lua` from this repository into your `TEXMF`
tree, or clone this repostory into your `TEXMF` tree using Git, then run
`mktexlsr`. Note that in this case your local copy will shadow the version
possibly installed in your \TeX\ distribution.

# Usage

\lyluatex\ is loaded with the command `\usepackage{lyluatex}` which also accepts
a number of `key=value` options.  Their general use is described in the [Option
Handling](#option-handling) section below.

By default \lyluatex\ invokes LilyPond simply as `lilypond`.  If LilyPond is
installed in another location or a specific version of LilyPond should be used
the invocation is controlled with the \option{program} option, see [The LilyPond
Executable](#program).

\lyIssue{Note:} \lyluatex\ can only be used with \LuaLaTeX, and compiling with
any other \LaTeX\ engine will fail.

\lyIssue{Note:} In order to avoid unexpected behaviour it is strongly suggested
that documents are generally compiled from their actual directory, i.e. without
referring to it through a path.

\lyIssue{NOTE:} \lyluatex\ requires that \LuaLaTeX\ is started with the
`--shell-escape` command line option to enable the execution of arbitrary
shell commands, which is necessary to let LilyPond compile the inserted scores
on-the-fly and to perform some auxiliary shell operations.
However, this opens a significant security hole,
and only fully trusted input files should be compiled.
You may mitigate (but not totally remove) this security hole by adding
`lilypond` and `gs` to `shell_escape_commands`, and using `--shell-restricted`
instead of `--shell-escape`:
look at the documentation of your \TeX\ distribution.
For example, on Debian Linux with TeXLive:

```sh
% export shell_escape_commands=$(kpsewhich -expand-var '$shell_escape_commands'),lilypond,gs
% lualatex --shell-restricted DOCUMENT.tex
```

## Basic Operation

Once \lyluatex\ is loaded it provides commands and environments to include
musical scores and score fragments which are produced using the GNU LilyPond
score writer.  They are encoded in LilyPond input language, either directly in
the `.tex` document or in referenced standalone files.  \lyluatex\ will
automatically take care of compiling the scores if necessary -- making use of an
intelligent caching mechanism --, and it will match the score's layout to that
of the text document.  \lyluatex\ will produce PDF image files which are
automatically included within the current paragraph, in their own paragraphs or
as full pages.

\lyluatex\ aims at being an upwards-compatible drop-in replacement for the
\highlight{lilypond-book} preprocessor shipping with
LilyPond.^[[http://lilypond.org/doc/v2.18/Documentation/usage/lilypond_002dbook](http://lilypond.org/doc/v2.18/Documentation/usage/lilypond_002dbook)]
which means that any documents prepared for use with `lilypond-book` should
be directly usable with \lyluatex, with some caveats:

- \option{fragment} is the default: see [Automatic wrapping](#autowrap) for
  more details about this;
- \lyluatex\ has an option \option{insert}, which defaults to \option{systems}
  for \cmd{begin\{lilypond\}} \cmd{end\{lilypond\}}, but to \option{inline}
  for \cmd{lilypond}; the last one by default reduces staff size and includes
  only the first system if there are several ones;
- \cmd{musicxmlfile} has \option{no-articulation-directions},
  \option{no-beaming}, \option{no-page-layout} and \option{no-rest-positions}
  set to `true` by default, to increase chances of getting something
  acceptable. Nevertheless, please read the note about this command below.

So, if you want \lyluatex\ to mimic as much as possible
\highlight{lilypond-book}, you should load it with options as follows:
\cmd{usepackage[nofragment, insert=systems]\{lyluatex\}}.


\lyMargin{lilypond\index{lilypond}}
The basic mode of inserting scores into text documents is the `lilypond` environment:

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

\lyluatex\ will now collect the given content and wrap it in additional LilyPond
code to create the layout and appearance according to the text document and the
user's configuration.  The resulting file is compiled with LilyPond and saved in
a temporary directory, from where it is included in the text document. A hash
value including the full content and all options will be used to determine if
the score has already been compiled earlier, so unnecessary recompilations are
avoided.


\lyCmd{lilypond}

Very short fragments of LilyPond code can be entered inline using the
\cmd{lilypond} command: `\lilypond{ c' d' e' }` \lilypond{ c' d' e' }
Fragments specified with \cmd{lilypond} are by default inserted as *inline*
scores with a smaller staff size.  For further information about the different
insertion modes read the section about [insertion modes](#insertion-mode).


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


\lyCmd{musicxmlfile}\label{musicxml}
Finally there is a command to include scores encoded as
[MusicXML](https://www.musicxml.com/) files.  These will be converted to
LilyPond input by LilyPond's `musicxml2ly` script and then compiled by
LilyPond.

\lyIssue{Note:}
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

Options can be unset (i.e. reset to their default value) through the syntax
`key=`. This can for example be used to use the default value locally when
a value has been specified globally.

Some options are complemented by a corresponding `no<option>`.  Using this
alternative is equivalent to setting an option to `false`: `nofragment` is
the same as `fragment=false`.

Finally it has to be mentioned that some options have side-effects on other
options. For example, setting `indent` to some value implicitly will set
`autoindent=false`, or `max-protrusion` will define `max-left-protrusion`
and `max-right-protrusion` if these are not set explicitly.

\lyMargin{Package Options\index{Package Options}}
Options can be set globally through package options, which are used with

```tex
\usepackage[key1=value1,key2]{lyluatex}
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

Insertion mode can be controlled with the \option{insert} option, whose  valid
values are \option{systems} (default), \option{fullpage}, \option{inline}, and
\option{bare-inline}.

### System-by-System

\lyMargin{\texttt{insert=systems}}
With this default option each score is compiled as a sequence of PDF files
representing one system each. By default the systems are separated by a
paragraph and a variable skip depending on the staffsize.

\lyCmd{betweenLilyPondSystem}
However, if a macro \cmd{betweenLilyPondSystem} is defined it will be expanded
between each system. This macro must accept one argument, which will be the
number of systems already printed in the score (‘1’ after the first system).
With this information it is possible to respond individually to systems (e.g.
“print a horizontal rule after each third system” or “force page breaks after
the third and seventh system”).  But a more typical use case is to insert
different space between the systems or using simple line breaks while ignoring
the system count:

```tex
\newcommand{\betweenLilyPondSystem}[1]{\linebreak}
```

\lyCmd{preLilyPondExample, \cmd{postLilyPondExample}}
If either of these macros is defined it will be expanded immediately before or
after the score; this may for example be used to wrap the example in
environments, though there probably are better ways to do so.
With \option{verbatim}, \cmd{preLilyPondExample} will take place after the
verbatim block, just before the score.

\lyMargin{Examples:}
For a demonstration of the system-by-system options see [Insert Systems](#insert-systems).

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

\lyMargin{\texttt{insert=inline|bare-inline}}
With \option{insert=inline} or \option{insert=bare-inline} scores can be
included *within* paragraphs. They are basically the same with regard to the
inclusion, but `bare-inline`  implicitly sets the \option{nostaff} option to
suppress staff symbol, time signature and clef.

\lyOption{inline-staffsize}{default}
By default the staff size of inline scores is determined as 2/3 of the default
staff size of regular scores, so the effective size of an inline score will
depend both on the text's font size and the current \option{staffsize} setting.
The \option{inline-staffsize} option sets an absolute staffsize in `pt`
(omitting the “`pt`”).

\lyOption{valign}{center}
Controls the vertical alignment of the score against the current line of text.
The default value `center` will align the vertical center of the image to a
virtual line `1/2em` above the baseline of the text.  `top` will align the top
edge of the image with the X-height of the text (actually: `1em` above the
baseline). `bottom` aligns the bottom of the image with the text baseline.

*Note:* The alignment works with the edges of the *image file*, there is no
notion of an “optical” center or aligning with the staff lines.

\lyOption{voffset}{0pt}
Can be used to *add* a vertical offset to the automatic alignment.

\lyOption{hpadding}{0.75ex}
Inserts some space to the left and right of the included score (except at line
start or end).

\lyMargin{Examples:}
Examples can be found in [Insert Inline](#insert-inline).

### Choosing Systems/Pages

\lyOption{print-only}{}
With the option \option{print-only} it is possible to choose which pages or
systems of a score will be included in the document.  This can for example be
used to comment on individual parts of a score without having to specify them --
potentially redundantly -- as separate scores.  Another use case is printing a
selection of scores from a PDF containing multiple scores, such as a song book
for example.

Depending on the setting of the \option{insert} option this will affect systems
or pages.  The selection of systems/pages can be specified as

* `<empty>` (default): include the whole score
* a single number: include a single page/system
* a range of numbers: include a range of pages/systems
  `{M-N}` or `{N-M}` (to print backwards)
* the special range `N-`, including all systems/pages from N throughout the end
* a comma-separated list of numbers or ranges
  `{A,B , C,D-E, F, C- B}` (freely mixed, in arbitrary order)

\lyIssue{Note:}
It is the user's responsibility to only request pages/systems that are actually
present in the score, otherwise \LaTeX\ will raise an error.

\lyMargin{Examples:}
Usage examples for this option can be found in [Choosing Systems](#print-only).

## Score Layout

One of the most obvious features of \lyluatex\ is its ability to configure the
layout and appearance of LilyPond scores from within the `.tex` document.
Without further configuration \lyluatex\ will try to match the score as closely
as possible to the layout of the surrounding text, but there are numerous
options to tweak the layout in detail.

### Dimensions

If not stated otherwise dimensions can be given in arbitrary \TeX\ units, e.g.
`200pt`, `1ex` or `3cm` or as \TeX\ lengths, e.g. `0.4\textwidth`.

#### General

\lyOption{line-width}{default}
Set the line width of the score.  By default this exactly matches the current
actual line width of the text, which also works in multicolumn settings.  See
[Alignment](#alignment) for a discussion of the details of the alignment of
staves to the text.

\lyOption{staffsize}{default}
Set the staffsize of the score.  By default (`[staffsize=default]`,
`[staffsize]` or simply omitted) this is calculated relative to the size of the
current text font, so it will give a consistent relation to the text at any font
size.  Absolute sizes can be given as a number, which is interpreted as `pt`.
For example LilyPond's own default staff size is `20`.

\lyOption{ragged-right}{default}
Set the score to ragged-right systems.
By default, single-system scores will not be justified but printed at their
“natural” width, while scores with multiple systems by default will be
justified.
With this option set to true, all systems are printed at their natural width;
with this option set to false, all systems are justified (even for
single-system scores). \option{noragged-right} is equivalent to
\option{raggedright=false}.

\lyOption{indent}{}
Defines indentation of first system (same as LilyPond's `indent`).
By default, with \option{insert=fullpage}, scores are indented;
otherwise, they aren't.
\option{noindent} is equivalent to \option{indent=0pt}.  Please also see the section about [Dynamic Indentation](#indent).

\lyOption{quote}{false}
This option, which is there for compatibility with `lilypond-book`,
reduces line length of a music snippet by $2×0.4\,in$ and puts the output into
a quotation block.
The value $0.4\,in$ can be controlled with following options.

This option isn't intended to be used with \cmd{insert=fullpage}, and won't
give a good result with it.

\lyOption{gutter, leftgutter, rightgutter, exampleindent}{$0.4\,in$}
\option{leftgutter} control the supplementary left margin of a “quoted” score,
\option{rightgutter} the right margin. If not set, they're automatically set
to \option{gutter} value; \option{exampleindent} is an alias for
\option{gutter} (for compatibility with `lilypond-book`).

#### Fullpage

There are several options that can change the basic page layout of full-page
scores.  However, by default all these options inherit their values from the
`.tex` document, and there should very rarely be the need to explicitly change
the values for these options.

\lyOption{papersize}{default}
By default the LilyPond score will have the same paper size as the text
document, but it is possible to override this with the \option{papersize}
option.  It accepts any paper sizes that are predefined in LilyPond^[see the
manual page at
[http://lilypond.org/doc/v2.18/Documentation/notation/predefined-paper-sizes](http://lilypond.org/doc/v2.18/Documentation/notation/predefined-paper-sizes)],
it is not possible to use custom paper sizes.

\lyOption{paperwidth}{\cmd{paperwidth}}

\lyOption{paperheight}{\cmd{paperheight}}

\lyOption{twoside}{default}

\lyIssue{Note:}
If \option{papersize} is set, any values of \option{paperheight} and
\option{paperwidth} are ignored.


### Alignment{#alignment}

#### Protrusion (system-by-system Scores){#protrusion}

The reference for the horizontal alignment of scores included system-by-system
is the *staff symbol*.  By default \lyluatex\ aligns the two ends of the staff
symbol with the current \cmd{linewidth}, and any score items that exceed the
staff lines to the left or right will protrude into the page margin(s):

\begin{lilypond}[nofragment,
print-only=1]
{
  \set Staff.instrumentName = "Vl."
  \shape #'((0 . 0)(0 . 0)(3 . 0)(4 . 0)) Tie
  c'1 ~ \break c'
}
\end{lilypond}

This is also how LilyPond handles margins (and the only option when including
scores with \option{insert=fullpage}).  However, \lyluatex\ provides a
configurable limit to guard against excessive protrusion.  By default this is
effectively “disabled” by being set to the length \cmd{maxdimen}, so protruding
elements may be cut off at the page border:

\begin{lilypond}[nofragment,
print-only=1]
{
  \set Staff.instrumentName = "Violin one, with damper"
  \shape #'((0 . 0)(0 . 0)(30 . 0)(24 . 2)) Tie
  c'1 ~ \break c'
}
\end{lilypond}


\lyOption{max-protrusion}{\cmd{maxdimen}}
\lyOption{max-left-protrusion}{default}
\lyOption{max-right-protrusion}{default}

These options set the protrusion limit.  If either of the `-left-` or
`-right-` options is unset then the value will be taken from `max-dimension`.
Note that this is not a fixed value for the protrusion but a *limit*, so it will
only have an effect when the actual protrusion of the score exceeds the limit.
In a way it can be understood as a dynamic variant of the \option{quote} option,
something like a “fence”.  The following two scores have the same
\option{max-left-protrusion=1cm}, but only the second is modified.

\begin{lilypond}[nofragment,%
max-left-protrusion=1cm,
print-only=1]
{
  \set Staff.instrumentName = "Vl. 1"
  c'1 ~ \break c'
}
\end{lilypond}

\begin{lilypond}[nofragment,%
print-only=1,
max-left-protrusion=1cm]
{
  \set Staff.instrumentName = "Violin one"
  c'1 ~ \break c'
}
\end{lilypond}

When the protrusion limit kicks in the score will be offset to the right by the
appropriate amount, and if necessary it will be shortened to accomodate the
right edge with its individual protrusion limit. \lyluatex\ will automatically
ensure both that the staff line doesn't exceed the text and that the protruding
elements don't exceed the limit. The following three scores demonstrate that
behaviour with \option{max-protrusion=1cm}.

The first score has elements that protrude less than the limit, so nothing is
modified:

\begin{lilypond}[nofragment,%
max-protrusion=1cm,
print-only=1]
{
  \set Staff.instrumentName = "Vl. 1"
  c'1 ~ \break
  \once \override Score.RehearsalMark.break-visibility = ##(#t #t #t)
  \mark \default
  c'
}
\end{lilypond}

In the second score the longer instrument name makes the system shift to the
right. The rehearsal mark still protrudes into the margin but is below the
threshold. The score will automatically be recompiled with a narrower line width
to ensure the staff lines don't protrude into the right margin.

\begin{lilypond}[nofragment,%
max-protrusion=1cm,
print-only=1]
{
  \set Staff.instrumentName = "Violin 1"
  c'1 ~ \break
  \once \override Score.RehearsalMark.break-visibility = ##(#t #t #t)
  \mark \default
  c'
}
\end{lilypond}

In a third score the tie has been tweaked to protrude into the margin and exceed
the limit.  As a result the score is narrowed even further, also shifting the
*right* margin.

\begin{lilypond}[nofragment,%
max-protrusion=1cm,
print-only=1]
{
  \set Staff.instrumentName = "Violin 1"
  \shape #'((0 . 0)(0 . 0)(3 . 0)(12 . 0)) Tie
  c'1 ~ \break
  \once \override Score.RehearsalMark.break-visibility = ##(#t #t #t)
  \mark \default
  c'
}
\end{lilypond}

Note that this is not achieved by *scaling* the \textsc{pdf} file but by
actually *recompiling* the score with modified \option{line-width}, thus keeping
the correct staffsize.  A warning message will inform about that fact on the
console and in the log file.

Note further that in the final example the score is short enough to fit on the
line even with the horizontal offset, so in this case there is no need to
recompile a shortened version:

\begin{lilypond}[nofragment,%
max-left-protrusion=1cm]
{
  \set Staff.instrumentName = "Violin one, with damper"
  c'1
}
\end{lilypond}

\lyMargin{Negative max-protrusion}

The protrusion limits can
also be set to *negative* lengths, which makes them behave similar to using the
\option{quote} option.  However, there is a substantial difference between the
two: using \option{quote} will apply a fixed indent, and the reference will
again be the staff lines. Any protrusion will be considered from that reference
point, so protruding elements will protrude into the margins, starting from the indent.
Using a negative protrusion limit instead will prevent *any* part of the score
to exceed that value. Twe following three scores demonstrate the difference: the
first has \option{quote, gutter=0.4in} while the second has
\option{max-protrusion=-0.4in} set.  The third has the same protrusion
limit as the second but no protruding elements.

\begin{lilypond}[nofragment,%
quote,
print-only=1]
{
  \set Staff.instrumentName = "Vl. 1"
  c'1 ~ \break c'
}
\end{lilypond}

\begin{lilypond}[nofragment,%
max-protrusion=-0.4in,
print-only=1]
{
  \set Staff.instrumentName = "Vl. 1"
  c'1 ~ \break c'1
}
\end{lilypond}

\begin{lilypond}[nofragment,%
max-protrusion=-0.4in,
print-only=1]
{
  c'1 ~ \break c'1
}
\end{lilypond}


#### Managing indentation {#indent}

\lyOption{indent}{false}
As mentioned above \option{indent} controls the indentation of the first system
in a score.  However, \lyluatex\ provides smart dynamic indent handling for
\option{insert=systems} that goes beyond simply setting the `indent` in the
LilyPond score.

\lyMargin{Deactivating indent}

The indent is deactivated if one of the following condition is true:

* The score consists of a single system
* Only the first system of a score is printed using \option{print-only=true}
* \option{print-only} is set so the first system of a score is printed but not
  in the first position.

In the first case the score is simply shifted left, but in the other cases the
score is recompiled to avoid a “hole” at the right edge.

\lyOption{autoindent}{true}

When \option{autoindent} is active protrusion handling will be modified.  If a
given protrusion limit is exceeded \lyluatex\ will not reduce the
\option{line-width} of the *whole* score but add an indent.  This is because in
many cases it is the *first* system of a score that contains significant
protruding elements. If after application of the indent the protrusion limit is
still exceeded due to other systems the line width is only reduced by the
necessary amount and the indent adjusted accordingly.

\option{autoindent} is active by default but will be deactivated if
\option{indent} is set.

\option{autoindent} will also be applied when a given indent is deactivated as
described in the previous paragraph.  This is done in order to avoid the whole
score to be narrowed because of the deactivated indent.

\lyIssue{Note:}
Handling automatic indent requires up to three recompilations of a score, but it
will only be applied when a protrusion limit is given and exceeded. Intermediate
scores are cached and won't be unnecessarily recompiled.

\lyIssue{NOTE:}

Cacluations regarding automatic indent rely on the High Resolution Bounding Box
retrieved from the final PDF file of the score. This is done using Ghostscript
with the `gs` invocation.  If this should not be available a low resolution
bounding box is used instead, which can lead to rounding errors. Note that under
certain circumstandes these rounding errors may not only lead to less accurate
alignment but to wrong decisions in the alignment process. If you encounter
wrong results please try to create a Minimal Working Example and submit it to
\lyluatex's issue
tracker^[[https://github.com/jperon/lyluatex/issues](https://github.com/jperon/lyluatex/issues)].

\lyMargin{Examples:}
A comprehensive set of examples demonstrating the dynamic indent behaviour is available in [Dynamic Indent](#dynamic-indent).

#### Vertical Alignment of Fullpage Scores

\lyOption{fullpagealign}{crop|staffline}

Controls how the top and bottom margins of a score are calculated. With `crop`
LilyPond's `margin` paper variables are simply set to those of the
\LaTeX\ document, while `staffline` pursues a different approach that makes the
outermost *stafflines* align with the margin of the text's type area.

With `crop` the pages may look somewhat uneven because the top and bottom
systems are often pushed inside the page because the *extremal* score items are
aligned to the text.  With `staffline` on the other hand it may happen that
score items protrude too much into the vertical margins.

\lyIssue{NOTE:}
The \option{fullpagealign=staffline} option is highly experimental and has to be
used with care. While positioning the extremal staves works perfectly the
approach may confuse LilyPond's overall spacing algorithms. The `stretchability`
parameters of `top-system-spacing`, `top-markup-spacing`, and
`last-bottom-spacing` are forced to `0`, which seems to “unbalance” the mutual
stretches of vertical spacing. When scores appear compressed it is possible to
experiment with (a combination of) explicitly setting `max-systems-per-page`,
`page-count`, or -- if everything else fails -- by including manual page breaks
in the score.

Another issue with \option{fullpagealign=staffline} is that it doesn't work
properly with \option{print-page-number}.  If these two options are set LilyPond
will print the page numbers at the top of the paper, without a margin.  But when
aligning the stafflines to the type area one will usually want to have
\LaTeX\ print the page headers and footers anyway.

\lyOption{extra-bottom-margin}{0}

\lyOption{extra-top-margin}{0}

These options may be used to add (or remove) some space to the vertical margins
of fullpage scores.  This can be used to create a vertical “indent” or to adjust
for scores with unusually large vertical protrusion. *Note:* This setting
affects a whole score and can't be applied to individual pages (which is a
limitaion with LilyPond).


## Score Options

### Automatic Wrapping of Music Expressions {#autowrap}

\lyOption{fragment}{true}
With this option set to \option{true}, the input code is wrapped between `{ }`,
so that you can directly enter simple code,
for example:

```TeX
\lilypond{a' b' c'}
```

This option defaults to `true` with \cmd{lilypond} and `lilypond` environment,
to `false` with \cmd{lilypondfile}.
It will be automatically disabled if a `\book`, `\header`, `\layout`,
`\paper` or `\score` block is found within the input code; but in some cases,
it will be necessary to explicitly disable it with \option{fragment=false} or
its equivalent \option{nofragment}.

\option{nofragment} and \option{relative} are mutually exclusive;
the locally-defined option will take precedence over the globally-defined one,
and if both are defined at the same level, the result will be random.

### Font Handling

\lyOption{pass-fonts}{false}
Use the text document's fonts in the LilyPond score.

The choice of fonts is arguably the most obvious factor in the appearance of any
document, be it text or music.  In text documents with interspersed scores the
text fonts should be consistent between text and music sections. \lyluatex\ can
handle this automatically by passing the used text fonts to LilyPond, so the
user doesn't have to worry about keeping the scores' fonts in sync with the text
document.

The following steps are taken when \option{pass-fonts} is `true`: Before
generating any score \lyluatex\ retrieves the currently defined fonts for
\cmd{rmfamily}, \cmd{sffamily}, and \cmd{ttfamily}, as well as the font that is
currently in use for typesetting. These fonts are included in the score compiled
by LilyPond, but if the LilyPond input explicitly defines fonts in a
\cmd{paper \{\}} block this takes precedence over the automatically
transferred fonts.

\lyIssue{Note:}
So far only the font *family* is used by LilyPond, but it is intended to add
support for OpenType features in the future.

\lyIssue{Note:}
LilyPond handles font selection differently from \LuaTeX\ and can only look up
fonts that are installed as system fonts. For any font that is installed in the
`texmf` tree LilyPond will use an arbitrary fallback font. Therefore
\option{pass-fonts} defaults to `false`.

\lyOption{current-font-as-main}{false}
Use the font family *currently* used for typesetting as LilyPond's main font.

By default \option{pass-fonts} matches, roman, sans, and mono fonts, but with
\option{current-font-as-main=false} the font that is *currently* used for
typesetting is passed to LilyPond as its “main” roman font.  This ensures that
the score's main font is consistent with the surrounding text.  However, this
behaviour may not be desirable because it effectively removes the roman font
from the LilyPond score, and it may make the *scores* look inconsistent with
each other.  Therefore \lyluatex\ by default passes the text document's three
font families to their directy LilyPond counterparts.

\lyOption{rmfamily}{}
\lyOption{sffamily}{}
\lyOption{ttfamily}{}

The roman, sans, and mono fonts can also be specified explicitly to be passed
into the LilyPond document independently from the text document's fonts.  If
*any* of these options is set \option{pass-fonts} is implicitly set to `true`.
Note that in this case for families that are *not* set explicitly the current
text document fonts are used.

If \option{rmfamily} is set explicitly then \option{current-font-as-main} is
implicitly disabled.

\lyMargin{Examples:}
Demonstrations of the different font handling features are available in
[Font Handling](#fonts).

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

Note that there is no option to suppress key signatures since a key signature is
not *implicitly* printed. *If* there should be the need to *have* a key
signature and at the same time suppress it, it's reasonable to expect this to be
explicitly done in the LilyPond code.

### Relative or Absolute Pitches {#relative}

By default LilyPond input is parsed as-is with regard to pitches.  That means
pitches are treated as absolute pitches except if the music is wrapped in a
\cmd{relative} clause.

\lyOption{relative}{0}

With the \option{relative} option set the LilyPond input is parsed in *relative*
mode, with the option value specifying the starting pitch. Zero (or an empty
value) takes the “middle C” as the origin, positive integers refer to the number
of octaves upwards, negative integers to downward octaves.

\lyIssue{Note:}
This deviates from LilyPond's usual behaviour: in LilyPond the “natural” `c`
corresponds to C3 in MIDI terminology, while `relative=0` refers to C4 instead.
This is in accordance with the use in lilypond-book.

\lyIssue{Note:}
\option{relative} is only allowed when the content is automatically wrapped in
a music expression (as described in [Automatic Wrapping](#autowrap)).

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
since multiple identical labels will trigger \LaTeX\ errors.

\lyOption{labelprefix}{ly\_}
Sets the prefix to be prepended to each label.

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

\lyOption{addversion}{false}
If \option{addversion} is set the LilyPond version used to compile the current
score is printed before the verbatim input code.

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
absolute and relative paths.
By default, relative paths are considered relative not to the current `.tex`
document's directory, but to the *current working directory*,
which is one reason why it's strongly recommended to launch \LuaLaTeX\ from
the document's directory.
Additionally, \lyluatex\ will find any file that is visible to \LaTeX\ itself,
i.e. all files in the \texttt{\textsc{texmf}} tree.
A special case are paths that start with a tilde (\textasciitilde).
This tilde (which has to be input as \cmd{string\textasciitilde} in \LaTeX)
will be expanded to the user's `HOME` directory,
which should work equally in UNIX/Linux and Windows.

\lyOption{includepaths}{./}

With the \option{includepaths} option a comma-separated list of search paths can
be specified.  These paths will be used by \lyluatex\ to locate external files,
and relative paths are searched for in the following order:

* relative to the current `.tex` file's directory (i. e. the file from which
  the score is included)
* relative to each `includepath`, in the order of their definition in the list
* using \LaTeX's search mechanism

Additionally the list of include paths is passed to LilyPond's include path, so
they can be used for including files from within the LilyPond code.  Paths
starting with the tilde will implicitly be expanded to absolute paths in that
process.

### LilyPond Executable{#program}

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

\lyOption{tmpdir}{tmp-ly}
The directory that is used for this purpose can be set with the \option{tmpdir}
option.  Its value is a relative path starting from the *current working
directory*, i.e. the directory from which \LuaLaTeX\ has been started, not
necessarily that of the `.tex` document. Note that for several reasons it is
strongly suggested to always compile documents from their own directory.

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

### PDF optimization

\lyOption{optimize-pdf}{false}
If set to `true`, each included pdf will be optimized by `ghostscript` before
inclusion. It's set to `false` by default, because it's time consuming,
and it loses information about the fonts.

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
or not.  In addition \lyluatex\ will usually delete intermediate files that are
not useful for later compilations but keep them all when \option{debug} is
active.

\lyOption{showfailed}{false}
If LilyPond failed to produce a score and \option{showfailed} is set to `false`
then the \LaTeX\ compilation will stop with an error.  This error can be
skipped, but nothing will be included in the document.  If on the other hand
\option{showfailed} is set to `true` only a warning is issued and a box with an
informative text is typeset into the resulting document.

## MusicXML options

\lyOption{xml2ly}{musicxml2ly}
This option does the same for `\musicxmlfile`
as \option{program} for `\lilypondfile`.

\lyOption{language}{}
\lyOption{absolute, lxml, verbose}{false}
\lyOption{
no-articulation-directions, no-beaming, no-page-layout, no-rest-positions
}{true}
All those options control the corresponding `musicxml2ly` switches;
please refer to
[`musicxml2ly` documentation](http://lilypond.org/doc/v2.18/Documentation/usage/invoking-musicxml2ly)
for more information.

# Using \lyluatex\ in Classes or Style Files

## Wrapping \lyluatex\ commands

\cmd{lilypond} and \highlight{lilypond} are aliases for a command and an
environment that \lyluatex\ defines internally,
respectively \cmd{lily} and \highlight{ly}.

\cmd{lily} can be wrapped within another command in an usual way;
but \highlight{ly} is quite a special environments,
which makes it a bit unusual to wrap.
You'll find more about this point in [Wrapping Commands](#wrappingcommands)

## Providing Raw filenames

\lyluatex's default mode of operations is to directly insert scores into the
document.  For this the generated PDF files of the scores are transparently
wrapped in \cmd{includegraphics} or \cmd{includepdf} commands and given
appropriate layout.

\lyOption{raw-pdf}{false}
However, for more control over the placement and handling of the scores,
especially for package developers, \option{raw-pdf} provides the option to make
available the raw file name(s) to be processed and wrapped at will. When
\option{raw-pdf} is set \lyluatex\ will implicitly and temporarily define a
command

\lyCmd{lyscore}

taking one mandatory argument, which may be empty. In this case
\cmd{lyscore\{\}} expands to the filename of the first system of the score while
\cmd{lyscore\{N\}} will return the filename of the N-th system. The special
keywords  \cmd{lyscore\{nsystems\}} and \cmd{lyscore\{hoffset\}} return the
number of systems in the score and `<hoffset>pt` as a distance to be applied to
handle protrusion.

Additionally any \lyluatex\ option can be used to retrieve the corresponding
given or calculated value. For example \cmd{lyscore\{valign\}} will return
`top`, `center`, or `bottom`. By accessing these options it is possible to make
use of information that is not part of the actual generated score but that would
otherwise be used by \lyluatex's \LaTeX\ wrapping.

\lyMargin{Examples:}
Examples on how raw filenames can be wrapped in secondary commands can be found
in [Wrapping Raw PDF Filenames](#insert-raw-pdf).

\printindex
\addcontentsline{toc}{section}{Index}

# Examples

Those examples and others may be found in
[the package repository](https://github.com/jperon/lyluatex/).

\includeexample{insert-systems}{Insert Systems}

\includeexample{insert-inline}{Insert Inline}

\includeexample{print-only}{Choosing Systems}

\includeexample{dynamic-indent}{Dynamic Indent Handling}

\includeexample{fonts}{Font Handling}

\includeexample{wrappingcommands}{Wrapping Commands}

\includeexample{insert-raw-pdf}{Wrapping Raw PDF Filenames}
