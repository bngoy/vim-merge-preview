" autoload/mergepreview.vim - session open/close/toggle

let s:session = {}

function! s:HasSession() abort
  return !empty(s:session) && get(s:session, 'active', 0)
endfunction

function! s:Warn(msg) abort
  echohl WarningMsg | echomsg 'mergepreview: ' . a:msg | echohl None
endfunction

function! s:Err(msg) abort
  echohl ErrorMsg | echomsg 'mergepreview: ' . a:msg | echohl None
endfunction

function! mergepreview#CompleteBase(arglead, cmdline, cursorpos) abort
  let l:out = systemlist('git for-each-ref --format=%(refname:short) refs/heads refs/remotes')
  if v:shell_error != 0
    return []
  endif
  return filter(l:out, 'v:val =~# "^" . a:arglead')
endfunction

function! mergepreview#Open(...) abort
  if s:HasSession()
    call s:Warn('session already open; use :MergePreviewClose first')
    return
  endif

  if !mergepreview#git#InRepo()
    call s:Err('not inside a git work tree')
    return
  endif

  let l:base = (a:0 >= 1 && !empty(a:1)) ? a:1 : g:merge_preview_base
  if empty(l:base)
    let l:base = mergepreview#git#DetectBase()
  endif
  if empty(l:base)
    call s:Err('could not detect a base branch (set g:merge_preview_base)')
    return
  endif

  let l:merge_base = mergepreview#git#MergeBase(l:base)
  if empty(l:merge_base)
    call s:Err('no merge-base between HEAD and ' . l:base)
    return
  endif

  let l:files = mergepreview#git#ChangedFiles(l:merge_base)
  if empty(l:files)
    call s:Warn('no files changed between ' . l:base . ' and HEAD')
    return
  endif

  let l:head = mergepreview#git#HeadName()
  let l:range_shas = mergepreview#git#CommitShasInRange(l:merge_base)

  let s:session = {
        \ 'active': 1,
        \ 'base': l:base,
        \ 'head': l:head,
        \ 'merge_base': l:merge_base,
        \ 'files': l:files,
        \ 'range_shas': l:range_shas,
        \ 'active_file': '',
        \ 'mode': 'diff',
        \ 'hunks': [],
        \ 'hunk_index': -1,
        \ 'files_bufnr': -1,
        \ 'commits_bufnr': -1,
        \ 'view_winid': -1,
        \ 'view_bufnr': -1,
        \ 'prev_tabpage': tabpagenr(),
        \ }

  call mergepreview#ui#Open(s:session)

  " Open the first file by default.
  call mergepreview#SetActiveFile(s:session.files[0].path)
endfunction

function! mergepreview#Close() abort
  if !s:HasSession()
    return
  endif
  call mergepreview#ui#Close(s:session)
  let s:session = {}
endfunction

function! mergepreview#Session() abort
  return s:session
endfunction

function! mergepreview#SetActiveFile(path) abort
  if !s:HasSession()
    return
  endif
  let s:session.active_file = a:path
  let s:session.hunks = mergepreview#git#HunksFor(s:session.merge_base, a:path)
  let s:session.hunk_index = -1

  call mergepreview#ui#RenderFileView(s:session)
  call mergepreview#ui#RenderCommits(s:session)
endfunction

function! mergepreview#ToggleMode() abort
  if !s:HasSession()
    return
  endif
  let l:modes = ['diff', 'plain']
  if executable('delta')
    let l:modes = ['diff', 'delta', 'plain']
  endif
  let l:i = index(l:modes, s:session.mode)
  let l:next = l:modes[(l:i + 1) % len(l:modes)]
  let s:session.mode = l:next
  echo 'mergepreview: mode = ' . l:next
  if !empty(s:session.active_file)
    call mergepreview#ui#RenderFileView(s:session)
  endif
endfunction

function! mergepreview#OpenFile(path) abort
  call mergepreview#SetActiveFile(a:path)
endfunction

function! mergepreview#JumpHunk(direction) abort
  if !s:HasSession() || empty(s:session.hunks)
    return
  endif
  let l:n = len(s:session.hunks)
  let l:idx = s:session.hunk_index
  if a:direction > 0
    let l:idx = (l:idx < 0) ? 0 : (l:idx + 1)
    if l:idx >= l:n | let l:idx = l:n - 1 | endif
  else
    let l:idx = (l:idx <= 0) ? 0 : (l:idx - 1)
  endif
  let s:session.hunk_index = l:idx
  call mergepreview#ui#FocusHunk(s:session, l:idx)
  call mergepreview#ui#HighlightCommitForHunk(s:session, l:idx)
endfunction

function! mergepreview#ShowCommit(sha) abort
  if empty(a:sha)
    return
  endif
  execute 'tabnew | terminal ++curwin ++close git show --color=always '
        \ . shellescape(a:sha)
endfunction
