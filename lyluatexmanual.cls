\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{lyluatexmanual}

\LoadClass{lyluatexbase}

\usepackage{fontspec}
\usepackage{microtype}
\usepackage{libertine}
\setmonofont[Scale=MatchLowercase,StylisticSet=1]{InconsolataN}
\defaultfontfeatures{
	Ligatures=TeX,
	Scale=MatchLowercase,
	Numbers=Proportional,
	Numbers=OldStyle
}
\frenchspacing

\usepackage{makeidx}
\makeindex
\usepackage[colorlinks=true]{hyperref}

\newcommand{\linkexample}[2]{\protect\hyperlink{examples/#1.pdf.1}{#2}}
