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
  let l:lnum = line('.')
  if l:lnum < 1 || l:lnum > len(l:s.files)
    return
  endif
  call mergepreview#OpenFile(l:s.files[l:lnum - 1].path)
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
  let l:lines = []
  for l:f in a:session.files
    call add(l:lines, printf('%s  %s', l:f.status, l:f.path))
  endfor
  call setline(1, l:lines)
  setlocal nomodifiable
  setlocal cursorline
  syntax clear
  syntax match mergepreviewStatusA /^A\ze\s/
  syntax match mergepreviewStatusM /^M\ze\s/
  syntax match mergepreviewStatusD /^D\ze\s/
  syntax match mergepreviewStatusR /^R\ze\s/
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
  let l:commits = mergepreview#git#CommitsForFile(
        \ a:session.merge_base, a:session.active_file)
  let l:lines = []
  for l:c in l:commits
    call add(l:lines, printf('%s %s', l:c.sha, l:c.subject))
    for l:b in l:c.body
      call add(l:lines, '    ' . l:b)
    endfor
  endfor
  if empty(l:lines)
    call add(l:lines, '(no commits on HEAD touch this file)')
  endif
  call setline(1, l:lines)
  setlocal nomodifiable
  setlocal cursorline
  syntax clear
  syntax match mergepreviewSha /^\x\{7,40}\ze /
  highlight default link mergepreviewSha Identifier
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
  elseif a:session.mode ==# 'delta' && executable('delta')
    call s:RenderDeltaMode(a:session)
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
    if l:name =~# '^mergepreview://\%(base\|head\):'
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

function! s:RenderDeltaMode(session) abort
  let l:cmd = 'git -c core.pager=cat diff '
        \ . shellescape(a:session.merge_base) . '...HEAD -- '
        \ . shellescape(a:session.active_file)
        \ . ' | delta ' . g:merge_preview_delta_args
  " Replace the view buffer with a terminal running the pipeline.
  enew
  execute 'terminal ++curwin ++close ' . &shell . ' -c ' . shellescape(l:cmd)
  let a:session.view_bufnr = bufnr('%')
  " Terminal buffers are not modifiable; mappings apply to normal mode.
  call s:SetFileViewMappings()
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
    " In diff mode view_bufnr holds the HEAD file; line numbers match.
    call cursor(l:hunk.start, 1)
    normal! zz
  elseif a:session.mode ==# 'plain'
    " Scan the diff buffer for the matching @@ header.
    let l:pat = '^@@ [^@]* +' . l:hunk.start . '\(,\d\+\)\? @@'
    call cursor(1, 1)
    call search(l:pat, 'c')
    normal! zz
  elseif a:session.mode ==# 'delta'
    " delta --line-numbers prints the new-file line in a fixed gutter.
    let l:pat = '\s\+' . l:hunk.start . '\%(\s\|│\)'
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
