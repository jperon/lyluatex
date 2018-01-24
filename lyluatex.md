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

* Including conventions in this manual

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
