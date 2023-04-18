local kpse, luatexbase, lua_options, status, tex = kpse, luatexbase, lua_options, status, tex
local err, warn, info = luatexbase.provides_module({
  name = "lyluatex",
  version = '1.1.5',
  date = "2023/04/18",
  description = "Module lyluatex.",
  author = "The Gregorio Project  − (see Contributors.md)",
  copyright = "2015-2023 - jperon and others",
  license = "MIT"
})
local basename, contains, convert_unit, current_font_size, dirname, fontinfo, max, min, mkdirs, orderedpairs, readlinematching, splitext, tex_engine
do
  local _obj_0 = require(kpse.find_file("luaoptions-lib.lua") or "luaoptions-lib.lua")
  basename, contains, convert_unit, current_font_size, dirname, fontinfo, max, min, mkdirs, orderedpairs, readlinematching, splitext, tex_engine = _obj_0.basename, _obj_0.contains, _obj_0.convert_unit, _obj_0.current_font_size, _obj_0.dirname, _obj_0.fontinfo, _obj_0.max, _obj_0.min, _obj_0.mkdirs, _obj_0.orderedpairs, _obj_0.readlinematching, _obj_0.splitext, _obj_0.tex_engine
end
local ly_opts = lua_options.client("ly")
local md5 = require("md5")
local lfs = require("lfs")
local ly = {
  err = err,
  varwidth_available = kpse.find_file("varwidth.sty")
}
local Score = ly_opts.options
Score.__index = Score
local FILELIST
local DIM_OPTIONS = {
  'extra-bottom-margin',
  'extra-top-margin',
  'gutter',
  'hpadding',
  'indent',
  'leftgutter',
  'line-width',
  'max-protrusion',
  'max-left-protrusion',
  'max-right-protrusion',
  'rightgutter',
  'paperwidth',
  'paperheight',
  'voffset'
}
local HASHIGNORE = {
  'autoindent',
  'cleantmp',
  'do-not-print',
  'force-compilation',
  'hpadding',
  'max-left-protrusion',
  'max-right-protrusion',
  'print-only',
  'valign',
  'voffset'
}
local MXML_OPTIONS = {
  'absolute',
  'language',
  'lxml',
  'no-articulation-directions',
  'no-beaming',
  'no-page-layout',
  'no-rest-positions',
  'verbose'
}
local TEXINFO_OPTIONS = {
  'doctitle',
  'nogettext',
  'texidoc'
}
local LY_HEAD = [[%%File header
\version "<<<version>>>"
<<<language>>>
#(define inside-lyluatex #t)
#(set-global-staff-size <<<staffsize>>>)
<<<preamble>>>

\header {
  copyright = ""
  tagline = ##f
}
\paper{
  <<<paper>>>
  two-sided = ##<<<twoside>>>
  line-width = <<<linewidth>>>\pt
  <<<indent>>>
  <<<raggedright>>>
  <<<fonts>>>
}
\layout{
  <<<staffprops>>>
  <<<fixbadlycroppedstaffgroupbrackets>>>
}<<<header>>>

%%Follows original score
]]
local LY_FIX_BADLY_CROPPED_STAFFGROUP_BRACKETS = [[\context {
      \Score
      \override SystemStartBracket.after-line-breaking =
      #(lambda (grob)
        (let ((Y-off (ly\grob-property grob 'Y-extent)))
          (ly\grob-set-property! grob 'Y-extent
          (cons (- (car Y-off) 1.7) (+ (cdr Y-off) 1.7)))))
}]]
local LY_FONTS_DEF = [[fonts.roman = "%s"
  fonts.sans = "%s"
  fonts.typewriter = "%s"
]]
local LY_FONTS_DEF_OLD = [[#(define fonts (make-pango-font-tree "%s" "%s" "%s" (/ staff-height pt 20)))]]
local LY_MARGINS_CROP = [[  top-margin = %f\pt
  bottom-margin = %f\pt
  %s
]]
local LY_MARGINS_STAFFLINE = [[  top-margin = 0\pt
  bottom-margin = 0\pt
  %s
  top-system-spacing =
  #'((basic-distance . %f)
    (minimum-distance . %f)
    (padding . 0)
    (stretchability . 0))
  top-markup-spacing =
  #'((basic-distance . %f)
    (minimum-distance . %f)
    (padding . 0)
    (stretchability . 0))
  last-bottom-spacing =
  #'((basic-distance . %f)
    (minimum-distance . %f)
    (padding . 0)
    (stretchability . 0))
]]
local LY_PAPER = [[  %s%s
  print-page-number = ##%s
  print-first-page-number = ##%s
  first-page-number = %d
  %s
]]
local MSG_GET_FONT_FAMILY = [[Some useful informations aren’t available:
you probably loaded polyglossia
before defining the main font, and we have
to "guess" the font’s familyname.
If the text of your scores looks weird,
you should consider using babel instead,
or at least loading polyglossia
after defining the main font.
]]
local MSG_PROCESS = [[LilyPond could not be started.
Please check that LuaLaTeX is started with the
--shell-escape option, and that 'program'
points to a valid LilyPond executable.
]]
local MSG_RANGE_PARSE = [[Invalid value '%s' for item
in list of page ranges. Possible entries:
- Single number
- Range (M-N, N-M or N-)
This item will be skipped!
]]
local oldinfo = info
info = function(...)
  print('\n(lyluatex)', string.format(...))
  return oldinfo(...)
end
local debug
debug = function(...)
  if Score.debug then
    return info(...)
  end
end
local extract_includepaths
extract_includepaths = function(self)
  self = self:explode(",")
  local cfd = Score.currfiledir:gsub('^$', tex_engine.dist == 'MiKTeX' and '.\\' or './')
  table.insert(self, 1, cfd)
  for i, path in ipairs(self) do
    self[i] = path:gsub('^ ', ''):gsub('^~', os.getenv("HOME")):gsub('^%.%.', './..')
  end
  return self
end
local font_default_staffsize
font_default_staffsize = function()
  return current_font_size() / 39321.6
end
local includes_parse
includes_parse = function(self)
  if not self then
    return ""
  else
    return "\n\n" .. table.concat((function()
      local _accum_0 = { }
      local _len_0 = 1
      local _list_0 = self:explode(",")
      for _index_0 = 1, #_list_0 do
        local included_file = _list_0[_index_0]
        _accum_0[_len_0] = "\\include \"" .. tostring(included_file) .. ".ly\""
        _len_0 = _len_0 + 1
      end
      return _accum_0
    end)(), "\n")
  end
end
local locate
locate = function(self, includepaths, ext)
  local result
  local _list_0 = extract_includepaths(includepaths)
  for _index_0 = 1, #_list_0 do
    local d = _list_0[_index_0]
    if d:sub(-1) ~= '/' then
      d = d .. '/'
    end
    result = d .. self
    if lfs.isfile(result) then
      break
    end
  end
  if not (result and lfs.isfile(result)) then
    if ext and self:match("%.[^%.]+$") ~= ext then
      return locate(tostring(self) .. tostring(ext), includepaths)
    else
      return kpse.find_file(self)
    end
  end
  return result
end
local range_parse
range_parse = function(self, nsystems)
  local num = tonumber(self)
  if num then
    return {
      num
    }
  end
  if nsystems ~= 0 and self:sub(-1) == '-' then
    self = self .. nsystems
  end
  if not (self == '' or self:match('^%d+%s*-%s*%d*$')) then
    warn(MSG_RANGE_PARSE, self)
    return 
  end
  local result = { }
  local _from, _to = tonumber(self:match("^%d+")), tonumber(self:match("%d+$"))
  if _to then
    local dir
    if _from <= _to then
      dir = 1
    else
      local _ = -1
    end
    for i = _from, _to, dir do
      table.insert(result, i)
    end
    return result
  else
    return {
      self
    }
  end
end
local set_lyscore
set_lyscore = function(self)
  self.nsystems = self:count_systems()
  if self.insert ~= "fullpage" then
    local hoffset = self.protrusion or 0
    if hoffset == '' then
      hoffset = 0
    end
    self.hoffset = hoffset .. 'pt'
    for s = 1, self.nsystems do
      table.insert(self, tostring(self.output) .. "-" .. tostring(s))
    end
  else
    self[1] = self.output
  end
  ly.score = self
end
local bbox_calc
bbox_calc = function(x_1, x_2, y_1, y_2, line_width)
  local bb = {
    ['protrusion'] = -convert_unit(("%fbp"):format(x_1)),
    ['r_protrusion'] = convert_unit(("%fbp"):format(x_2)) - line_width,
    ['width'] = convert_unit(("%fbp"):format(x_2))
  }
  bb.__index = function(self, k)
    return k == 'height' and convert_unit(("%fbp"):format(y_2)) - convert_unit(("%fbp"):format(y_1))
  end
  return setmetatable(bb, bb)
end
local bbox_parse
bbox_parse = function(self, line_width)
  local bbline = readlinematching('^%%%%BoundingBox', io.open(self .. '.eps', 'r'))
  if not bbline then
    return 
  end
  local x_1, y_1, x_2, y_2 = bbline:match("(%--%d+)%s(%--%d+)%s(%--%d+)%s(%--%d+)")
  bbline = readlinematching('^%%%%HiResBoundingBox', io.popen("gs -sDEVICE=bbox -q -dBATCH -dNOPAUSE " .. tostring(self) .. ".pdf 2>&1"))
  if bbline then
    local pbb = bbline:gmatch("(%d+%.%d+)")
    x_1, y_1, x_2, y_2 = pbb() + x_1, pbb() + y_1, pbb() + x_1, pbb() + y_1
  else
    warn("gs couldn't be launched; there could be rounding errors.")
  end
  local f = assert(io.open(tostring(self) .. ".bbox", 'w'), tostring(self) .. ".bbox can’t be written.")
  f:write(("return %f, %f, %f, %f, %f"):format(x_1, y_1, x_2, y_2, line_width))
  f:close()
  return bbox_calc(x_1, x_2, y_1, y_2, line_width)
end
local bbox_read
bbox_read = function(self)
  self = self .. '.bbox'
  if lfs.isfile(self) then
    local x_1, y_1, x_2, y_2, line_width = dofile(self)
    return bbox_calc(x_1, x_2, y_1, y_2, line_width)
  end
end
local bbox_get
bbox_get = function(self, line_width)
  return bbox_read(self) or bbox_parse(self, line_width)
end
local latex_filename
latex_filename = function(self, insert, input_file)
  if self and input_file then
    if insert ~= 'systems' then
      return warn("`printfilename` only works with `insert=systems`")
    else
      self = input_file:gsub("(.*/)(.*)", "\\lyFilename{%2}\\par")
      return tex.sprint(self)
    end
  end
end
local latex_fullpagestyle
latex_fullpagestyle = function(self, ppn)
  local texoutput
  texoutput = function(self)
    return tex.sprint("\\includepdfset{pagecommand=" .. tostring(self) .. "}%")
  end
  if self == '' then
    if ppn then
      return texoutput("\\thispagestyle{empty}")
    else
      return texoutput('')
    end
  else
    return texoutput("\\thispagestyle{" .. tostring(self) .. "}")
  end
end
local latex_includeinline
latex_includeinline = function(self, height, valign, hpadding, voffset)
  local v_base
  local _exp_0 = valign
  if 'bottom' == _exp_0 then
    v_base = 0
  elseif 'top' == _exp_0 then
    v_base = convert_unit("1em") - height
  else
    v_base = (convert_unit("1em") - height) / 2
  end
  return tex.sprint(("\\hspace{%fpt}\\raisebox{%fpt}{\\includegraphics{%s-1}}\\hspace{%fpt}"):format(hpadding, v_base + voffset, self, hpadding))
end
local latex_includepdf
latex_includepdf = function(self, range, papersize)
  return tex.sprint(("\\includepdf[pages={%s},%s]{%s}"):format(table.concat(range, ','), papersize and 'noautoscale' or '', self))
end
local latex_includesystems
latex_includesystems = function(self, range, protrusion, gutter, staffsize, indent_offset)
  local h_offset = protrusion + indent_offset
  local texoutput = {
    "\\ifx\\preLilyPondExample\\undefined\\else\\preLilyPondExample\\fi",
    "\\par"
  }
  for index, system in pairs(range) do
    if not lfs.isfile(tostring(self) .. "-" .. tostring(system) .. ".eps") then
      break
    end
    texoutput[#texoutput + 1] = ("\\noindent\\hspace*{%fpt}\\includegraphics{" .. tostring(self) .. "-" .. tostring(system) .. "}%%"):format(h_offset + gutter)
    if index < #range then
      texoutput[#texoutput + 1] = ("\\ifx\\betweenLilyPondSystem\\undefined\\par\\vspace{%fpt plus %fpt minus %fpt}\\else\\betweenLilyPondSystem{" .. tostring(index) .. "}\\fi%%"):format(staffsize / 4, staffsize / 12, staffsize / 16)
    end
  end
  texoutput[#texoutput + 1] = "\\ifx\\postLilyPondExample\\undefined\\else\\postLilyPondExample\\fi"
  return tex.sprint(texoutput)
end
local latex_label
latex_label = function(self, labelprefix)
  if self then
    return tex.sprint("\\label{" .. tostring(labelprefix) .. tostring(self) .. "}%%")
  end
end
ly.verbenv = {
  [[\begin{verbatim}]],
  [[\end{verbatim}]]
}
local latex_verbatim
latex_verbatim = function(self, ly_code, intertext, version)
  if self then
    if version then
      tex.sprint('\\lyVersion{' .. version .. '}')
    end
    local content = table.concat(ly_code:explode('\n'), '\n'):gsub('.*%%%s*begin verbatim', ''):gsub('%%%s*end verbatim.*', '')
    local fname = tostring(ly_opts.tmpdir) .. "/verb.tex"
    local f = assert(io.open(fname, 'w'), tostring(fname) .. " can’t be written.")
    f:write(tostring(ly.verbenv[1]) .. "\n" .. tostring(content) .. "\n" .. tostring(ly.verbenv[2]:gsub([[\end {]], [[\end{]])) .. "\n")
    f:close()
    tex.sprint("\\input{" .. tostring(fname) .. "}")
    if intertext then
      return tex.sprint("\\lyIntertext{" .. tostring(intertext) .. "}")
    end
  end
end
do
  local _ = Score
  _.new = function(self, ly_code, options, input_file)
    local o = options or { }
    setmetatable(o, self)
    o.output_names = { }
    o.input_file = input_file
    o.ly_code = ly_code
    return o
  end
  _.bbox = function(self, system)
    if system then
      self.bboxes = self.bboxes or (function()
        local _accum_0 = { }
        local _len_0 = 1
        for i = 1, self:count_systems() do
          _accum_0[_len_0] = bbox_get(tostring(self.output) .. "-" .. tostring(i), self['line-width'])
          _len_0 = _len_0 + 1
        end
        return _accum_0
      end)()
      return self.bboxes[system]
    else
      self.bbox = self.bbox or bbox_get(self.output, self['line-width'])
      return self.bbox
    end
  end
  _.calc_properties = function(self)
    self:calc_staff_properties()
    self.ly_code = tostring(includes_parse(self.include_before_body)) .. tostring(self.ly_code) .. tostring(includes_parse(self.include_after_body))
    if self.relative and not self.fragment then
      if _.fragment then
        self.relative = false
      end
    end
    if self.relative then
      self.fragment = 'true'
      self.relative = self.relative == '' and 1 or tonumber(self.relative)
    end
    if self.fragment == '' then
      if ly.state == 'file' then
        self.fragment = false
      end
    end
    if self.insert == '' then
      self.insert = ly.state == 'cmd' and 'inline' or 'systems'
    end
    self.staffsize = tonumber(self.staffsize)
    if self.staffsize == 0 then
      self.staffsize = font_default_staffsize()
    end
    if self.insert == 'inline' or self.insert == 'bare-inline' then
      local inline_staffsize = tonumber(self['inline-staffsize'])
      if inline_staffsize == 0 then
        inline_staffsize = self.staffsize / 1.5
      end
      self.staffsize = inline_staffsize
    end
    for _index_0 = 1, #DIM_OPTIONS do
      local dimension = DIM_OPTIONS[_index_0]
      self[dimension] = convert_unit(self[dimension])
    end
    self['max-left-protrusion'] = self['max-left-protrusion'] or self['max-protrusion']
    self['max-right-protrusion'] = self['max-right-protrusion'] or self['max-protrusion']
    if self.quote then
      self.leftgutter = self.leftgutter or self.gutter
      self.rightgutter = self.rightgutter or self.gutter
      self['line-width'] = self['line-width'] - (self.leftgutter + self.rightgutter)
    else
      self.leftgutter = 0
      self.rightgutter = 0
    end
    self.original_lw = self['line-width']
    self.original_indent = self.indent
    self.autoindent = not self.indent
    if self['current-font-as-main'] then
      self.rmfamily = self['current-font']
    end
    self.addversion = self.addversion and self:lilypond_version()
    self.output = self:output_filename()
  end
  _.calc_range = function(self)
    local nsystems = self:count_systems(true)
    local printonly, donotprint = self['print-only'], self['do-not-print']
    if printonly == '' then
      printonly = '1-'
    end
    local result, rm_result = { }, { }
    local _list_0 = printonly:explode(",")
    for _index_0 = 1, #_list_0 do
      local r = _list_0[_index_0]
      do
        local range = range_parse(r:gsub('^%s', ''):gsub('%s$', ''), nsystems)
        if range then
          for _index_1 = 1, #range do
            local v = range[_index_1]
            table.insert(result, v)
          end
        end
      end
    end
    local _list_1 = donotprint:explode(",")
    for _index_0 = 1, #_list_1 do
      local r = _list_1[_index_0]
      do
        local range = range_parse(r:gsub('^%s', ''):gsub('%s$', ''), nsystems)
        if range then
          for _index_1 = 1, #range do
            local v = range[_index_1]
            table.insert(rm_result, v)
          end
        end
      end
    end
    for _index_0 = 1, #rm_result do
      local v = rm_result[_index_0]
      do
        local k = contains(result, v)
        if k then
          table.remove(result, k)
        end
      end
    end
    return result
  end
  _.calc_staff_properties = function(self)
    if self.insert == 'bare-inline' then
      self.nostaff = 'true'
    end
    if self.notime then
      self.notimesig = 'true'
      self.notiming = 'true'
    end
    if self.nostaff then
      self.nostaffsymbol = 'true'
      self.notimesig = 'true'
      self.noclef = 'true'
    end
  end
  _.check_compilation = function(self)
    local debug_msg, doc_debug_msg
    if self.debug then
      debug_msg = "Please check the log file\nand the generated LilyPond code in\n" .. tostring(self.output) .. ".log\n" .. tostring(self.output) .. ".ly\n"
      doc_debug_msg = "A log file and a LilyPond file have been written.\\\\See log for details."
    else
      debug_msg = "If you need more information\nthan the above message,\nplease retry with option debug=true."
      doc_debug_msg = "Re-run with \\texttt{debug} option to investigate."
    end
    if self.fragment then
      local frag_msg = "As the input code has been automatically wrapped\nwith a music expression, you may try repeating\nwith the `nofragment` option."
      debug_msg = tostring(debug_msg) .. "\n" .. tostring(frag_msg)
      doc_debug_msg = tostring(doc_debug_msg) .. "\n" .. tostring(frag_msg)
    end
    if self:is_compiled() then
      if self.lilypond_error then
        warn("\n\nLilyPond reported a failed compilation but\nproduced a score. " .. tostring(debug_msg))
      end
      return true
    else
      self:clean_failed_compilation()
      if self.showfailed then
        tex.sprint("\\begin{quote}\n\\minibox[frame]{LilyPond failed to compile a score.\\\\\n" .. tostring(doc_debug_msg) .. "}\n\\end{quote}\n\n")
        warn("\n\nLilyPond failed to compile the score.\n" .. tostring(debug_msg) .. "\n")
      else
        err("\n\nLilyPond failed to compile the score.\n" .. tostring(debug_msg) .. "\n")
      end
      return false
    end
  end
  _.check_indent = function(self, lp)
    local nsystems = self:count_systems()
    local handle_autoindent
    handle_autoindent = function()
      self.indent_offset = 0
      if lp.shorten > 0 then
        if not self.indent or self.indent == 0 then
          self.indent = lp.overflow_left
          lp.shorten = max(lp.shorten - lp.overflow_left, 0)
        else
          self.indent = max(self.indent - lp.overflow_left, 0)
        end
        lp.changed_indent = true
      end
    end
    local handle_indent
    handle_indent = function()
      if not self.indent_offset then
        self.indent_offset = 0
        if self:count_systems() > 1 then
          self.indent = 0
          lp.changed_indent = true
        end
        return info("Deactivate indentation because of system selection")
      elseif lp.shorten > 0 then
        self.indent = 0
        self.autoindent = true
        handle_autoindent()
        return info("Deactivated indent causes protrusion.")
      end
    end
    local regular_score
    regular_score = function()
      return not self.original_indent or nsystems > 1 and #self.range > 1 and self.range[1] == 1
    end
    local simple_noindent
    simple_noindent = function()
      return self.original_indent and nsystems == 1
    end
    if simple_noindent() then
      self.indent_offset = -self.indent
      return warn("Deactivate indent for single-system score.")
    elseif self.autoindent then
      return handle_autoindent()
    elseif regular_score() then
      self.indent_offset = 0
    else
      return handle_indent()
    end
  end
  _.check_properties = function(self)
    ly_opts:validate_options(self)
    for _index_0 = 1, #TEXINFO_OPTIONS do
      local k = TEXINFO_OPTIONS[_index_0]
      if self[k] then
        info("Option " .. tostring(k) .. " is specific to Texinfo: ignoring it.")
      end
    end
    if self.fragment then
      if (self.input_file or self.ly_code:find([[\book]]) or self.ly_code:find([[\header]]) or self.ly_code:find([[\layout]]) or self.ly_code:find([[\paper]]) or self.ly_code:find([[\score]])) then
        warn([[Found something incompatible with `fragment`
(or `relative`). Setting them to false.
]])
        self.fragment = false
        self.relative = false
      end
    end
  end
  _.check_protrusion = function(self, bbox_func)
    self.range = self:calc_range()
    if self.insert ~= 'systems' then
      return self:is_compiled()
    end
    local bb = bbox_func(self.output, self['line-width'])
    if not bb then
      return 
    end
    local lp = { }
    lp.overflow_left = max(bb.protrusion - math.floor(self['max-left-protrusion']), 0)
    self.protrusion_left = lp.overflow_left - bb.protrusion
    lp.stave_extent = lp.overflow_left + min(self['line-width'], bb.width)
    lp.available = self.original_lw + self['max-right-protrusion']
    lp.total_extent = lp.stave_extent + bb.r_protrusion
    lp.stave_overflow_right = max(lp.stave_extent - self.original_lw, 0)
    lp.overflow_right = max(lp.total_extent - lp.available, 0)
    lp.shorten = max(lp.stave_overflow_right, lp.overflow_right)
    lp.changed_indent = false
    self:check_indent(lp, bb)
    if lp.shorten > 0 or lp.changed_indent then
      self['line-width'] = self['line-width'] - lp.shorten
      if lp.shorten > 0 then
        info("Compiled score exceeds protrusion limit(s)")
      end
      if lp.changed_indent then
        info("Adjusted indent.")
      end
      self.output = self:output_filename()
      warn("Recompile or reuse cached score")
      return 
    else
      return true
    end
  end
  _.clean_failed_compilation = function(self)
    for file in lfs.dir(self.tmpdir) do
      local filename = tostring(self.tmpdir) .. "/" .. tostring(file)
      if filename:find(self.output) then
        os.remove(filename)
      end
    end
  end
  _.content = function(self)
    local n = ''
    local ly_code = self.ly_code
    if self.relative then
      self.fragment = 'true'
      if self.relative < 0 then
        for _ = -1, self.relative, -1 do
          n = n .. ','
        end
      elseif self.relative > 0 then
        for _ = 1, self.relative do
          n = n .. "'"
        end
      end
      return "\\relative c" .. tostring(n) .. " {" .. tostring(ly_code) .. "}"
    elseif self.fragment then
      return "{" .. tostring(ly_code) .. "}"
    else
      return ly_code
    end
  end
  _.count_systems = function(self, force)
    local count = self.system_count
    if force or not count then
      count = 0
      local systems = tostring(self.output:match('[^/]*$')) .. "%-%d+%.eps"
      for f in lfs.dir(self.tmpdir) do
        if f:match(systems) then
          count = count + 1
        end
      end
      self.system_count = count
    end
    return count
  end
  _.delete_intermediate_files = function(self)
    local _list_0 = self.output_names
    for _index_0 = 1, #_list_0 do
      local filename = _list_0[_index_0]
      if self.insert == 'fullpage' then
        os.remove(tostring(filename) .. ".ps")
      else
        os.remove(tostring(filename) .. "-systems.tex")
        os.remove(tostring(filename) .. "-systems.texi")
        os.remove(tostring(filename) .. ".eps")
      end
    end
  end
  _.flatten_content = function(self, ly_code)
    ly_code = ly_code:gsub('%%', '#')
    local includepaths = self.input_file and tostring(self.includepaths) .. "," .. tostring(dirname(self.input_file)) or tostring(self.includepaths) .. "," .. tostring(self.tmpdir)
    for iline in ly_code:gmatch('\\include%s*"[^"]*"') do
      do
        local f = io.open(locate(iline:match('\\include%s*"([^"]*)"'), includepaths, '.ly') or "")
        if f then
          ly_code = ly_code:gsub(iline, self:flatten_content(f:read("*a")))
          f:close()
        end
      end
    end
    return ly_code
  end
  _.footer = function(self)
    return includes_parse(self.include_footer)
  end
  _.header = function(self)
    local header = LY_HEAD
    for element in LY_HEAD:gmatch("<<<(%w+)>>>") do
      header = header:gsub("<<<" .. tostring(element) .. ">>>", self["ly_" .. tostring(element)](self) or '')
    end
    do
      local wh_dest = self['write-headers']
      if wh_dest then
        if self.input_file then
          local ext
          _, ext = splitext(wh_dest)
          local header_file = ext and wh_dest or tostring(wh_dest) .. "/" .. tostring(splitext(basename(self.input_file), 'ly')) .. "-lyluatex-headers.ily"
          mkdirs(dirname(header_file))
          local f = assert(io.open(header_file, 'w'), tostring(header_file) .. " can’t be written.")
          f:write(header:gsub([[%\include "lilypond%-book%-preamble.ly"]], ''):gsub([[%#%(define inside%-lyluatex %#t%)]], ''):gsub('\n+', '\n'))
          f:close()
        else
          warn("Ignoring 'write-headers' for non-file score.")
        end
      end
    end
    return header
  end
  _.is_compiled = function(self)
    if self['force-compilation'] then
      return false
    end
    return lfs.isfile(self.output .. '.pdf') or lfs.isfile(self.output .. '.eps') or self:count_systems(true) ~= 0
  end
  _.is_odd_page = function(self)
    return tex.count['c@page'] % 2 == 1
  end
  _.lilypond_cmd = function(self)
    local input, mode = '-s -', 'w'
    if self.debug or tex_engine.dist == 'MiKTeX' then
      local f = assert(io.open(tostring(self.output) .. ".ly", 'w'), tostring(self.output) .. ".ly can’t be written.")
      f:write(self.complete_ly_code)
      f:close()
      input = tostring(self.output) .. ".ly 2>&1"
      mode = 'r'
    end
    local cmd = "\"" .. tostring(self.program) .. "\" " .. tostring(self.insert == 'fullpage' and '' or '-E') .. " -dno-point-and-click -djob-count=2 -dno-delete-intermediate-files"
    if self['optimize-pdf'] and self:lilypond_has_TeXGS() then
      cmd = cmd .. " -O TeX-GS -dgs-never-embed-fonts"
    end
    if self.input_file then
      cmd = cmd .. " -I \"" .. tostring(dirname(self.input_file):gsub('^%./', lfs.currentdir() .. '/')) .. "\""
    end
    local _list_0 = extract_includepaths(self.includepaths)
    for _index_0 = 1, #_list_0 do
      local dir = _list_0[_index_0]
      cmd = cmd .. " -I \"" .. tostring(dir:gsub('^%./', lfs.currentdir() .. '/')) .. "\""
    end
    cmd = cmd .. " -o \"" .. tostring(self.output) .. "\" " .. tostring(input)
    debug("Command:\n" .. tostring(cmd))
    return cmd, mode
  end
  _.lilypond_has_TeXGS = function(self)
    return readlinematching('TeX%-GS', io.popen("\"" .. tostring(self.program) .. "\" --help", 'r'))
  end
  _.lilypond_version = function(self)
    local version = self._lilypond_version
    if not version then
      version = readlinematching('GNU LilyPond', io.popen("\"" .. tostring(self.program) .. "\" --version", 'r'))
      info("Compiling score " .. tostring(self.output) .. " with LilyPond executable '" .. tostring(self.program) .. "'.")
      if not version then
        return 
      end
      version = ly.v({
        version:match("(%d+)%.(%d+)%.?(%d*)")
      })
      debug("VERSION " .. tostring(version))
      self._lilypond_version = version
    end
    return version
  end
  _.ly_fixbadlycroppedstaffgroupbrackets = function(self)
    return self.fix_badly_cropped_staffgroup_brackets and LY_FIX_BADLY_CROPPED_STAFFGROUP_BRACKETS or '%% no fix for badly cropped StaffGroup brackets'
  end
  _.ly_fonts = function(self)
    if self['pass-fonts'] then
      local fonts_def = (self:lilypond_version() >= ly.v({
        2,
        25,
        4
      })) and LY_FONTS_DEF or LY_FONTS_DEF_OLD
      return fonts_def:format(self.rmfamily, self.sffamily, self.ttfamily)
    else
      return '%% fonts not set'
    end
  end
  _.ly_header = function(self)
    return includes_parse(self.include_header)
  end
  _.ly_indent = function(self)
    if not (self.indent == false and self.insert == 'fullpage') then
      return "indent = " .. tostring(self.indent or 0) .. "\\pt"
    else
      return '%% no indent set'
    end
  end
  _.ly_language = function(self)
    return self.language and "\\language \"" .. tostring(self.language) .. "\"\n\n" or ''
  end
  _.ly_linewidth = function(self)
    return self['line-width']
  end
  _.ly_staffsize = function(self)
    return self.staffsize
  end
  _.ly_margins = function(self)
    local horizontal_margins = self.twoside and ("inner-margin = %f\\pt"):format(self:tex_margin_inner()) or ("left-margin = %f\\pt"):format(self:tex_margin_left())
    local tex_top = self['extra-top-margin'] + self:tex_margin_top()
    local tex_bottom = self['extra-bottom-margin'] + self:tex_margin_bottom()
    if self.fullpagealign == 'crop' then
      return LY_MARGINS_CROP:format(tex_top, tex_bottom, horizontal_margins)
    elseif self.fullpagealign == 'staffline' then
      local top_distance = 4 * tex_top / self.staffsize + 2
      local bottom_distance = 4 * tex_bottom / self.staffsize + 2
      return LY_MARGINS_STAFFLINE:format(horizontal_margins, top_distance, top_distance, top_distance, top_distance, bottom_distance, bottom_distance)
    else
      return err("Invalid argument for option 'fullpagealign'.\nAllowed: 'crop', 'staffline'.\nGiven: " .. tostring(self.fullpagealign))
    end
  end
  _.ly_paper = function(self)
    local system_count = self['system-count'] == '0' and '' or "system-count = " .. tostring(self['system-count']) .. "\n"
    local papersize = "#(set-paper-size \"" .. tostring(self.papersize or 'lyluatexfmt') .. "\")"
    if self.insert == 'fullpage' then
      local first_page_number = self['first-page-number'] or tex.count['c@page']
      local pfpn = self['print-first-page-number'] and 't' or 'f'
      local ppn = self['print-page-number'] and 't' or 'f'
      return LY_PAPER:format(system_count, papersize, ppn, pfpn, first_page_number, self:ly_margins())
    else
      return tostring(papersize) .. "\n" .. tostring(system_count)
    end
  end
  _.ly_preamble = function(self)
    local result = ([[#(set! paper-alist (cons '("lyluatexfmt" . (cons (* %f pt) (* %f pt))) paper-alist))]]):format(self.paperwidth, self.paperheight)
    return self.insert == 'fullpage' and result or tostring(result) .. "\n\n\\include \"lilypond-book-preamble.ly\""
  end
  _.ly_raggedright = function(self)
    if self['ragged-right'] ~= 'default' then
      return "ragged-right = " .. tostring(self['ragged-right'] and '##t' or '##f')
    else
      return '%% no alignment set'
    end
  end
  _.ly_staffprops = function(self)
    local clef = self.noclef and [[\context { \Staff \remove "Clef_engraver" }]] or '%% no clef set'
    local timing = self.notiming and [[\context { \Score timing = ##f }]] or '%% timing not suppressed'
    local timesig = self.notimesig and [[\context { \Staff \remove "Time_signature_engraver" }]] or '%% no time signature set'
    local staff = self.nostaffsymbol and [[\context { \Staff \remove "Staff_symbol_engraver" }]] or '%% staff symbol not suppressed'
    return tostring(clef) .. "\n  " .. tostring(timing) .. "\n  " .. tostring(timesig) .. "\n  " .. tostring(staff)
  end
  _.ly_twoside = function(self)
    return self.twoside and 't' or 'f'
  end
  _.ly_version = function(self)
    return self['ly-version']
  end
  _.optimize_pdf = function(self)
    if not self['optimize-pdf'] then
      return 
    end
    if self:lilypond_has_TeXGS() and not ly.final_optimization_message then
      ly.final_optimization_message = true
      return luatexbase.add_to_callback('stop_run', function()
        return info("Optimization enabled: remember to run\n'gs -q -dBATCH -dNOPAUSE -sDEVICE=pdfwrite -sOutputFile=%s %s'.", tex.jobname .. '-final.pdf', tex.jobname .. '.pdf')
      end, 'lyluatex optimize-pdf')
    else
      local pdf2ps, ps2pdf, path
      for file in lfs.dir(self.tmpdir) do
        path = tostring(self.tmpdir) .. "/" .. tostring(file)
        if path:match(self.output) and path:sub(-4) == '.pdf' then
          pdf2ps = io.popen("gs -q -sDEVICE=ps2write -sOutputFile=- -dNOPAUSE " .. tostring(path) .. " -c quit", "r")
          ps2pdf = io.popen("gs -q -dBATCH -dNOPAUSE -sDEVICE=pdfwrite -sOutputFile=" .. tostring(path) .. "-gs -", "w")
          if pdf2ps then
            ps2pdf:write(pdf2ps:read("*a"))
            pdf2ps:close()
            ps2pdf:close()
            os.rename(tostring(path) .. "-gs", path)
          else
            warn("You have asked for pdf optimization, but gs wasn't found.")
          end
        end
      end
    end
  end
  _.output_filename = function(self)
    local properties = ''
    for k in orderedpairs(ly_opts.declarations) do
      if (not contains(HASHIGNORE, k)) and self[k] and type(self[k]) ~= 'function' then
        properties = tostring(properties) .. "\n" .. tostring(k) .. "\t" .. tostring(self[k])
      end
    end
    if self.insert == 'fullpage' then
      properties = properties .. tostring(self:tex_margin_top()) .. tostring(self:tex_margin_bottom()) .. tostring(self:tex_margin_left()) .. tostring(self:tex_margin_right())
    end
    local filename = md5.sumhexa(tostring(self:flatten_content(self.ly_code)) .. tostring(properties))
    return tostring(self.tmpdir) .. "/" .. tostring(filename)
  end
  _.process = function(self)
    self:check_properties()
    self:calc_properties()
    if not self:lilypond_version() then
      if self.showfailed then
        warn(MSG_PROCESS)
        tex.sprint("\\begin{quote}\\minibox[frame]{LilyPond could not be started.}\\end{quote}\n\n")
        return 
      else
        err(MSG_PROCESS)
      end
    end
    local do_compile = not self:check_protrusion(bbox_read)
    if self['force-compilation'] or do_compile then
      while true do
        self.complete_ly_code = self:header() .. self:content() .. self:footer()
        self:run_lilypond()
        self['force-compilation'] = false
        if self:is_compiled() then
          table.insert(self.output_names, self.output)
        else
          self:clean_failed_compilation()
          break
        end
        if self:check_protrusion(bbox_get) then
          break
        end
      end
      self:optimize_pdf()
    else
      table.insert(self.output_names, self.output)
    end
    set_lyscore(self)
    if self:count_systems() == 0 then
      warn("The score doesn't contain any music:\nthis will probably cause bad output.")
    end
    if not self['raw-pdf'] then
      self:write_latex(do_compile)
    end
    self:write_to_filelist()
    if not self.debug then
      return self:delete_intermediate_files()
    end
  end
  _.run_lily_proc = function(self, p)
    if self.debug then
      local f = assert(io.open(tostring(self.output) .. ".log", 'w'), tostring(self.output) .. " can’t be written.")
      f:write(p:read("*a"))
      f:close()
    else
      p:write(self.complete_ly_code)
    end
    return p:close()
  end
  _.run_lilypond = function(self)
    if self:is_compiled() then
      return 
    end
    mkdirs(dirname(self.output))
    if not self:run_lily_proc(io.popen(self:lilypond_cmd(self.complete_ly_code))) and not self.debug then
      self.debug = true
      self.lilypond_error = not self:run_lily_proc(io.popen(self:lilypond_cmd(self.complete_ly_code)))
    end
    local lilypond_pdf, mode = self:lilypond_cmd(self.complete_ly_code)
    if lilypond_pdf:match("-E") then
      lilypond_pdf = lilypond_pdf:gsub(" %-E", " --pdf")
      return self:run_lily_proc(io.popen(lilypond_pdf, mode))
    end
  end
  _.tex_margin_bottom = function(self)
    self._tex_margin_bottom = self._tex_margin_bottom or (convert_unit(tostring(tex.dimen.paperheight) .. "sp") - self:tex_margin_top() - convert_unit(tostring(tex.dimen.textheight) .. "sp"))
    return self._tex_margin_bottom
  end
  _.tex_margin_inner = function(self)
    self._tex_margin_inner = self._tex_margin_inner or convert_unit(tostring(tex.sp('1in') + tex.dimen.oddsidemargin + tex.dimen.hoffset) .. "sp")
    return self._tex_margin_inner
  end
  _.tex_margin_outer = function(self)
    self._tex_margin_outer = self._tex_margin_outer or (convert_unit(tostring(tex.dimen.paperwidth - tex.dimen.textwidth) .. "sp") - self:tex_margin_inner())
    return self._tex_margin_outer
  end
  _.tex_margin_left = function(self)
    return self:is_odd_page() or not self.twopage and self:tex_margin_inner() or self:tex_margin_outer()
  end
  _.tex_margin_right = function(self)
    return self:is_odd_page() or not self.twopage and self:tex_margin_outer() or self:tex_margin_inner()
  end
  _.tex_margin_top = function(self)
    self._tex_margin_top = self._tex_margin_top or convert_unit(tostring(tex.sp('1in') + tex.dimen.voffset + tex.dimen.topmargin + tex.dimen.headheight + tex.dimen.headsep) .. "sp")
    return self._tex_margin_top
  end
  _.write_latex = function(self, do_compile)
    latex_filename(self.printfilename, self.insert, self.input_file)
    latex_verbatim(self.verbatim, self.ly_code, self.intertext, self.addversion)
    if do_compile and not self:check_compilation() then
      return 
    end
    latex_fullpagestyle(self.fullpagestyle, self['print-page-number'])
    latex_label(self.label, self.labelprefix)
    if self.insert == 'fullpage' then
      return latex_includepdf(self.output, self.range, self.papersize)
    elseif self.insert == 'systems' then
      return latex_includesystems(self.output, self.range, self.protrusion_left, self.leftgutter, self.staffsize, self.indent_offset)
    else
      if self:count_systems() > 1 then
        warn("Score with more than one system included inline.\nThis will probably cause bad output.")
      end
      do
        local bb = self:bbox(1)
        if bb then
          return latex_includeinline(self.output, bb.height, self.valign, self.hpadding, self.voffset)
        end
      end
    end
  end
  _.write_to_filelist = function(self)
    local f = assert(io.open(FILELIST, 'a'), tostring(FILELIST) .. " can’t be written.")
    local _list_0 = self.output_names
    for _index_0 = 1, #_list_0 do
      local file = _list_0[_index_0]
      local filename = file:match("./+(.*)")
      f:write(filename, '\t', self.input_file or '', '\t', self.label or '', '\n')
    end
    return f:close()
  end
end
ly.buffenv_begin = function()
  ly.buffenv = function(self)
    table.insert(ly.score_content, self)
    if not self:find([[\end{%w+}]]) then
      return ''
    end
  end
  ly.score_content = { }
  return luatexbase.add_to_callback('process_input_buffer', ly.buffenv, 'readline')
end
ly.buffenv_end = function()
  luatexbase.remove_from_callback('process_input_buffer', 'readline')
  return table.remove(ly.score_content)
end
ly.clean_tmp_dir = function()
  local hash, file_is_used
  local hash_list = { }
  for file in lfs.dir(Score.tmpdir) do
    if file:sub(-5, -1) == '.list' then
      local i = assert(io.open(tostring(Score.tmpdir) .. "/" .. tostring(file)), tostring(Score.tmpdir) .. "/" .. tostring(file) .. " can’t be written.")
      local _list_0 = i:read("*a"):explode("\n")
      for _index_0 = 1, #_list_0 do
        local line = _list_0[_index_0]
        hash = line:explode("\t")[1]
        if hash ~= '' then
          table.insert(hash_list, hash)
        end
      end
      i:close()
    end
  end
  for file in lfs.dir(Score.tmpdir) do
    if file ~= '.' and file ~= '..' and file:sub(-5, -1) ~= '.list' then
      for _index_0 = 1, #hash_list do
        local lhash = hash_list[_index_0]
        file_is_used = file:find(lhash)
        if file_is_used then
          break
        end
      end
      if not file_is_used then
        os.remove(Score.tmpdir .. '/' .. file)
      end
    end
  end
end
ly.conclusion_text = function()
  return info("Output written on %s.pdf.\nTranscript written on %s.log.", tex.jobname, tex.jobname)
end
ly.make_list_file = function()
  local tmpdir = ly_opts.tmpdir
  mkdirs(tmpdir)
  FILELIST = tostring(tmpdir) .. "/" .. tostring(splitext(status.log_name, 'log')) .. ".list"
  return os.remove(FILELIST)
end
ly.file = function(self, options)
  local file = locate(self, Score.includepaths, '.ly')
  options = ly_opts:check_local_options(options)
  if not file then
    err("File %s doesn't exist.", self)
  end
  local i = assert(io.open(file, 'r'), tostring(file) .. " can’t be read")
  ly.score = Score:new(i:read("*a"), options, file)
  return i:close()
end
ly.file_musicxml = function(self, options)
  local file = locate(self, Score.includepaths, '.xml')
  options = ly_opts:check_local_options(options)
  if not file then
    err("File %s doesn't exist.", self)
  end
  local xmlopts = ''
  for _index_0 = 1, #MXML_OPTIONS do
    local opt = MXML_OPTIONS[_index_0]
    if options[opt] ~= nil then
      if options[opt] then
        xmlopts = xmlopts .. " --" .. tostring(opt)
        if options[opt] ~= 'true' and options[opt] ~= '' then
          xmlopts = xmlopts .. " " .. tostring(options[opt])
        end
      end
    elseif ly_opts[opt] then
      xmlopts = xmlopts .. " --" .. tostring(opt)
    end
  end
  do
    local i = io.popen(tostring(ly_opts.xml2ly) .. " --out=-" .. tostring(xmlopts) .. " \"" .. tostring(file) .. "\"", 'r')
    if i then
      ly.score = Score:new(i:read("*a"), options, file)
      return i:close()
    else
      return err(tostring(ly_opts.xml2ly) .. " could not be started.\nPlease check that LuaLaTeX is started with the\n--shell-escape option.")
    end
  end
end
ly.fragment = function(self, options)
  options = ly_opts:check_local_options(options)
  if type(self) == 'string' then
    self = self:gsub('\\par ', '\n'):gsub('\\([^%s]*) %-([^%s])', '\\%1-%2')
  else
    self = table.concat(self, '\n')
  end
  ly.score = Score:new(self, options)
end
ly.get_font_family = function(self)
  local ft = fontinfo(self)
  if ft.shared.rawdata then
    return ft.shared.rawdata.metadata.familyname
  end
  warn(MSG_GET_FONT_FAMILY)
  return ft.fullname:match("[^-]*")
end
ly.newpage_if_fullpage = function()
  if ly.score.insert == 'fullpage' then
    return tex.sprint([[\newpage]])
  end
end
ly.set_fonts = function(rm, sf, tt)
  if ly.score.rmfamily .. ly.score.sffamily .. ly.score.ttfamily ~= '' then
    ly.score['pass-fonts'] = 'true'
    info("At least one font family set explicitly. Activate 'pass-fonts'")
  end
  if ly.score.rmfamily == '' then
    ly.score.rmfamily = ly.get_font_family(rm)
  else
    if ly.score['current-font-as-main'] then
      info("rmfamily set explicitly. Deactivate 'current-font-as-main'")
    end
    ly.score['current-font-as-main'] = false
  end
  if ly.score.sffamily == '' then
    ly.score.sffamily = ly.get_font_family(sf)
  end
  if ly.score.ttfamily == '' then
    ly.score.ttfamily = ly.get_font_family(tt)
  end
end
do
  local _ = {
    __sub = function(self, other)
      for i = 1, max(#self, #other) do
        local diff = (self[i] or 0) - (other[i] or 0)
        if diff ~= 0 then
          return diff, i
        end
      end
      return 0
    end,
    __eq = function(self, other)
      return self - other == 0
    end,
    __lt = function(self, other)
      return self - other < 0
    end,
    __call = function(self, v)
      for i = 1, #v do
        v[i] = tonumber(v[i])
      end
      return setmetatable(v, self)
    end,
    __tostring = function(self)
      return table.concat(self, ".")
    end
  }
  ly.v = setmetatable(_, _)
end
ly.write_to_file = function(self, content)
  local f = assert(io.open(tostring(Score.tmpdir) .. "/" .. tostring(self), "w"), tostring(Score.tmpdir) .. "/" .. tostring(self) .. " can’t be written.")
  f:write(content)
  return f:close()
end
return ly
