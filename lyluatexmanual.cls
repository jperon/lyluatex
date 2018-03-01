\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{lyluatexmanual}

\LoadClass{lyluatexbase}

\usepackage{fontspec}
\usepackage{microtype}
\usepackage{libertine}
\setmonofont[Scale=MatchLowercase]{Inconsolata}
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

\newcommand{\linkexample}[2]{\protect\hyperlink{#1.tex.1}{#2}}
