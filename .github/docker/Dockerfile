# Test image for lyluatex: a minimal TeX Live plus several LilyPond versions.
#
# Every LilyPond lives in /opt/lilypond-<major.minor>/bin and none is on the
# PATH, so a test job has to pick one explicitly.
#
# TeX Live gets only what the tests and examples load, not collection-music:
# that collection contains lyluatex from CTAN, which could shadow the copy
# under test.

FROM ubuntu:24.04

ARG LILYPOND_2_22=2.22.2
ARG LILYPOND_TARBALLS="2.24.4 2.26.0 2.27.4"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    PATH=/opt/texlive/bin/x86_64-linux:$PATH

RUN apt-get update -q \
 && apt-get install -qy --no-install-recommends \
      bzip2 ca-certificates curl fontconfig ghostscript perl python3 xz-utils \
 && rm -rf /var/lib/apt/lists/*

# LilyPond 2.22 comes as the old self-extracting installer. It covers the
# pre-2.24 path in lyluatex, where only EPS systems exist and epstopdf turns
# them into PDF.
RUN curl -fsSL -o /tmp/lp.sh \
      "https://lilypond.org/download/binaries/linux-64/lilypond-${LILYPOND_2_22}-1.linux-64.sh" \
 && sh /tmp/lp.sh --batch --prefix "/opt/lilypond-${LILYPOND_2_22%.*}" \
 && rm /tmp/lp.sh

RUN for v in $LILYPOND_TARBALLS; do \
      curl -fsSL "https://gitlab.com/lilypond/lilypond/-/releases/v$v/downloads/lilypond-$v-linux-x86_64.tar.gz" \
        | tar -xz -C /opt \
   && mv "/opt/lilypond-$v" "/opt/lilypond-${v%.*}" || exit 1; \
    done

COPY texlive.profile /tmp/texlive.profile

RUN curl -fsSL https://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz \
      | tar -xz -C /tmp \
 && /tmp/install-tl-*/install-tl --profile=/tmp/texlive.profile \
      --location https://mirror.ctan.org/systems/texlive/tlnet \
 && rm -rf /tmp/install-tl-* /tmp/texlive.profile

# Packages read by test*.tex and examples/*.tex (from their .fls files), plus
# the LuaLaTeX format, the default fonts and epstopdf for LilyPond 2.22.
RUN tlmgr install \
      latex-bin luahbtex lm epstopdf \
      bigintcalc bitset blindtext bookmark catchfile ctablestack currfile \
      environ epstopdf-pkg eso-pic etexcmds etoolbox fancyvrb filehook float \
      fontspec fvextra gettitlestring graphics graphics-cfg graphics-def \
      hycolor hyperref iftex infwarerr intcalc koma-script kvdefinekeys \
      kvoptions kvsetkeys l3kernel l3packages latex latex2pydata \
      latexconfig libertine lineno listings ltxcmds lua-uni-algos lualibs \
      luaotfload luatexbase metalogo minibox minted mptopdf pdfescape \
      pdflscape pdfpages pdftexcmds pgf pgfopts refcount rerunfilecheck \
      stringenc tex-ini-files tools trimspaces uniquecounter upquote url \
      varwidth xcolor xkeyval \
 && luaotfload-tool --update
