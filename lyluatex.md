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


\lyMargin{\cmd{lilypond}}
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

\lyMargin{\texttt{lilypond}}
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

\lyMargin{\cmd{lilypondfile}}
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

The behaviour of \lyluatex\ can be configured in detail.  For most aspects
(except when it doesn't make sense) there are global and local options, as well
as commands to change the behaviour along the way.  Currently \lyluatex\ only supports explicit boolean arguments:

```tex
% Correct:
[key1=true,key2=false]

% Incorrect:
[key1] % as meaning the same as above
```


#### Package Options
Options can be set globally through package options, which are used with

```tex
\usepackage[key1=value1,key2=value2]{lyluatex}
```

#### Local Options

Options can also be applied on a per-score basis through optional arguments to
the individual command or environments:

```tex
\includely[key1=value1]{path/to/file.ly}
\lily[key1=value1]{ c' d' e' }
\begin{ly}[key1=value1]
{
  c' d' e'
}
\end{ly}
```

#### Switching Commands

Most options can be changed within the document to apply to all subsequent
scores instead of only the current one.  These commands generally expect one
argument, but details are described below.

#### Convention in this Manual

*Options* are printed with some negative indent. The option name is printed in
bold face, followed by a parenthesized default value. At the end of the line is
an indicator showing whether the option can be applied as package and/or as
local option:

\lyOption{option-name}{default}{pkg/local}
followed by a description.

*Commands* look very much the same but (of course) have a leading backslash. The
item gives some information on the number of arguments (usually 1):

\lyCmd{commandName}{1}

## Score Layout

### `line-width`

### `staffsize`

### Full Page Scores and Fragments

### Alignment

## Miscellaneous Options

### LilyPond Include Paths [#include-paths]

### LilyPond Executable

### Temp Directory for scores

* tmpdir
* cleantmp

### Handling Failed LilyPond Compilations


## Font Handling

The choice of fonts is arguably the most obvious factor in the appearance of any
document, be it text or music.  In text documents with interspersed scores the
text fonts should be consistent between text and music sections. \lyluatex\ can
handle this automatically by passing the used text fonts to LilyPond, so the
user doesn't have to worry about keeping the scores' fonts in sync with the text
document.

Before generating any score \lyluatex\ retrieves the currently defined fonts for
\cmd{rmfamily}, \cmd{sffamily}, and \cmd{ttfamily}, as well as the font that is
currently in use for typesetting.  By default the *current* font is used as the
roman font in LilyPond, while sans and mono fonts are passed to their
corresponding families.  This ensures that the score's main font is consistent
with the surrounding text.  However, this behaviour may not be desirable because
it effectively removes the roman font from the LilyPond score, and it may make
the *scores* look inconsistent with each other.  Therefore \lyluatex\ can also
just pass the three font families to their LilyPond counterparts.  If fonts are
explicitly defined in a \cmd{paper \{\}} block in the LilyPond input this takes
precedence over the automatically transferred fonts.

\lyIssue{Note:} So far only the main *font family* is used by LilyPond, but it is intended to add support for OpenType features in the future.

\lyIssue{Note:} LilyPond handles font selection differently from \LuaTeX and can
only look up fonts that are installed as system fonts. For any font that is
installed in the `texmf` tree LilyPond will use an arbitrary fallback font.
However, it doesn't matter whether the fonts are selected by their family or
file names.

Scores that differ *only* by their fonts are considered different by
\lyluatex\ and therefore recompiled correctly.

\lyOption{pass-fonts}{true}{pkg/local} When set to `false` text fonts are *not*
transferred to LilyPond.

\lyCmd{lilypondPassFonts}{1} Change behaviour from here on. Possible values: ‘true’ / ‘false’.

# Cooperations

## `musicexamples`{#musicexamples}
