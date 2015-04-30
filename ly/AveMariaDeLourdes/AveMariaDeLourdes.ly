\version "2.16"
\include "italiano.ly"

\header {
  tagline = ""
  composer = ""
}

MetriqueArmure = {
  \tempo 4=70
  \time 3/4
  \key do \major
}

italique = { \override Score . LyricText #'font-shape = #'italic }

roman = { \override Score . LyricText #'font-shape = #'roman }

MusiqueTheme = \relative do' {
  \partial 4 do4
  fa4 fa la
  fa4 fa la
  sol4 sol la8[( sol])
  fa2 do4
  fa4 fa la
  fa4 fa la
  sol4 sol la8[( sol])
  fa2 \breathe fa4^"Refrain"
  sib2 sib4
  la2 la4
  sol4 sol sol
  do2 la4
  sib2 sib4
  la2 la4
  sol4 sol la8[( sol])
  fa2. \bar "|."
}

Paroles = \lyricmode {
  L'heure é -- tait ve -- nu -- e,
  où l'ai -- rain sa -- cré,
  de sa voix con -- nu -- e,
  an -- non -- çait l'A -- ve.
  
  \italique
  A -- ve, a -- ve, a -- ve Ma -- rí -- a_!
  A -- ve, a -- ve, a -- ve Ma -- rí -- a_!
}

\score{
  <<
    \new Staff <<
      \set Staff.midiInstrument = "flute"
      \set Staff.autoBeaming = ##f
      \new Voice = "theme" {
        \override Score.PaperColumn #'keep-inside-line = ##t
        \MetriqueArmure
        \MusiqueTheme
      }
    >>
    \new Lyrics \lyricsto theme {
      \Paroles
    }
  >>
  \layout{}
  \midi{}
}
