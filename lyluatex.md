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

* Basic operation with the three commands/environments
* Subsection: lilypond-book compatibility chart

## Option Handling

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

### LilyPond Include Paths

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
