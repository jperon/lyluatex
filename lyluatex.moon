kpse, luatexbase, lua_options, status, tex = kpse, luatexbase, lua_options, status, tex
err, warn, info = luatexbase.provides_module {
    name:         "lyluatex"
    version:      '1.1.5'  --LYLUATEX_VERSION
    date:         "2023/04/18"  --LYLUATEX_DATE
    description:  "Module lyluatex."
    author:       "The Gregorio Project  − (see Contributors.md)"
    copyright:    "2015-2023 - jperon and others"
    license:      "MIT"
}

import basename, contains, convert_unit, current_font_size, dirname, fontinfo, max, min, mkdirs, orderedpairs, readlinematching, splitext, tex_engine from require(kpse.find_file"luaoptions-lib.lua" or "luaoptions-lib.lua")
ly_opts = lua_options.client"ly"

md5 = require"md5"
lfs = require"lfs"

ly = :err, varwidth_available: kpse.find_file"varwidth.sty"

Score = ly_opts.options
Score.__index = Score

local FILELIST
DIM_OPTIONS = {
    'extra-bottom-margin'
    'extra-top-margin'
    'gutter'
    'hpadding'
    'indent'
    'leftgutter'
    'line-width'
    'max-protrusion'
    'max-left-protrusion'
    'max-right-protrusion'
    'rightgutter'
    'paperwidth'
    'paperheight'
    'voffset'
}
HASHIGNORE = {
    'autoindent'
    'cleantmp'
    'do-not-print'
    'force-compilation'
    'hpadding'
    'max-left-protrusion'
    'max-right-protrusion'
    'print-only'
    'valign'
    'voffset'
}
MXML_OPTIONS = {
    'absolute'
    'language'
    'lxml'
    'no-articulation-directions'
    'no-beaming'
    'no-page-layout'
    'no-rest-positions'
    'verbose'
}
TEXINFO_OPTIONS = {'doctitle', 'nogettext', 'texidoc'}
LY_HEAD = [[
%%File header
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
    <<<paper>>>    two-sided = ##<<<twoside>>>
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


--[[ ========================== Helper functions ========================== --]]
-- dirty fix as info doesn't work as expected
oldinfo = info
info = (...) ->
    print('\n(lyluatex)', string.format(...))
    oldinfo(...)

-- debug acts as info if [debug] is specified
debug = (...) ->
    info(...) if Score.debug

extract_includepaths = =>
    @ = @explode","
    cfd = Score.currfiledir\gsub('^$', '.\\') if tex_engine.dist == 'MiKTeX' else Score.currfiledir\gsub('^$', './')
    table.insert(@, 1, cfd)
    for i, path in ipairs(@)
        -- delete initial space (in case someone puts a space after the comma)
        @[i] = path\gsub('^ ', '')\gsub('^~', os.getenv"HOME")\gsub('^%.%.', './..')
    @

font_default_staffsize = -> current_font_size!/39321.6

includes_parse = => "" if not @ else "\n\n" .. table.concat ["\\include \"#{included_file}.ly\"" for included_file in *@explode","], "\n"

locate = (includepaths, ext) =>
    local result
    for d in *extract_includepaths includepaths
        d ..= '/' if d\sub(-1) != '/'
        result = d..@
        break if lfs.isfile result
    if not (result and lfs.isfile result)
        if ext and @match"%.[^%.]+$" != ext
            return locate "#{@}#{ext}", includepaths
        else
            return kpse.find_file @
    result

range_parse = (nsystems) =>
    num = tonumber @
    return {num} if num
    -- if nsystems is set, we have insert=systems
    @ ..= nsystems if nsystems != 0 and @sub(-1) == '-'
    if not (@ == '' or @match('^%d+%s*-%s*%d*$'))
        warn [[
Invalid value '%s' for item
in list of page ranges. Possible entries:
- Single number
- Range (M-N, N-M or N-)
This item will be skipped!
]], @
        return
    result = {}
    _from, _to = tonumber(@match"^%d+"), tonumber(@match"%d+$")
    if _to
        dir = 1 if _from <= _to else -1
        for i = _from, _to, dir do table.insert result, i
        return result
    else return {@}  -- N- with insert=fullpage

set_lyscore = =>
    @nsystems = @count_systems!
    if @insert != "fullpage" then  -- systems and inline
        hoffset = @protrusion or 0
        hoffset = 0 if hoffset == ''
        @hoffset = hoffset..'pt'
        for s = 1, @nsystems
            table.insert @, "#{@output}-#{s}"
    else @[1] = @output
    ly.score = @


--[[ ================ Bounding box calculations =========================== --]]

bbox_calc = (x_1, x_2, y_1, y_2, line_width) ->
    bb = {
        'protrusion': -convert_unit "%fbp"\format x_1
        'r_protrusion': convert_unit("%fbp"\format x_2) - line_width
        'width': convert_unit "%fbp"\format x_2
    }
    --FIX #192: height is only calculated if really needed, to prevent errors with huge scores.
    bb.__index = (k) => k == 'height' and convert_unit("%fbp"\format y_2) - convert_unit("%fbp"\format y_1)
    setmetatable bb, bb

bbox_parse = (line_width) =>
    -- get BoundingBox from EPS file
    bbline = readlinematching '^%%%%BoundingBox', io.open @..'.eps', 'r'
    return if not bbline
    x_1, y_1, x_2, y_2 = bbline\match"(%--%d+)%s(%--%d+)%s(%--%d+)%s(%--%d+)"
    -- try to get HiResBoundingBox from PDF (if 'gs' works)
    bbline = readlinematching '^%%%%HiResBoundingBox', io.popen "gs -sDEVICE=bbox -q -dBATCH -dNOPAUSE #{@}.pdf 2>&1"
    if bbline
        pbb = bbline\gmatch"(%d+%.%d+)"
        -- The HiRes BoundingBox retrieved from the PDF differs from the
        -- BoundingBox present in the EPS file. In the PDF (0|0) is the
        -- Lower Left corner while in the EPS (0|0) represents the top
        -- edge at the start of the staff symbol.
        -- Therefore we shift the HiRes results by the (truncated)
        -- points of the EPS bounding box.
        x_1, y_1, x_2, y_2 = pbb! + x_1, pbb! + y_1, pbb! + x_1, pbb! + y_1
    else warn"gs couldn't be launched; there could be rounding errors."
    f = assert io.open("#{@}.bbox", 'w'), "#{@}.bbox can’t be written."
    f\write "return %f, %f, %f, %f, %f"\format x_1, y_1, x_2, y_2, line_width
    f\close!
    bbox_calc x_1, x_2, y_1, y_2, line_width

bbox_read = =>
    @ ..= '.bbox'
    if lfs.isfile @
        x_1, y_1, x_2, y_2, line_width = dofile @
        bbox_calc x_1, x_2, y_1, y_2, line_width

bbox_get = (line_width) => bbox_read(@) or bbox_parse(@, line_width)


--[[ =============== Functions that output LaTeX code ===================== --]]

latex_filename = (insert, input_file) =>
    if @ and input_file
        if insert != 'systems'
            warn"`printfilename` only works with `insert=systems`"
        else
            @ = input_file\gsub "(.*/)(.*)", "\\lyFilename{%2}\\par"
            tex.sprint @

latex_fullpagestyle = (ppn) =>
    texoutput = => tex.sprint"\\includepdfset{pagecommand=#{@}}%"
    if @ == ''
        if ppn then texoutput"\\thispagestyle{empty}"
        else texoutput''
    else texoutput"\\thispagestyle{#{@}}"

latex_includeinline = (height, valign, hpadding, voffset) =>
    v_base = switch valign
      when 'bottom' 0
      when 'top' convert_unit"1em" - height
      else (convert_unit"1em" - height) / 2
    tex.sprint "\\hspace{%fpt}\\raisebox{%fpt}{\\includegraphics{%s-1}}\\hspace{%fpt}"\format(
            hpadding, v_base + voffset, @, hpadding
        )

latex_includepdf = (range, papersize) =>
    tex.sprint "\\includepdf[pages={%s},%s]{%s}"\format(
        table.concat range, ','
        papersize and 'noautoscale' or ''
        @
    )

latex_includesystems = (range, protrusion, gutter, staffsize, indent_offset) =>
    h_offset = protrusion + indent_offset
    texoutput = '\\ifx\\preLilyPondExample\\undefined\\else\\preLilyPondExample\\fi\n\\par\n'
    for index, system in pairs range
        break if not lfs.isfile"#{@}-#{system}.eps"
        texoutput ..= [[
\noindent\hspace*{%fpt}\includegraphics{%s}%%
]]\format h_offset + gutter, "#{@}-#{system}"
        if index < #range
            texoutput ..= [[
\ifx\betweenLilyPondSystem\undefined\par\vspace{%fpt plus %fpt minus %fpt}%%
\else\betweenLilyPondSystem{%s}\fi%%
]]\format staffsize / 4, staffsize / 12, staffsize / 16, index
    texoutput ..= '\n\\ifx\\postLilyPondExample\\undefined\\else\\postLilyPondExample\\fi'
    tex.sprint texoutput\explode"\n"

latex_label = (labelprefix) => tex.sprint"\\label{#{labelprefix}#{@}}%%" if @

ly.verbenv = {[[\begin{verbatim}]], [[\end{verbatim}]]}
latex_verbatim = (ly_code, intertext, version) =>
    if @
        if version then tex.sprint('\\lyVersion{'..version..'}')
        content = table.concat(ly_code\explode('\n'), '\n')\gsub('.*%%%s*begin verbatim', '')\gsub('%%%s*end verbatim.*', '')
        --We unfortunately need an external file, as verbatim environments are quite special.
        fname = "#{ly_opts.tmpdir}/verb.tex"
        f = assert io.open(fname, 'w'), "#{fname} can’t be written."
        f\write"#{ly.verbenv[1]}\n#{content}\n#{ly.verbenv[2]\gsub([[\end {]], [[\end{]])}\n"
        f\close!
        tex.sprint"\\input{#{fname}}"
        tex.sprint"\\lyIntertext{#{intertext}}" if intertext


--[[ =============================== Classes =============================== --]]

-- Score class
do
    _ = Score
    _.new = (ly_code, options, input_file) =>
        o = options or {}
        setmetatable(o, @)
        o.output_names = {}
        o.input_file = input_file
        o.ly_code = ly_code
        return o

    _.bbox = (system) =>
        if system
            @bboxes or= [ bbox_get("#{@output}-#{i}", @['line-width']) for i = 1, @count_systems! ]
            return @bboxes[system]
        else
            @bbox or= bbox_get @output, @['line-width']
            return @bbox

    _.calc_properties = =>
        @calc_staff_properties!
        -- add includes to lilypond code
        @ly_code = "#{includes_parse @include_before_body}#{@ly_code}#{includes_parse @include_after_body}"
        -- fragment and relative
        if @relative and not @fragment
            -- option takes precedence over global option
            if _.fragment then @relative = false
        if @relative
            @fragment = 'true'  -- yes, here we need a string, not a bool
            @relative = @relative == '' and 1 or tonumber @relative
        if @fragment == ''
            -- by default, included files shouldn't be fragments
            @fragment = false if ly.state == 'file'
        -- default insertion mode
        if @insert == ''
            @insert = ly.state == 'cmd' and 'inline' or 'systems'
        -- staffsize
        @staffsize = tonumber @staffsize
        @staffsize = font_default_staffsize! if @staffsize == 0
        if @insert == 'inline' or @insert == 'bare-inline'
            inline_staffsize = tonumber @['inline-staffsize']
            inline_staffsize = @staffsize / 1.5 if inline_staffsize == 0
            @staffsize = inline_staffsize
        -- dimensions that can be given by LaTeX
        @[dimension] = convert_unit @[dimension] for dimension in *DIM_OPTIONS
        @['max-left-protrusion'] = @['max-left-protrusion'] or @['max-protrusion']
        @['max-right-protrusion'] = @['max-right-protrusion'] or @['max-protrusion']
        if @quote
            @leftgutter or= @gutter
            @rightgutter or= @gutter
            @['line-width'] -= @leftgutter + @rightgutter
        else
            @leftgutter = 0
            @rightgutter = 0
        -- store for comparing protrusion against
        @original_lw = @['line-width']
        @original_indent = @indent
        -- explicit indent disables autoindent
        @autoindent = not @indent
        -- score fonts
        @rmfamily = @['current-font'] if @['current-font-as-main']
        -- LilyPond version
        @addversion and= @lilypond_version!
        -- temporary file name
        @output = @output_filename!

    _.calc_range = =>
        nsystems = @count_systems true
        printonly, donotprint = @['print-only'], @['do-not-print']
        printonly = '1-' if printonly == ''
        result, rm_result = {}, {}
        for r in *printonly\explode","
            if range = range_parse r\gsub('^%s', '')\gsub('%s$', ''), nsystems
                table.insert(result, v) for v in *range
        for r in *donotprint\explode","
            if range = range_parse r\gsub('^%s', '')\gsub('%s$', ''), nsystems
                table.insert(rm_result, v) for v in *range
        for v in *rm_result
            if k = contains result, v
                table.remove result, k
        return result

    _.calc_staff_properties = =>
        -- preset for bare notation symbols in inline images
        @nostaff = 'true' if @insert == 'bare-inline'
        -- handle meta properties
        if @notime
            @notimesig = 'true'
            @notiming = 'true'
        if @nostaff
            @nostaffsymbol = 'true'
            @notimesig = 'true'
            -- do *not* suppress timing
            @noclef = 'true'

    _.check_compilation = =>
        local debug_msg, doc_debug_msg
        if @debug
            debug_msg = [[
Please check the log file
and the generated LilyPond code in
%s
%s
]]\format @output..'.log', @output..'.ly'
            doc_debug_msg = [[
A log file and a LilyPond file have been written.\\
See log for details.]]
        else
            debug_msg = [[
If you need more information
than the above message,
please retry with option debug=true.
]]
            doc_debug_msg = "Re-run with \\texttt{debug} option to investigate."
        if @fragment
            frag_msg = '\n'..[[
As the input code has been automatically wrapped
with a music expression, you may try repeating
with the `nofragment` option.]]
            debug_msg = debug_msg..frag_msg
            doc_debug_msg = doc_debug_msg..frag_msg
        if @is_compiled!
            if @lilypond_error
                warn [[

LilyPond reported a failed compilation but
produced a score. %s
]], debug_msg
            -- we do have *a* score (although labeled as failed by LilyPond)
            return true
        else
            @clean_failed_compilation!
            if @showfailed
                tex.sprint [[
\begin{quote}
\minibox[frame]{LilyPond failed to compile a score.\\
%s}
\end{quote}

]]\format doc_debug_msg
                warn [[

LilyPond failed to compile the score.
%s
]], debug_msg
            else
                err [[

LilyPond failed to compile the score.
%s
]], debug_msg
            -- We don't have any compiled score
            return false

    _.check_indent = (lp) =>
        nsystems = @count_systems!

        handle_autoindent = ->
            @indent_offset = 0
            if lp.shorten > 0
                if not @indent or @indent == 0
                    @indent = lp.overflow_left
                    lp.shorten = max lp.shorten - lp.overflow_left, 0
                else
                    @indent = max @indent - lp.overflow_left, 0
                lp.changed_indent = true

        handle_indent = ->
            if not @indent_offset
                -- First step: deactivate indent
                @indent_offset = 0
                if @count_systems! > 1
                    -- only recompile if the *original* score has more than 1 system
                    @indent = 0
                    lp.changed_indent = true
                info"Deactivate indentation because of system selection"
            elseif lp.shorten > 0
                @indent = 0
                @autoindent = true
                handle_autoindent!
                info"Deactivated indent causes protrusion."

        regular_score = ->
            -- score without any indent or with the first system
            -- printed regularly, with others following.
            not @original_indent or nsystems > 1 and  #@range > 1 and @range[1] == 1

        simple_noindent = ->
            -- score with indent and only one system
            @original_indent and nsystems == 1

        if simple_noindent!
            @indent_offset = -@indent
            warn"Deactivate indent for single-system score."
        elseif @autoindent
            handle_autoindent!
        elseif regular_score!
            @indent_offset = 0
        else handle_indent!

    _.check_properties = =>
        ly_opts\validate_options @
        for k in *TEXINFO_OPTIONS
            if @[k] then info "Option %s is specific to Texinfo: ignoring it.", k
        if @fragment
            if (@input_file or
                @ly_code\find([[\book]]) or
                @ly_code\find([[\header]]) or
                @ly_code\find([[\layout]]) or
                @ly_code\find([[\paper]]) or
                @ly_code\find([[\score]])
            )
                warn[[
Found something incompatible with `fragment`
(or `relative`). Setting them to false.
]]
                @fragment = false
                @relative = false

    _.check_protrusion = (bbox_func) =>
        @range = @calc_range!
        return @is_compiled! if @insert != 'systems'
        bb = bbox_func @output, @['line-width']
        return if not bb
        -- line_props lp
        lp = {}
        -- Determine offset due to left protrusion
        lp.overflow_left = max bb.protrusion - math.floor(@['max-left-protrusion']), 0
        @protrusion_left = lp.overflow_left - bb.protrusion
        -- Determine further line properties
        lp.stave_extent = lp.overflow_left + min @['line-width'], bb.width
        lp.available = @original_lw + @['max-right-protrusion']
        lp.total_extent = lp.stave_extent + bb.r_protrusion
        -- Check if stafflines protrude into the right margin after offsetting
        -- Note: we can't *reliably* determine this with ragged one-system scores,
        -- possibly resulting in unnecessarily short lines when right protrusion is
        -- present
        lp.stave_overflow_right = max lp.stave_extent - @original_lw, 0
        -- Check if image as a whole protrudes over max-right-protrusion
        lp.overflow_right = max lp.total_extent - lp.available, 0
        lp.shorten = max lp.stave_overflow_right, lp.overflow_right
        lp.changed_indent = false
        @check_indent lp, bb
        if lp.shorten > 0 or lp.changed_indent
            @['line-width'] -= lp.shorten
            -- recalculate hash to reflect the reduced line-width
            if lp.shorten > 0
                info"Compiled score exceeds protrusion limit(s)"
            info"Adjusted indent." if lp.changed_indent
            @output = @output_filename!
            warn"Recompile or reuse cached score"
            return
        else return true

    _.clean_failed_compilation = =>
        for file in lfs.dir @tmpdir
            filename = "#{@tmpdir}/#{file}"
            os.remove(filename) if filename\find @output

    _.content = =>
        n = ''
        ly_code = @ly_code
        if @relative
            @fragment = 'true'  -- in case it would serve later
            if @relative < 0
                for _ = -1, @relative, -1 do n ..= ','
            elseif @relative > 0
                for _ = 1, @relative do n ..= "'"
            return "\\relative c%s {%s}"\format n, ly_code
        elseif @fragment then return "{#{ly_code}}"
        else return ly_code

    _.count_systems = (force) =>
        count = @system_count
        if force or not count
            count = 0
            systems = "#{@output\match'[^/]*$'}%-%d+%.eps"
            for f in lfs.dir @tmpdir
                count += 1 if f\match systems
            @system_count = count
        count

    _.delete_intermediate_files = =>
        for filename in *@output_names
            if @insert == 'fullpage'
                os.remove"#{filename}.ps"
            else
                os.remove"#{filename}-systems.tex"
                os.remove"#{filename}-systems.texi"
                os.remove"#{filename}.eps"

    _.flatten_content = (ly_code) =>
        -- Produce a flattend string from the original content,
        -- including referenced files (if they can be opened.
        -- Other files (from LilyPond's include path) are considered
        -- irrelevant for the purpose of a hashsum.)

        -- Replace percent signs with another character that doesn't
        -- meddle with Lua's gsub escape character.
        ly_code = ly_code\gsub '%%', '#'
        local f
        includepaths = "#{@includepaths},#{@tmpdir}"
        includepaths = "#{@includepaths},#{dirname @input_file}" if @input_file
        for iline in ly_code\gmatch'\\include%s*"[^"]*"'
            if f = io.open(locate(iline\match('\\include%s*"([^"]*)"'), includepaths, '.ly') or '')
                ly_code = ly_code\gsub iline, @flatten_content f\read"*a"
                f\close!
        ly_code

    _.footer = => includes_parse @include_footer

    _.header = =>
        header = LY_HEAD
        for element in LY_HEAD\gmatch"<<<(%w+)>>>"
            header = header\gsub "<<<#{element}>>>", @['ly_'..element](@) or ''
        if wh_dest = @['write-headers']
            if @input_file
                _, ext = splitext wh_dest
                header_file = ext and wh_dest or "#{wh_dest}/#{splitext basename(@input_file), 'ly'}-lyluatex-headers.ily"
                mkdirs dirname header_file
                f = assert io.open(header_file, 'w'), "#{header_file} can’t be written."
                f\write header\gsub([[%\include "lilypond%-book%-preamble.ly"]], '')\gsub([[%#%(define inside%-lyluatex %#t%)]], '')\gsub('\n+', '\n')
                f\close!
            else
                warn"Ignoring 'write-headers' for non-file score."
        header

    _.is_compiled = =>
        return false if @['force-compilation']
        lfs.isfile(@output..'.pdf') or lfs.isfile(@output..'.eps') or @count_systems(true) != 0

    _.is_odd_page = => tex.count['c@page'] % 2 == 1

    _.lilypond_cmd = =>
        input, mode = '-s -', 'w'
        if @debug or tex_engine.dist == 'MiKTeX'
            f = assert io.open("#{@output}.ly", 'w'), "#{@output}.ly can’t be written."
            f\write @complete_ly_code
            f\close!
            input = "#{@output}.ly 2>&1"
            mode = 'r'
        cmd = "\"#{@program}\" #{@insert == 'fullpage' and '' or '-E'} -dno-point-and-click -djob-count=2 -dno-delete-intermediate-files"
        if @['optimize-pdf'] and @lilypond_has_TeXGS! then cmd ..= " -O TeX-GS -dgs-never-embed-fonts"
        if @input_file
            cmd ..= " -I \"#{dirname(@input_file)\gsub '^%./', lfs.currentdir!..'/'}\""
        for dir in *extract_includepaths @includepaths
            cmd ..= " -I \"#{dir\gsub '^%./', lfs.currentdir!..'/'}\""
        cmd ..= " -o \"#{@output}\" #{input}"
        debug "Command:\n#{cmd}"
        cmd, mode

    _.lilypond_has_TeXGS = => readlinematching 'TeX%-GS', io.popen "\"#{@program}\" --help", 'r'

    _.lilypond_version = =>
        version = @_lilypond_version
        if not version
            version = readlinematching 'GNU LilyPond', io.popen "\"#{@program}\" --version", 'r'
            info "Compiling score %s with LilyPond executable '%s'.", @output, @program
            if not version then return
            version = ly.v{version\match"(%d+)%.(%d+)%.?(%d*)"}
            debug "VERSION #{version}"
            @_lilypond_version = version
        version

    _.ly_fixbadlycroppedstaffgroupbrackets = =>
        @fix_badly_cropped_staffgroup_brackets and [[\context {
            \Score
            \override SystemStartBracket.after-line-breaking =
            #(lambda (grob)
                (let ((Y-off (ly\grob-property grob 'Y-extent)))
                    (ly\grob-set-property! grob 'Y-extent
                    (cons (- (car Y-off) 1.7) (+ (cdr Y-off) 1.7)))))
        }]] or '%% no fix for badly cropped StaffGroup brackets'

    _.ly_fonts = =>
        if @['pass-fonts']
            fonts_def = @lilypond_version! >= ly.v{2, 25, 4} and [[fonts.roman = "%s"
    fonts.sans = "%s"
    fonts.typewriter = "%s"]] or [[
#(define fonts
    (make-pango-font-tree "%s"
                        "%s"
                        "%s"
                        (/ staff-height pt 20)))
]]
            return fonts_def\format @rmfamily, @sffamily, @ttfamily
        else
            return '%% fonts not set'

    _.ly_header = => includes_parse @include_header

    _.ly_indent = =>
        if not (@indent == false and @insert == 'fullpage')
            return "indent = #{@indent or 0}\\pt"
        else
            return '%% no indent set'

    _.ly_language = => @language and "\\language \"#{@language}\"\n\n" or ''

    _.ly_linewidth = => @['line-width']

    _.ly_staffsize = => @staffsize

    _.ly_margins = =>
        horizontal_margins = @twoside and [[
            inner-margin = %f\pt]]\format(@tex_margin_inner!) or [[
            left-margin = %f\pt]]\format @tex_margin_left!
        tex_top = @['extra-top-margin'] + @tex_margin_top!
        tex_bottom = @['extra-bottom-margin'] + @tex_margin_bottom!
        if @fullpagealign == 'crop'
            return [[
    top-margin = %f\pt
    bottom-margin = %f\pt
    %s]]\format tex_top, tex_bottom, horizontal_margins
        elseif @fullpagealign == 'staffline'
            top_distance = 4 * tex_top / @staffsize + 2
            bottom_distance = 4 * tex_bottom / @staffsize + 2
            return [[
    top-margin = 0\pt
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
]]\format horizontal_margins, top_distance, top_distance, top_distance, top_distance, bottom_distance, bottom_distance
        else
            err [[
Invalid argument for option 'fullpagealign'.
Allowed: 'crop', 'staffline'.
Given: %s
]], @fullpagealign

    _.ly_paper = =>
        system_count = @['system-count'] == '0' and '' or "system-count = #{@['system-count']}\n    "
        papersize = "#(set-paper-size \"#{@papersize or 'lyluatexfmt'}\")"
        if @insert == 'fullpage'
            first_page_number = @['first-page-number'] or tex.count['c@page']
            pfpn = @['print-first-page-number'] and 't' or 'f'
            ppn = @['print-page-number'] and 't' or 'f'
            return [[
    %s%s
    print-page-number = ##%s
    print-first-page-number = ##%s
    first-page-number = %d
%s]]\format system_count, papersize, ppn, pfpn, first_page_number, @ly_margins!
        else return "%s%s"\format "#{papersize}\n\n", system_count

    _.ly_preamble = =>
        result = [[#(set! paper-alist (cons '("lyluatexfmt" . (cons (* %f pt) (* %f pt))) paper-alist))]]\format @paperwidth, @paperheight
        @insert == 'fullpage' and result or "#{result}\n\n\\include \"lilypond-book-preamble.ly\""

    _.ly_raggedright = =>
        if @['ragged-right'] != 'default'
            return "ragged-right = #{@['ragged-right'] and '##t' or '##f'}"
        else
            return '%% no alignment set'

    _.ly_staffprops = =>
        clef = '%% no clef set'
        timing = '    %% timing not suppressed'
        timesig = '    %% no time signature set'
        staff = '    %% staff symbol not suppressed'
        if @noclef then clef = [[\context { \Staff \remove "Clef_engraver" }]]
        if @notiming then timing = [[\context { \Score timing = ##f }]]
        if @notimesig then timesig = [[\context { \Staff \remove "Time_signature_engraver" }]]
        if @nostaffsymbol then staff = [[\context { \Staff \remove "Staff_symbol_engraver" }]]
        '%s\n%s\n%s\n%s'\format clef, timing, timesig, staff

    _.ly_twoside = => @twoside and 't' or 'f'

    _.ly_version = => @['ly-version']

    _.optimize_pdf = =>
        if not @['optimize-pdf'] then return
        if @lilypond_has_TeXGS() and not ly.final_optimization_message
            ly.final_optimization_message = true
            luatexbase.add_to_callback 'stop_run',
                -> info "Optimization enabled: remember to run\n'gs -q -dBATCH -dNOPAUSE -sDEVICE=pdfwrite -sOutputFile=%s %s'.",
                    tex.jobname..'-final.pdf', tex.jobname..'.pdf',
                'lyluatex optimize-pdf'
        else
            local pdf2ps, ps2pdf, path
            for file in lfs.dir @tmpdir
                path = "#{@tmpdir}/#{file}"
                if path\match(@output) and path\sub(-4) == '.pdf'
                    pdf2ps = io.popen "gs -q -sDEVICE=ps2write -sOutputFile=- -dNOPAUSE #{path} -c quit", "r"
                    ps2pdf = io.popen "gs -q -dBATCH -dNOPAUSE -sDEVICE=pdfwrite -sOutputFile=#{path}-gs -", "w"
                    if pdf2ps
                        ps2pdf\write pdf2ps\read"*a"
                        pdf2ps\close!
                        ps2pdf\close!
                        os.rename "#{path}-gs", path
                    else
                        warn"You have asked for pdf optimization, but gs wasn't found."

    _.output_filename = =>
        properties = ''
        for k in orderedpairs ly_opts.declarations
            if (not contains HASHIGNORE, k) and @[k] and type(@[k]) != 'function'
                properties = "#{properties}\n#{k}\t#{@[k]}"
        if @insert == 'fullpage'
            properties ..= "#{@tex_margin_top!}#{@tex_margin_bottom!}#{@tex_margin_left!}#{@tex_margin_right!}"
        filename = md5.sumhexa "#{@flatten_content @ly_code}#{properties}"
        return "#{@tmpdir}/#{filename}"

    _.process = =>
        @check_properties!
        @calc_properties!
        if not @lilypond_version!
            warning = [[
LilyPond could not be started.
Please check that LuaLaTeX is started with the
--shell-escape option, and that 'program'
points to a valid LilyPond executable.
]]
            if @showfailed
                warn warning
                tex.sprint [[
\begin{quote}
\minibox[frame]{LilyPond could not be started.}
\end{quote}

]]
                return
            else
                err warning
        -- with bbox_read check_protrusion will only execute with
        -- a prior compilation, otherwise it will be ignored
        do_compile = not @check_protrusion bbox_read
        if @['force-compilation'] or do_compile
            while true
                @complete_ly_code = @header!..@content!..@footer!
                @run_lilypond!
                @['force-compilation'] = false
                if @is_compiled! then table.insert @output_names, @output
                else
                    @clean_failed_compilation!
                    break
                break if @check_protrusion bbox_get
            @optimize_pdf!
        else table.insert @output_names, @output
        set_lyscore @
        warn"The score doesn't contain any music:\nthis will probably cause bad output." if @count_systems! == 0
        @write_latex(do_compile) if not @['raw-pdf']
        @write_to_filelist!
        @delete_intermediate_files! if not @debug

    _.run_lily_proc = (p) =>
            if @debug
                f = assert io.open("#{@output}.log", 'w'), "#{@output} can’t be written."
                f\write p\read"*a"
                f\close!
            else p\write @complete_ly_code
            p\close!

    _.run_lilypond = =>
        return if @is_compiled!
        mkdirs dirname @output
        if not @run_lily_proc(io.popen @lilypond_cmd @complete_ly_code) and not @debug
            @debug = true
            @lilypond_error = not @run_lily_proc(io.popen @lilypond_cmd @complete_ly_code)
        lilypond_pdf, mode = @lilypond_cmd @complete_ly_code
        if lilypond_pdf\match"-E"
            lilypond_pdf = lilypond_pdf\gsub " %-E", " --pdf"
            @run_lily_proc io.popen lilypond_pdf, mode

    _.tex_margin_bottom = =>
        @_tex_margin_bottom or= convert_unit"#{tex.dimen.paperheight}sp" - @tex_margin_top! - convert_unit"#{tex.dimen.textheight}sp"
        @_tex_margin_bottom

    _.tex_margin_inner = =>
        @_tex_margin_inner or= convert_unit"#{tex.sp('1in') + tex.dimen.oddsidemargin + tex.dimen.hoffset}sp"
        @_tex_margin_inner

    _.tex_margin_outer = =>
        @_tex_margin_outer or= convert_unit"#{tex.dimen.paperwidth - tex.dimen.textwidth}sp" - @tex_margin_inner!
        @_tex_margin_outer

    _.tex_margin_left = => @is_odd_page! or not @twopage and @tex_margin_inner! or @tex_margin_outer!

    _.tex_margin_right = => @is_odd_page! or not @twopage and @tex_margin_outer! or @tex_margin_inner!

    _.tex_margin_top = =>
        @_tex_margin_top or= convert_unit"#{tex.sp'1in' + tex.dimen.voffset + tex.dimen.topmargin + tex.dimen.headheight + tex.dimen.headsep}sp"
        @_tex_margin_top

    _.write_latex = (do_compile) =>
        latex_filename @printfilename, @insert, @input_file
        latex_verbatim @verbatim, @ly_code, @intertext, @addversion
        if do_compile and not @check_compilation! then return
        --[[ Now we know there is a proper score --]]
        latex_fullpagestyle @fullpagestyle, @['print-page-number']
        latex_label @label, @labelprefix
        if @insert == 'fullpage'
            latex_includepdf @output, @range, @papersize
        elseif @insert == 'systems'
            latex_includesystems @output, @range, @protrusion_left, @leftgutter, @staffsize, @indent_offset
        else  -- inline
            if @count_systems! > 1
                warn"Score with more than one system included inline.\nThis will probably cause bad output."
            if bb = @bbox 1
                latex_includeinline @output, bb.height, @valign, @hpadding, @voffset

    _.write_to_filelist = =>
        f = assert io.open(FILELIST, 'a'), "#{FILELIST} can’t be written."
        for file in *@output_names
            filename = file\match"./+(.*)"
            f\write(filename, '\t', @input_file or '', '\t', @label or '', '\n')
        f\close!


--[[ ========================== Public functions ========================== --]]


ly.buffenv_begin = ->
    ly.buffenv = =>
        table.insert ly.score_content, @
        return '' if not @find [[\end{%w+}]]
    ly.score_content = {}
    luatexbase.add_to_callback 'process_input_buffer', ly.buffenv, 'readline'

ly.buffenv_end = ->
    luatexbase.remove_from_callback 'process_input_buffer', 'readline'
    table.remove ly.score_content

ly.clean_tmp_dir = ->
    local hash, file_is_used
    hash_list = {}
    for file in lfs.dir Score.tmpdir
        if file\sub(-5, -1) == '.list'
            i = assert io.open"#{Score.tmpdir}/#{file}", "#{Score.tmpdir}/#{file} can’t be written."
            for line in *i\read"*a"\explode"\n"
                hash = line\explode"\t"[1]
                table.insert(hash_list, hash) if hash != ''
            i\close!
    for file in lfs.dir Score.tmpdir
        if file != '.' and file != '..' and file\sub(-5, -1) != '.list'
            for lhash in *hash_list
                file_is_used = file\find lhash
                break if file_is_used
            os.remove(Score.tmpdir..'/'..file) if not file_is_used

ly.conclusion_text = -> info "Output written on %s.pdf.\nTranscript written on %s.log.", tex.jobname, tex.jobname

ly.make_list_file = ->
    tmpdir = ly_opts.tmpdir
    mkdirs tmpdir
    FILELIST = "#{tmpdir}/#{splitext status.log_name, 'log'}.list"
    os.remove FILELIST

ly.file = (options) =>
    -- Here, we only take in account global option includepaths,
    -- as it really doesn't mean anything as a option.
    file = locate @, Score.includepaths, '.ly'
    options = ly_opts\check_local_options(options)
    err("File %s doesn't exist.", @) if not file
    i = assert io.open(file, 'r'), "#{file} can’t be read"
    ly.score = Score\new i\read"*a", options, file
    i\close!

ly.file_musicxml = (options) =>
    -- Here, we only take in account global option includepaths,
    -- as it really doesn't mean anything as a option.
    file = locate @, Score.includepaths, '.xml'
    options = ly_opts\check_local_options options
    err("File %s doesn't exist.", @) if not file
    xmlopts = ''
    for opt in *MXML_OPTIONS
        if options[opt] != nil
            if options[opt]
                xmlopts ..= " --#{opt}"
                xmlopts ..= " #{options[opt]}" if options[opt] != 'true' and options[opt] != ''
        elseif ly_opts[opt] then xmlopts ..= " --#{opt}"
    i = assert io.popen("#{ly_opts.xml2ly} --out=-#{xmlopts} \"#{file}\"", 'r'), "#{ly_opts.xml2ly} couldn’t be launched."
    if not i
        err [[
%s could not be started.
Please check that LuaLaTeX is started with the
--shell-escape option.
]], ly_opts.xml2ly
    ly.score = Score\new i\read"*a", options, file
    i\close!

ly.fragment = (options) =>
    options = ly_opts\check_local_options(options)
    if type(@) == 'string'
        @ = @gsub('\\par ', '\n')\gsub('\\([^%s]*) %-([^%s])', '\\%1-%2')
    else @ = table.concat @, '\n'
    ly.score = Score\new @, options

ly.get_font_family = =>
    ft = fontinfo @
    return ft.shared.rawdata.metadata.familyname if ft.shared.rawdata
    warn([[
Some useful informations aren’t available:
you probably loaded polyglossia
before defining the main font, and we have
to "guess" the font’s familyname.
If the text of your scores looks weird,
you should consider using babel instead,
or at least loading polyglossia
after defining the main font.
]])
    ft.fullname\match("[^-]*")

ly.newpage_if_fullpage = -> tex.sprint([[\newpage]]) if ly.score.insert == 'fullpage'

ly.set_fonts = (rm, sf, tt) ->
    if ly.score.rmfamily..ly.score.sffamily..ly.score.ttfamily != ''
        ly.score['pass-fonts'] = 'true'
        info"At least one font family set explicitly. Activate 'pass-fonts'"
    if ly.score.rmfamily == ''
        ly.score.rmfamily = ly.get_font_family rm
    else
        -- if explicitly set don't override rmfamily with 'current' font
        if ly.score['current-font-as-main']
            info"rmfamily set explicitly. Deactivate 'current-font-as-main'"
        ly.score['current-font-as-main'] = false
    ly.score.sffamily = ly.get_font_family(sf) if ly.score.sffamily == ''
    ly.score.ttfamily = ly.get_font_family(tt) if ly.score.ttfamily == ''

ly.v = do
    _ = {
        __sub: (other) =>
            for i = 1, max #@, #other
                diff = (@[i] or 0) - (other[i] or 0)
                if diff != 0 then return diff, i
            0
        __eq: (other) => return @ - other == 0
        __lt: (other) => return @ - other < 0
        __call: (v) =>
            v[i] = tonumber v[i] for i = 1, #v
            setmetatable v, @
        __tostring: => table.concat(@, ".")
    }
    setmetatable _, _

ly.write_to_file = (content) =>
    f = assert io.open("#{Score.tmpdir}/#{@}", "w"), "#{Score.tmpdir}/#{@} can’t be written."
    f\write content
    f\close!

ly
