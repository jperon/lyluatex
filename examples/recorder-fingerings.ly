recorder-diagram=#(define-scheme-function (size holes) (number? list?)
	(let* (
	       (half (if (member 'thumbhf holes) 1 0))
	       (radius (* size 0.5))
	       (box-fill (cons (* -0.4 (* half size)) -0))
	       (box-list (cons (* -1 (* radius half)) (* radius half)))
	       (box-size (* size 0.4))
	       (line-list (cons (* size 1.3) 0))
	       (skip-size (* size 1.5))
	       (pencil 0.2)
	       (line-width (* size 2.5))
	       (small-radius (* 0.8 radius))
	       (baselineskip-list  (cons 'baseline-skip skip-size))
	       (linewidth-list  (cons 'line-width line-width))
	       (thumb (if (member 'thumb holes) #t #f))
	       (one (if (member 'one holes) #t #f))
	       (two (if (member 'two holes) #t #f))
	       (three (if (member 'three holes) #t #f))
	       (four (if (member 'four holes) #t #f))
	       (five (if (member 'five holes) #t #f))
	       (sixl (if (member 'sixl holes)  #t #f))
	       (sixr (if (member 'sixr holes)  #t #f))
	       (pinkyl (if (member 'pinkyl holes)  #t #f))
	       (pinkyr (if (member 'pinkyr holes)  #t #f))
	     )
  #{
	 \markup {\override #baselineskip-list
	 %\bracket
	 {
		   \center-column {\combine \draw-circle #radius #pencil #thumb
			   \filled-box #box-fill #box-list #box-size
			   \draw-line #line-list
			   \draw-circle #radius #pencil #one
			   \draw-circle #radius #pencil #two
			   \draw-circle #radius #pencil #three
			   \draw-line #line-list
			   \draw-circle #radius #pencil #four
			   \draw-circle #radius #pencil #five
			   \override #linewidth-list
			   \fill-line {\draw-circle #radius #pencil #sixl \draw-circle #small-radius #pencil #sixr }
			   \override #linewidth-list
	 \fill-line {\draw-circle #radius #pencil #pinkyl \draw-circle #small-radius #pencil #pinkyr }}}
	 \center-column {
	 \hspace #size
	 }
	 }
  #}
))



%%% fingering table %%%%
   %started from 
				%https://lsr.di.unimi.it/LSR/Snippet?id=1177
% but adapted considerably for recorder

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%

%% put the size of chart you want in place of 1.2 in (size 1.2) below

myTWFingerings =           
#(lambda (pitch ctx)
  (let ((size 1.2))
   (cond
    ((<= (ly:pitch-semitones pitch)
         4)  ; Note too low
     (markup #:sans "U"))
    ((>= (ly:pitch-semitones pitch)
         30)  ;  Note too high
     (markup #:sans "H"))
  

    ; F4
    ((= (ly:pitch-semitones pitch)
            5)
      (recorder-diagram size '(thumb one two three four five sixl sixr pinkyl pinkyr)
      ))

    ; F# or Gb4 
    ((= (ly:pitch-semitones pitch)
            6)
      (recorder-diagram size '(thumb one two three four five sixl sixr pinkyl)
     ))

    ; G4 
    ((= (ly:pitch-semitones pitch)
            7)
     (recorder-diagram size '(thumb one two three four five sixl sixr)
     ))

    ; G# or Ab4
    ((= (ly:pitch-semitones pitch)
        8)
     (recorder-diagram size '(thumb one two three four five sixl)
     ))

    ; A4 or 5
    ((= (ly:pitch-semitones pitch)
            9)
      (recorder-diagram size '(thumb one two three four five )
      ))

    ; A# or Bb4
    ((= (ly:pitch-semitones pitch)
        10)
     (recorder-diagram size '(thumb one two three four sixl sixr pinkyl pinkyr)
     ))

    ; B4
    ((= (ly:pitch-semitones pitch)
            11)
      (recorder-diagram size '(thumb one two three five pinkyl pinkyr)
      ))

    ; C5
    ((= (ly:pitch-semitones pitch)
            12)
      (recorder-diagram size '(thumb one two three four)
      ))

    ; C# or Db5
    ((= (ly:pitch-semitones pitch)
            13)
       (recorder-diagram size '(thumb one two  four five sixl) 
      ))

    ; D5
    ((= (ly:pitch-semitones pitch)
        14)
     (recorder-diagram size '(thumb one two)
    )
   )
      ; D# or Eb5
    ((= (ly:pitch-semitones pitch)
        15)
     (recorder-diagram size '(thumb one three four)
     ))
     ; E5
    ((= (ly:pitch-semitones pitch)
        16)
       (recorder-diagram size '(thumb one) 
     ))
      ; F5
    ((= (ly:pitch-semitones pitch)
        17)
      (recorder-diagram size '(thumb two) 
     ))
       ; F# or Gb5
    ((= (ly:pitch-semitones pitch)
        18)
       (recorder-diagram size '(one two)
     ))
      ; G5
    ((= (ly:pitch-semitones pitch)
        19)
       (recorder-diagram size '(two)
     ))
       ; G# or Ab5
    ((= (ly:pitch-semitones pitch)
        20)
     (recorder-diagram size '(two three four five sixl sixr pinkyl pinkyr)
     ))
      ; A5
    ((= (ly:pitch-semitones pitch)
        21)
     (recorder-diagram size '(thumbhf one two three four five sixl sixr)
     ))
       ; A# or Bb5
    ((= (ly:pitch-semitones pitch)
        22)
     (recorder-diagram size '(thumbhf one two three four sixl sixr)
     ))
      ; B5
    ((= (ly:pitch-semitones pitch)
        23)
     (recorder-diagram size '(thumbhf one two three  five)
     ))
       ; C6
    ((= (ly:pitch-semitones pitch)
        24)
     (recorder-diagram size '(thumbhf one two three)
     ))
      ; C# or Db6
    ((= (ly:pitch-semitones pitch)
        25)
      (recorder-diagram size '(thumbhf one two four)
     ))
       ; D6
    ((= (ly:pitch-semitones pitch)
        26)
      (recorder-diagram size '(thumbhf one two)
     ))
      ; D# or Eb6
    ((= (ly:pitch-semitones pitch)
        27)
      (recorder-diagram size '(thumbhf one two four  five sixl sixr)
     ))
          
   ; E6
    ((= (ly:pitch-semitones pitch)
        28)
      (recorder-diagram size '(thumbhf one two four  five)
     ))
      ; F6
    ((= (ly:pitch-semitones pitch)
        29)
      (recorder-diagram size '(thumbhf one four  five)
     ))

    (else  ;  Failover - should never get here
           (markup #:sans "X"))

    )
   ))


finger =#(define-music-function (m) (ly:music?)
	  (make-relative (m) m
		     #{
		     << $m
		     \new NoteNames {\set noteNameFunction=#myTWFingerings $m }
		     >>
		     #}
))
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

