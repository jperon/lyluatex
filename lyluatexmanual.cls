\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{lyluatexmanual}

\LoadClass[DIV=11]{scrartcl}
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

\usepackage{lyluatex}

\usepackage{makeidx}
\makeindex
\usepackage[colorlinks=true]{hyperref}

\newcommand{\cmd}[1]{%
\textcolor{blue}{\textbackslash \texttt{#1}}}

\newcommand{\option}[1]{%
\textcolor{blue}{\texttt{#1}}%
}

\newcommand{\lyMargin}[1]{%

\medskip
\hspace*{-1em}%
\noindent%
\textcolor{blue}{#1}
\nopagebreak
}

\newcommand{\lyOption}[2]{%
\lyMargin{\texttt{#1} {\small \emph{(#2)}}\index{#1}}}

\newcommand{\lyCmd}[1]{%
\lyMargin{\texttt{\textbackslash #1}\index{\textbackslash #1}}}

\newcommand{\lyIssue}[1]{%
\lyMargin{\textbf{\textcolor{red}{#1}}}}
