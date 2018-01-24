\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{lyluatexmanual}

\LoadClass[DIV=11]{scrartcl}
\usepackage{fontspec}
\usepackage{microtype}
\usepackage{libertine}
\setmonofont{Inconsolata}
\defaultfontfeatures{
	Ligatures=TeX,
	Scale=MatchLowercase,
	Numbers=Proportional,
	Numbers=OldStyle
}
\frenchspacing

\usepackage{lyluatex}

\newcommand{\cmd}[1]{%
\textbackslash \texttt{#1}}

\newcommand{\lyOption}[3]{%

\medskip
\hspace*{-1em}\textbf{#1} (#2) {\small \textit{#3}} ---\\}

\newcommand{\lyCmd}[2]{%

\medskip
\hspace*{-1em}\textbf{\textbackslash #1} (#2 args)---\\}

\newcommand{\lyIssue}[1]{%

\medskip
\hspace*{-1em}\textbf{\textcolor{red}{#1}}\\}
