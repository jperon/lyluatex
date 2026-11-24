#! /usr/bin/env lua
local lfs = require"lfs"

local VERSION = '1.1.8'
local DATE = '2026/11/24'

local function read(stream)
  if not stream then return end
  local r = stream:read('*a')
  stream:close()
  return r
end

local function plain(str) return (str:gsub('%p', '%%%0')) end

local function update_string(before, after, skip)
  for f in lfs.dir('.') do
    if f ~= skip and lfs.attributes(f, "mode") == "file" then
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
  local date = os.date('%Y/%m/%d')
  if version then
    print('Updated version number:')
    -- CHANGES mentions the previous release in its history.
    update_string(plain(VERSION), version, 'CHANGES')
    print('\nUpdated release date:')
    update_string(plain(DATE), date)
    print('\nUpdated copyright:')
    update_string([[([Cc]opyright.*2015[%-]*)%d%d%d%d(.*)]], '%1'..date:sub(1,4)..'%2')
  end
end