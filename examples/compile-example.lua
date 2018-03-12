#!/usr/bin/env lua

local basename = arg[#arg]:match('(.*)%.tex$') or arg[#arg]
table.remove(arg)
local hd, dc, ft, tmp =
    io.open('examples-header.inc'),
    io.open(basename..'.tex'),
    io.open('examples-footer.inc'),
    io.open('tmp.tex', 'w')
tmp:write(hd:read('*a')..'\n'..dc:read('*a')..'\n'..ft:read('*a'))
tmp:close()
hd:close()
dc:close()
ft:close()

os.execute(string.format(
    'TEXINPUTS="..:" lualatex --shell-escape --jobname=%s %s tmp',
    basename, table.concat(arg, ' ')
))
