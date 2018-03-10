#!/usr/bin/env lua

local hd, dc, ft, tmp =
    io.open('examples-header.tex'),
    io.open(arg[1]:match('(.*)%.tex$') or arg[1]..'.tex'),
    io.open('examples-footer.tex'),
    io.open('tmp.tex', 'w')
tmp:write(hd:read('*a')..'\n'..dc:read('*a')..'\n'..ft:read('*a'))
tmp:close()
hd:close()
dc:close()
ft:close()

os.execute(('latexmk --jobname="%s" tmp'):format(arg[1]))
