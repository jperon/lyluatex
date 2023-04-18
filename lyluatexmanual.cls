%Lyluatex LaTeX class for the manual.
%
% Copyright (C) 2015-2023 jperon and others (see CONTRIBUTORS.md)
% License: MIT
% This file is part of lyluatex.

\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{lyluatexmanual}[2023/04/18 v1.1.5]  %%LYLUATEX_DATE LYLUATEX_VERSION

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

\newcommand{\linkexample}[2]{
    \addcontentsline{toc}{subsection}{#2}
    \hypertarget{#1}{}
}


\newcommand{\lyluatexmanualdate}{
	\directlua{
		local PC = string.char(37)
		local date_fmt = PC..'Y-'..PC..'m-'..PC..'d'
		local p = io.popen('git log -n1 --date=short --format='..PC..'"ad"', 'r')
		tex.sprint(p and p:read('*a'):sub(1,-2) or os.date(date_fmt))
		if p then p:close() end
	}
}
