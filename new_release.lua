#! /usr/bin/env lua
local lfs = require"lfs"

local VERSION = '1.1.1'
local DATE = '2022/11/07'

local function read(stream)
  if not stream then return end
  local r = stream:read('*a')
  stream:close()
  return r
end

local function update_string(before, after)
  for f in lfs.dir('.') do
    if lfs.attributes(f, "mode") == "file" then
      local text, n = read(io.open(f)):gsub(before, after)
      if n > 0 then
        print('', '- '..f)
        local output = io.open(f, 'w')
        output:write(text)
        output:close()
      end
	end
  end
end

if arg and arg[0] then
  local version = arg[1]
  local date = read(io.popen('git log -n1 --date=short --format="%ad"')):gsub('-', '/'):sub(1, -2)
  if version and date then
    print('Updated version number:')
    update_string(VERSION, version)
    print('\nUpdated release date:')
    update_string(DATE, date)
    print('\nUpdated copyright:')
    update_string([[([Cc]opyright.*2015[%-]*)%d%d%d%d(.*)]], '%1'..date:sub(1,4)..'%2')
  end
end