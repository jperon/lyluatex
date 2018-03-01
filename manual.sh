#!/bin/bash

cd examples
grep includepdf{ examples-include.tex | sed 's/\\.*{examples\/\(.*\)}/\1/g' | while read f ; do
    TEXINPUTS="../:" lualatex --shell-escape "${f}"
done
