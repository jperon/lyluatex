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

\usepackage[colorlinks=true]{hyperref}

\newcommand{\cmd}[1]{%
\textbackslash \texttt{#1}}

\newcommand{\lyMargin}[1]{%

\medskip
\hspace*{-1em}%
\noindent%
\textcolor{blue}{#1}

}

\newcommand{\lyOption}[3]{%
\lyMargin{\texttt{}#1} (#2) {\small \textit{#3}}}

\newcommand{\lyCmd}[2]{%
\lyMargin{\texttt{\textbackslash #1} (#2 args)}}

\newcommand{\lyIssue}[1]{%
\lyMargin{\textbf{\textcolor{red}{#1}}}}
