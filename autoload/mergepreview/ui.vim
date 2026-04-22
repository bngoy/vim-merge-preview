" autoload/mergepreview/ui.vim - window/buffer construction

function! s:ScratchBuf(name) abort
  execute 'silent keepalt file ' . fnameescape(a:name)
  setlocal buftype=nofile
  setlocal bufhidden=wipe
  setlocal noswapfile
  setlocal nobuflisted
  setlocal nowrap
  setlocal nonumber
  setlocal norelativenumber
  setlocal signcolumn=no
endfunction

" Panel headers: a title line + an underline drawn across the window width.
" Returns the list of lines to prepend; also sets b:mp_header_lines so handlers
" (fold expr, click handlers, line-to-index mappers) can skip the header.
function! s:HeaderLines(title) abort
  let l:w = max([winwidth(0), 40])
  " ASCII separator so we don't depend on Unicode rendering.
  let l:bar = repeat('─', l:w - 1)
  let b:mp_header_lines = 2
  return [' ' . a:title, l:bar]
endfunction

function! s:SetFilesMappings() abort
  nnoremap <silent> <buffer> <CR> :call <SID>FilesOpen()<CR>
  nnoremap <silent> <buffer> o    :call <SID>FilesOpen()<CR>
  nnoremap <silent> <buffer> q    :MergePreviewClose<CR>
endfunction

function! s:SetCommitsMappings() abort
  nnoremap <silent> <buffer> <CR> :call <SID>CommitsShow()<CR>
  nnoremap <silent> <buffer> q    :MergePreviewClose<CR>
endfunction

function! s:SetFileViewMappings() abort
  nnoremap <silent> <buffer> ]c         :call mergepreview#JumpHunk(1)<CR>
  nnoremap <silent> <buffer> [c         :call mergepreview#JumpHunk(-1)<CR>
  nnoremap <silent> <buffer> <leader>mt :MergePreviewToggle<CR>
  nnoremap <silent> <buffer> <leader>mq :MergePreviewClose<CR>
endfunction

function! s:FilesOpen() abort
  let l:s = mergepreview#Session()
  if empty(l:s) | return | endif
  let l:idx = line('.') - get(b:, 'mp_header_lines', 0) - 1
  if l:idx < 0 || l:idx >= len(l:s.files)
    return
  endif
  call mergepreview#OpenFile(l:s.files[l:idx].path)
endfunction

function! s:CommitsShow() abort
  let l:line = getline('.')
  let l:sha = matchstr(l:line, '^\x\{7,40}')
  if empty(l:sha)
    " cursor may be on a body line; walk up to find the header
    let l:lnum = line('.')
    while l:lnum > 0
      let l:h = matchstr(getline(l:lnum), '^\x\{7,40}')
      if !empty(l:h)
        let l:sha = l:h
        break
      endif
      let l:lnum -= 1
    endwhile
  endif
  call mergepreview#ShowCommit(l:sha)
endfunction

function! s:GotoWin(winid) abort
  if a:winid <= 0 | return 0 | endif
  let l:nr = win_id2win(a:winid)
  if l:nr <= 0 | return 0 | endif
  execute l:nr . 'wincmd w'
  return 1
endfunction

function! mergepreview#ui#Open(session) abort
  " Open a fresh tabpage so we don't disturb the user's current layout.
  tabnew
  let a:session.tabpagenr = tabpagenr()

  " Middle (file view) is the current window of the new tabpage.
  call s:ScratchBuf('mergepreview://view')
  let a:session.view_winid = win_getid()
  let a:session.view_bufnr = bufnr('%')
  call s:SetFileViewMappings()

  " Files panel on the left.
  execute 'vertical topleft 30new'
  call s:ScratchBuf('mergepreview://files')
  let a:session.files_bufnr = bufnr('%')
  let a:session.files_winid = win_getid()
  call mergepreview#ui#RenderFiles(a:session)
  call s:SetFilesMappings()

  " Commits panel on the right.
  execute 'vertical botright 50new'
  call s:ScratchBuf('mergepreview://commits')
  let a:session.commits_bufnr = bufnr('%')
  let a:session.commits_winid = win_getid()
  setlocal foldmethod=expr
  setlocal foldexpr=mergepreview#commits#FoldExpr(v:lnum)
  setlocal foldtext=mergepreview#commits#FoldText()
  setlocal foldlevel=0
  setlocal fillchars=fold:\
  call s:SetCommitsMappings()

  " Return to the file view window.
  call s:GotoWin(a:session.view_winid)
endfunction

function! mergepreview#ui#RenderFiles(session) abort
  let l:win = win_id2win(a:session.files_winid)
  if l:win <= 0 | return | endif
  let l:cur = win_getid()
  execute l:win . 'wincmd w'
  setlocal modifiable
  silent %delete _
  let l:title = printf('Changes: %s vs %s', a:session.head, a:session.base)
  let l:lines = s:HeaderLines(l:title)
  for l:f in a:session.files
    call add(l:lines, printf('%s  %s', l:f.status, l:f.path))
  endfor
  call setline(1, l:lines)
  setlocal nomodifiable
  setlocal cursorline
  " Move cursor past the header so <CR> on the first keypress opens a file.
  call cursor(b:mp_header_lines + 1, 1)
  syntax clear
  " Header: title (line 1) and underline (line 2).
  execute 'syntax match mergepreviewTitle /\%1l.*/'
  execute 'syntax match mergepreviewRule  /\%2l.*/'
  syntax match mergepreviewStatusA /^A\ze\s/
  syntax match mergepreviewStatusM /^M\ze\s/
  syntax match mergepreviewStatusD /^D\ze\s/
  syntax match mergepreviewStatusR /^R\ze\s/
  highlight default link mergepreviewTitle   Title
  highlight default link mergepreviewRule    NonText
  highlight default link mergepreviewStatusA DiffAdd
  highlight default link mergepreviewStatusM DiffChange
  highlight default link mergepreviewStatusD DiffDelete
  highlight default link mergepreviewStatusR DiffChange
  call s:GotoWin(l:cur)
endfunction

function! mergepreview#ui#RenderCommits(session) abort
  let l:win = win_id2win(a:session.commits_winid)
  if l:win <= 0 | return | endif
  let l:cur = win_getid()
  execute l:win . 'wincmd w'
  setlocal modifiable
  silent %delete _
  let l:title = printf('Commits touching %s (%s..HEAD)',
        \ a:session.active_file, a:session.base)
  let l:lines = s:HeaderLines(l:title)
  let l:commits = mergepreview#git#CommitsForFile(
        \ a:session.merge_base, a:session.active_file)
  for l:c in l:commits
    call add(l:lines, printf('%s %s', l:c.sha, l:c.subject))
    for l:b in l:c.body
      call add(l:lines, '    ' . l:b)
    endfor
  endfor
  if empty(l:commits)
    call add(l:lines, '(no commits on HEAD touch this file)')
  endif
  call setline(1, l:lines)
  setlocal nomodifiable
  setlocal cursorline
  call cursor(b:mp_header_lines + 1, 1)
  syntax clear
  execute 'syntax match mergepreviewTitle /\%1l.*/'
  execute 'syntax match mergepreviewRule  /\%2l.*/'
  syntax match mergepreviewSha /^\x\{7,40}\ze /
  highlight default link mergepreviewTitle Title
  highlight default link mergepreviewRule  NonText
  highlight default link mergepreviewSha   Identifier
  " Re-apply fold settings in case syntax reset affected state.
  setlocal foldmethod=expr
  setlocal foldexpr=mergepreview#commits#FoldExpr(v:lnum)
  normal! zM
  call s:GotoWin(l:cur)
endfunction

function! mergepreview#ui#RenderFileView(session) abort
  if empty(a:session.active_file) | return | endif
  let l:win = win_id2win(a:session.view_winid)
  if l:win <= 0 | return | endif
  execute l:win . 'wincmd w'

  " Close any diffsplit side window created by a previous render.
  call s:ResetViewWindow(a:session)

  if a:session.mode ==# 'diff'
    call s:RenderDiffMode(a:session)
  elseif a:session.mode ==# 'difft' && executable('difft')
    call s:RenderDifftMode(a:session)
  else
    call s:RenderPlainMode(a:session)
  endif
  call s:SetFileViewMappings()
endfunction

function! s:ResetViewWindow(session) abort
  " If a previous render created a sibling split in the middle column, close
  " any window whose buffer is one of our auxiliary diff buffers.
  let l:keep = {}
  let l:keep[a:session.files_winid] = 1
  let l:keep[a:session.commits_winid] = 1
  let l:keep[a:session.view_winid] = 1
  " Iterate from highest to lowest to keep indices stable while closing.
  for l:wi in reverse(range(1, winnr('$')))
    let l:id = win_getid(l:wi)
    if has_key(l:keep, l:id) | continue | endif
    let l:name = bufname(winbufnr(l:wi))
    if l:name =~# '^mergepreview://\%(base\|head\|difft-lhs\|difft-rhs\):'
      execute l:wi . 'close'
    endif
  endfor
  call s:GotoWin(a:session.view_winid)
  diffoff!
endfunction

function! s:RenderDiffMode(session) abort
  " Two-buffer split: merge-base version on the left, HEAD version on the
  " right. Each side handles the "file didn't exist at this ref" case by
  " falling back to an empty scratch buffer.
  let l:file = a:session.active_file
  let l:status = s:StatusFor(a:session, l:file)

  " Right side (HEAD) — the existing view window.
  call s:LoadRefIntoCurrentWin(
        \ a:session, 'HEAD', l:file, l:status !=# 'D',
        \ 'mergepreview://head:' . l:file)
  let a:session.view_bufnr = bufnr('%')
  diffthis

  " Left side (merge-base).
  execute 'leftabove vnew'
  call s:LoadRefIntoCurrentWin(
        \ a:session, a:session.merge_base, l:file, l:status !=# 'A',
        \ 'mergepreview://base:' . a:session.merge_base[0:6] . ':' . l:file)
  diffthis

  " Return to the HEAD side so mappings and hunk jumps act on real line #s.
  wincmd p
endfunction

function! s:StatusFor(session, file) abort
  for l:f in a:session.files
    if l:f.path ==# a:file
      return l:f.status
    endif
  endfor
  return 'M'
endfunction

" If exists==1, populate a scratch buffer from `git show <ref>:<file>`; else
" leave it empty. Either way, set a stable name and scratch-buffer options.
function! s:LoadRefIntoCurrentWin(session, ref, file, exists, name) abort
  enew
  call s:ScratchBuf(a:name)
  setlocal modifiable
  if a:exists
    let l:cmd = 'git show ' . shellescape(a:ref . ':' . a:file)
    silent execute 'read !' . l:cmd
    silent 1delete _
  endif
  " Infer filetype from extension for syntax highlighting inside the diff.
  let l:ft = s:FiletypeFor(a:file)
  if !empty(l:ft)
    execute 'setlocal filetype=' . l:ft
  endif
  setlocal nomodifiable
endfunction

function! s:FiletypeFor(file) abort
  let l:ext = fnamemodify(a:file, ':e')
  if empty(l:ext) | return '' | endif
  let l:map = {
        \ 'py': 'python', 'rb': 'ruby', 'go': 'go', 'rs': 'rust',
        \ 'js': 'javascript', 'ts': 'typescript', 'jsx': 'javascriptreact',
        \ 'tsx': 'typescriptreact', 'sh': 'sh', 'vim': 'vim',
        \ 'md': 'markdown', 'c': 'c', 'h': 'c', 'cpp': 'cpp', 'hpp': 'cpp',
        \ 'java': 'java', 'lua': 'lua', 'yml': 'yaml', 'yaml': 'yaml',
        \ 'json': 'json', 'toml': 'toml',
        \ }
  return get(l:map, tolower(l:ext), '')
endfunction

" Structural (AST-aware) side-by-side diff using difftastic.
"
" Instead of rendering difft's terminal output, we ask for its JSON form
" (`difft --display json`) which exposes:
"   - aligned_lines: [[lhs_lineno|null, rhs_lineno|null], ...] — the exact
"     lhs↔rhs row mapping, with null meaning "filler on that side".
"   - chunks[][]: per-line change spans with byte offsets and a highlight
"     enum (novel/changed/delimiter/...).
"
" We load the two file versions from git, walk `aligned_lines` to produce
" two row-aligned scratch buffers (blank filler lines where null), and
" apply Vim 9 text properties per `chunks[].changes` for the structural
" highlights. scrollbind/cursorbind keep the panes in sync without
" invoking Vim's diff engine — the alignment is difft's, not Vim's.
function! s:RenderDifftMode(session) abort
  let l:file = a:session.active_file
  let l:status = s:StatusFor(a:session, l:file)

  let l:entry = s:DifftFetchJson(a:session, l:file)
  if empty(l:entry)
    " JSON unavailable / parse failure / no changes — degrade to plain.
    call s:RenderPlainMode(a:session)
    return
  endif

  let l:lhs_src = l:status !=# 'A'
        \ ? mergepreview#git#FileAtRef(a:session.merge_base, l:file)
        \ : []
  let l:rhs_src = l:status !=# 'D'
        \ ? mergepreview#git#FileAtRef('HEAD', l:file)
        \ : []

  let l:built = s:DifftBuildAligned(l:entry, l:lhs_src, l:rhs_src)

  " Stored so ]c/[c can translate a HEAD-side line number (from
  " git diff --unified=0) into the corresponding buffer row in the aligned
  " RHS buffer.
  let a:session.difft_rhs_map = l:built.rhs_line_to_row

  " Right side (HEAD/rhs) — the existing view window.
  call s:DifftFillWindow(
        \ 'mergepreview://difft-rhs:' . l:file,
        \ l:built.rhs_lines, l:file)
  let l:rhs_bufnr = bufnr('%')
  let a:session.view_bufnr = l:rhs_bufnr

  " Left side (merge-base/lhs).
  execute 'leftabove vnew'
  call s:DifftFillWindow(
        \ 'mergepreview://difft-lhs:' . a:session.merge_base[0:6] . ':' . l:file,
        \ l:built.lhs_lines, l:file)
  let l:lhs_bufnr = bufnr('%')

  if has('textprop')
    call s:DifftApplyHighlights(l:entry,
          \ l:lhs_bufnr, l:rhs_bufnr,
          \ l:built.lhs_line_to_row, l:built.rhs_line_to_row)
  endif

  " Return focus to the HEAD pane and sync the bind.
  wincmd p
  syncbind
endfunction

function! s:DifftFetchJson(session, file) abort
  let l:cmd = 'env GIT_EXTERNAL_DIFF=' . shellescape('difft --display json')
        \ . ' git diff --ext-diff '
        \ . shellescape(a:session.merge_base) . '...HEAD -- '
        \ . shellescape(a:file)
  let l:out = systemlist(l:cmd)
  if v:shell_error != 0 || empty(l:out)
    return {}
  endif
  try
    let l:parsed = json_decode(join(l:out, "\n"))
  catch
    return {}
  endtry
  if type(l:parsed) != v:t_list || empty(l:parsed)
    return {}
  endif
  return l:parsed[0]
endfunction

" Walk aligned_lines to produce two row-aligned arrays and per-side line→row
" maps (so chunk highlights can be placed at the right buffer row, not at
" the source line number which would be wrong after fillers shift things).
function! s:DifftBuildAligned(entry, lhs_src, rhs_src) abort
  let l:aligned = get(a:entry, 'aligned_lines', [])
  let l:lhs = []
  let l:rhs = []
  let l:lhs_map = {}
  let l:rhs_map = {}
  let l:row = 1
  for l:pair in l:aligned
    let l:l = type(l:pair) == v:t_list ? get(l:pair, 0, v:null) : v:null
    let l:r = type(l:pair) == v:t_list ? get(l:pair, 1, v:null) : v:null
    if l:l is v:null
      call add(l:lhs, '')
    else
      call add(l:lhs, get(a:lhs_src, l:l - 1, ''))
      let l:lhs_map[l:l] = l:row
    endif
    if l:r is v:null
      call add(l:rhs, '')
    else
      call add(l:rhs, get(a:rhs_src, l:r - 1, ''))
      let l:rhs_map[l:r] = l:row
    endif
    let l:row += 1
  endfor
  return {
        \ 'lhs_lines': l:lhs,
        \ 'rhs_lines': l:rhs,
        \ 'lhs_line_to_row': l:lhs_map,
        \ 'rhs_line_to_row': l:rhs_map,
        \ }
endfunction

function! s:DifftFillWindow(name, lines, src_file) abort
  enew
  call s:ScratchBuf(a:name)
  setlocal modifiable
  if !empty(a:lines)
    call setline(1, a:lines)
  endif
  setlocal nomodifiable
  let l:ft = s:FiletypeFor(a:src_file)
  if !empty(l:ft)
    execute 'setlocal filetype=' . l:ft
  endif
  setlocal scrollbind cursorbind nowrap
endfunction

" Map difft's `highlight` enum values to Vim highlight groups. Strings like
" `string-kind` and `type-kind` appear for syntax roles — link them to
" Identifier so they blend in. The important ones for the user's eye are
" novel (whole-line additions on one side) and changed (edits inside a
" line).
let s:difft_prop_types = {
      \ 'novel':           'DiffAdd',
      \ 'changed':         'DiffText',
      \ 'delimiter':       'Delimiter',
      \ 'string-partial':  'String',
      \ 'type-partial':    'Type',
      \ }

function! s:DifftEnsurePropTypes() abort
  for [l:name, l:hl] in items(s:difft_prop_types)
    let l:type = 'mergepreview_difft_' . l:name
    if empty(prop_type_get(l:type))
      call prop_type_add(l:type, {'highlight': l:hl, 'combine': 1})
    endif
  endfor
endfunction

function! s:DifftApplyHighlights(entry, lhs_bufnr, rhs_bufnr, lhs_map, rhs_map) abort
  call s:DifftEnsurePropTypes()
  for l:chunk in get(a:entry, 'chunks', [])
    if type(l:chunk) != v:t_list | continue | endif
    for l:pair in l:chunk
      if type(l:pair) != v:t_dict | continue | endif
      call s:DifftApplySide(
            \ a:lhs_bufnr, a:lhs_map, get(l:pair, 'lhs', {}))
      call s:DifftApplySide(
            \ a:rhs_bufnr, a:rhs_map, get(l:pair, 'rhs', {}))
    endfor
  endfor
endfunction

function! s:DifftApplySide(bufnr, line_map, side) abort
  if type(a:side) != v:t_dict || empty(a:side) | return | endif
  let l:src_line = get(a:side, 'line_number', 0)
  if !has_key(a:line_map, l:src_line) | return | endif
  let l:row = a:line_map[l:src_line]
  for l:change in get(a:side, 'changes', [])
    if type(l:change) != v:t_dict | continue | endif
    let l:hl = get(l:change, 'highlight', 'normal')
    if l:hl ==# 'normal' | continue | endif
    let l:type = 'mergepreview_difft_' . l:hl
    if empty(prop_type_get(l:type))
      " Unknown highlight enum value from difft; fall back to DiffText so
      " the span is still visible rather than silently dropped.
      let l:type = 'mergepreview_difft_changed'
    endif
    " Difft emits byte offsets (0-based); prop_add wants 1-based columns
    " and a length.
    let l:col = get(l:change, 'start', 0) + 1
    let l:len = get(l:change, 'end', 0) - get(l:change, 'start', 0)
    if l:len <= 0 | continue | endif
    try
      call prop_add(l:row, l:col, {
            \ 'bufnr': a:bufnr,
            \ 'type': l:type,
            \ 'length': l:len,
            \ })
    catch
      " Line shorter than the column range (can happen on trailing-newline
      " mismatches); skip rather than fail the whole render.
    endtry
  endfor
endfunction

function! s:RenderPlainMode(session) abort
  enew
  call s:ScratchBuf('mergepreview://diff:' . a:session.active_file)
  setlocal modifiable
  let l:cmd = 'git diff ' . shellescape(a:session.merge_base) . '...HEAD -- '
        \ . shellescape(a:session.active_file)
  silent execute 'read !' . l:cmd
  silent 1delete _
  setlocal filetype=diff
  setlocal nomodifiable
  let a:session.view_bufnr = bufnr('%')
endfunction

function! mergepreview#ui#FocusHunk(session, idx) abort
  if a:idx < 0 || a:idx >= len(a:session.hunks) | return | endif
  let l:hunk = a:session.hunks[a:idx]
  let l:win = win_id2win(a:session.view_winid)
  if l:win <= 0 | return | endif
  execute l:win . 'wincmd w'

  if a:session.mode ==# 'diff'
    " view_bufnr holds the HEAD file verbatim; line numbers match source.
    call cursor(l:hunk.start, 1)
    normal! zz
  elseif a:session.mode ==# 'difft'
    " The RHS buffer is row-aligned with fillers, so source line N lives at
    " buffer row difft_rhs_map[N] — not at row N.
    let l:row = get(get(a:session, 'difft_rhs_map', {}), l:hunk.start, l:hunk.start)
    call cursor(l:row, 1)
    normal! zz
  elseif a:session.mode ==# 'plain'
    let l:pat = '^@@ [^@]* +' . l:hunk.start . '\(,\d\+\)\? @@'
    call cursor(1, 1)
    call search(l:pat, 'c')
    normal! zz
  endif
endfunction

function! mergepreview#ui#HighlightCommitForHunk(session, idx) abort
  if a:idx < 0 || a:idx >= len(a:session.hunks) | return | endif
  let l:hunk = a:session.hunks[a:idx]
  let l:sha = mergepreview#git#BlameShaForLine(a:session.active_file, l:hunk.start)
  if empty(l:sha) | return | endif
  " Only highlight when the blamed commit is within merge_base..HEAD.
  if !has_key(a:session.range_shas, l:sha)
        \ && !has_key(a:session.range_shas, l:sha[0:6])
    return
  endif
  let l:win = win_id2win(a:session.commits_winid)
  if l:win <= 0 | return | endif
  let l:cur = win_getid()
  execute l:win . 'wincmd w'
  let l:short = l:sha[0:6]
  call cursor(1, 1)
  if search('^' . l:short . ' ', 'c') > 0
    normal! zv
  endif
  call s:GotoWin(l:cur)
endfunction

function! mergepreview#ui#Close(session) abort
  let l:tp = get(a:session, 'tabpagenr', 0)
  " Wipe our scratch buffers.
  for l:bn in [get(a:session, 'files_bufnr', -1),
              \ get(a:session, 'commits_bufnr', -1),
              \ get(a:session, 'view_bufnr', -1)]
    if l:bn > 0 && bufexists(l:bn)
      execute 'silent! bwipeout! ' . l:bn
    endif
  endfor
  " Close the dedicated tabpage if it still exists and is empty.
  if l:tp > 0 && l:tp <= tabpagenr('$')
    " If switching tabs is safe, try to close it.
    execute 'silent! tabclose ' . l:tp
  endif
endfunction
