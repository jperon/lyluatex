\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{lyluatexmanual}

\LoadClass{lyluatexbase}

\RequirePackage{fontspec}
\RequirePackage{microtype}
\RequirePackage{libertine}
\setmonofont[Scale=MatchLowercase,StylisticSet=1]{InconsolataN}
\defaultfontfeatures{
	Ligatures=TeX,
	Scale=MatchLowercase,
	Numbers=Proportional,
	Numbers=OldStyle
}
\frenchspacing

\RequirePackage{makeidx}
\makeindex
\RequirePackage[colorlinks=true]{hyperref}

\newcommand{\linkexample}[2]{
    \addcontentsline{toc}{subsection}{#2}
    \hypertarget{#1}{}
}
