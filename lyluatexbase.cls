\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{lyluatexbase}

\LoadClass[DIV=11]{scrartcl}
\RequirePackage{lyluatex}
\RequirePackage{blindtext}
\RequirePackage{libertine}
\RequirePackage{listings}
\RequirePackage{minted}
\RequirePackage{pgffor}
\lysetoption{includepaths}{./, ly/}


% Common formatting elements for manual and examples
\usepackage{xcolor}
\newcommand{\highlight}[1]{\textcolor{blue}{#1}}
\newcommand{\cmd}[1]{\highlight{\texttt{\textbackslash #1}}}
\newcommand{\option}[1]{\highlight{\texttt{#1}}}
\newcommand{\lyMargin}[1]{%

\medskip
\hspace*{-1em}%
\noindent%
\highlight{#1}
\nopagebreak
}

\newcommand{\lyOption}[2]{\lyMargin{\texttt{#1} {\small \emph{(#2)}}\index{#1}}}
\newcommand{\lyCmd}[1]{%
\lyMargin{\texttt{\textbackslash #1}\index{\textbackslash #1}}}
\newcommand{\lyIssue}[1]{\lyMargin{\textbf{\textcolor{red}{#1}}}}
