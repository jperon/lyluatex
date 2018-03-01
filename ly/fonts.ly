\version "2.18"

mel = {
  \set Staff.instrumentName = "First violin"
  \tempo \markup \typewriter Allegro
  c' d' e' f'
  g' a' b' c''
  \mark \markup \sans "Sans Mark"
}

lyr = \lyricmode {
  do re mi fa so -- la si -- do
}

\score {
  <<
  \new Staff \new Voice = "mel" \mel
  \new Lyrics \lyricsto "mel" \lyr
  >>
}
