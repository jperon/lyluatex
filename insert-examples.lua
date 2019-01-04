#!/usr/bin/env lua

if #arg < 2 then return end

local latex = [[
\addcontentsline{toc}{subsection}{%s}
\hypertarget{%s}{}
%s
]]

local function texoutput(n, i)
    local c = {}
    local f = io.open('examples/'..n..'.tex')
    local iter = f:read('*a'):gmatch('[^\n]+')
    f:close()
    repeat until iter() == [[\begin{document}]]
    for l in iter do
        if l == [[\end{document}]] then break else table.insert(c, l) end
    end
    return latex:format(i, n, table.concat(c, '\n')):gsub('%%','%%%%')
end

local content, dest = io.open(arg[1]):read('*a'), io.open(arg[2], 'w')
local includecmd = [[\includeexample{([^}]*)}{([^}]*)}]]
for n, i in content:gmatch(includecmd) do
    content = content:gsub(includecmd, texoutput(n, i), 1)
end
dest:write(content)
dest:close()
