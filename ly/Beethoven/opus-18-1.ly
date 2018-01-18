\version "2.19.20"

\include "lilypond-book-preamble.ly"

\paper {
  ragged-last = ##f
}

\header {
  % Remove default LilyPond tagline
  tagline = ##f
}

global = {
  \key f \major
  \numericTimeSignature
  \time 3/4
  \tempo "Allegro con brio"
}

scoreAViolinI = \relative f' {
  \global
  f4 \p ~ f8 ( g16 f ) e8-. f-. |
  c4 r r |
  f4  ~ f8 ( g16 f ) e8-. f-. |
  d4 r r |

  f'4 \< ~ f8 ( g16 f ) e8-. f-. |
  g2 \> ( bes,4) |
  a2 \! ( d8. bes16 ) |
  a2( g4 ) |

  f4 \f ~ f8 ( g16 f ) e8-. f-. |
  c4 r r |
  f4  ~ f8 ( g16 f ) e8-. f-. |
  d4 r r |

  f'4 \p ~ f8 ( g16 f ) e8-. f-. |
  a2 ( \< g4 ) \> |
  g4 \! ~ g8 ( a16 g ) fis8 -. g -. |
  bes2 ( a4 ) |
  a4 \! ~ a8 ( bes16 a ) g8 -. a -. |
  c4. ( bes8 a g ) |


}

scoreAViolinII = \relative f' {
  \global
  % Music follows here.
  f4 \p ~ f8 ( g16 f ) e8-. f-.
  c4 r r |
  f4 ~ f8 ( g16 f ) e8-. f-. |
  d4 r r |
  bes'2. ~ \< |
  bes2 \> ( g4 ) |
  f2 \! ( bes8. g16 ) |
  f2 ( e4 ) |

  f4 \f ~ f8 ( g16 f ) e8-. f-.
  c4 r r |
  f4 ~ f8 ( g16 f ) e8-. f-. |
  d4 r r |
  R2. |
  e'2.\p % espressivo missing!|
  R2. |
  c2. |
  R2. |
  es4. ( d8 c bes ) |


}

scoreAViola = \relative f {
  \global
  f4 \p ~ f8 ( g16 f ) e8-. f-.
  c4 r r |
  f4 ~ f8 ( g16 f ) e8-. f-. |
  d4 r r |
  d'2. \< ( |
  c2. \> ) ~  |
  c4 \! ( d f, ) |
  c'8 _( b c b c4 )

  f,4 \f ~ f8 ( g16 f ) e8-. f-.
  c4 r r |
  f4 ~ f8 ( g16 f ) e8-. f-. |
  d4 r r |
  R2.
  bes''2. \p |
  R2. |
  es2. |
  R2. |
  fis,4. ( g8 a bes ) |

}

scoreACello = \relative f {
  \global
  f4 \p ~ f8 ( g16 f ) e8-. f-.
  c4 r r |
  f4 ~ f8 ( g16 f ) e8-. f-. |
  d4 r r
  d2. \< ( |
  e2. \> ) ( |
  f4 ) \! ( d bes ) |
  c2.

  f4 \f ~ f8 ( g16 f ) e8-. f-.
  c4 r r |
  f4 ~ f8 ( g16 f ) e8-. f-. |
  d4 r r |
  R2.
  cis'2. \p |
  R2.
  \break
  fis2. |
  \once \override MultiMeasureRest.Y-extent = #'(-5 . 1)
  R2.
  bes,4. bes8 bes bes  |

}

scoreAViolinIPart = \new Staff \with {
  instrumentName = "Vl. I"
} \scoreAViolinI

scoreAViolinIIPart = \new Staff \with {
  instrumentName = "Vl. II"
} \scoreAViolinII

scoreAViolaPart = \new Staff \with {
  instrumentName = "Vla."
} { \clef alto \scoreAViola }

scoreACelloPart = \new Staff \with {
  instrumentName = "Vc."
} { \clef bass \scoreACello }

\score {
  \new StaffGroup <<
    \scoreAViolinIPart
    \scoreAViolinIIPart
    \scoreAViolaPart
    \scoreACelloPart
  >>
  \layout { }
}
