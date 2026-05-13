" merge_preview#ui: session state, layout, teardown.

" --- session state ----------------------------------------------------------

function! s:fresh_state() abort
  return {
        \ 'active': 0,
        \ 'tearing_down': 0,
        \ 'repo_root': '',
        \ 'base': '',
        \ 'merge_base': '',
        \ 'tabnr': 0,
        \ 'win_files': -1,
        \ 'win_commits': -1,
        \ 'buf_files': -1,
        \ 'buf_commits': -1,
        \ 'files': [],
        \ 'active_path': '',
        \ 'active_oldpath': '',
        \ 'active_status': '',
        \ 'commits': [],
        \ 'saved_diffopt': '',
        \ }
endfunction

if !exists('s:state')
  let s:state = s:fresh_state()
endif

function! merge_preview#ui#state() abort
  return s:state
endfunction

function! merge_preview#ui#is_active() abort
  return get(s:state, 'active', 0) ? 1 : 0
endfunction

" --- open / close -----------------------------------------------------------

function! merge_preview#ui#open(base_override) abort
  if s:state.active
    call merge_preview#ui#close()
  endif

  if !merge_preview#git#set_repo_root()
    call merge_preview#util#error('not in a git repository')
    return
  endif

  let s:state.repo_root = merge_preview#git#repo_root()

  let l:current = merge_preview#git#current_branch()
  let s:state.base = merge_preview#git#detect_base(a:base_override)
  if empty(s:state.base)
    call merge_preview#util#error(
          \ 'could not determine base branch; pass it explicitly: :MergePreview <branch>')
    return
  endif

  if l:current ==# 'HEAD' || empty(l:current)
    call merge_preview#util#info('detached HEAD; using ' . s:state.base . ' as base')
  endif

  let s:state.merge_base = merge_preview#git#merge_base(s:state.base)
  if empty(s:state.merge_base)
    call merge_preview#util#error('could not compute merge-base with ' . s:state.base)
    return
  endif

  let s:state.saved_diffopt = &diffopt
  let &diffopt = g:merge_preview_diffopt

  if g:merge_preview_use_tab
    tabnew
  endif
  let s:state.tabnr = tabpagenr()

  call s:build_layout()
  call s:install_autocmds()

  let s:state.active = 1

  call merge_preview#files#populate()
  call merge_preview#commits#clear()

  call win_gotoid(s:state.win_files)
endfunction

function! merge_preview#ui#close() abort
  if !s:state.active
    return
  endif
  let s:state.tearing_down = 1

  augroup merge_preview_session
    autocmd!
  augroup END

  " Close diff-area windows first.
  call s:close_diff_area()

  " Close the panel windows.
  for l:wid in [s:state.win_files, s:state.win_commits]
    if l:wid > 0 && win_id2win(l:wid) != 0
      call win_gotoid(l:wid)
      if winnr('$') > 1
        silent! close!
      endif
    endif
  endfor

  " Wipe panel buffers.
  for l:bufnr in [s:state.buf_files, s:state.buf_commits]
    if l:bufnr > 0 && bufexists(l:bufnr)
      execute 'silent! bwipeout!' l:bufnr
    endif
  endfor

  call merge_preview#util#wipe_tagged('merge_preview_diff')
  call merge_preview#util#wipe_tagged('merge_preview_scratch')

  if !empty(s:state.saved_diffopt)
    let &diffopt = s:state.saved_diffopt
  endif

  let s:state = s:fresh_state()
endfunction

function! merge_preview#ui#refresh() abort
  if !s:state.active
    return
  endif
  let s:state.merge_base = merge_preview#git#merge_base(s:state.base)
  call merge_preview#files#populate()
  if !empty(s:state.active_path)
    call merge_preview#commits#populate(s:state.active_path, s:state.active_oldpath)
  else
    call merge_preview#commits#clear()
  endif
endfunction

" --- layout -----------------------------------------------------------------

function! s:build_layout() abort
  " Files panel: full-height column on the left.
  topleft vnew
  execute 'vertical resize ' . g:merge_preview_files_width
  call s:apply_panel('files', '[MergePreview Files]', 'mergepreviewfiles')
  let s:state.win_files = win_getid()
  let s:state.buf_files = bufnr('%')

  " Commits panel: horizontal split below files, in the same column.
  rightbelow new
  execute 'resize ' . g:merge_preview_commits_height
  call s:apply_panel('commits', '[MergePreview Commits]', 'mergepreviewcommits')
  let s:state.win_commits = win_getid()
  let s:state.buf_commits = bufnr('%')
endfunction

function! s:apply_panel(kind, name, filetype) abort
  execute 'silent file ' . fnameescape(a:name)
  setlocal buftype=nofile
  setlocal bufhidden=wipe
  setlocal nobuflisted
  setlocal noswapfile
  setlocal nowrap
  setlocal cursorline
  setlocal nonumber
  setlocal norelativenumber
  setlocal signcolumn=no
  setlocal nomodifiable
  setlocal readonly
  let b:merge_preview_panel = a:kind
  execute 'setlocal filetype=' . a:filetype
endfunction

" Close every window in the active tab that isn't one of our two panels.
function! merge_preview#ui#close_diff_area() abort
  call s:close_diff_area()
endfunction

function! s:close_diff_area() abort
  let l:current_tab = tabpagenr()
  let l:victims = []
  for l:info in getwininfo()
    if l:info.tabnr != l:current_tab
      continue
    endif
    if l:info.winid == s:state.win_files || l:info.winid == s:state.win_commits
      continue
    endif
    call add(l:victims, l:info.winid)
  endfor

  for l:wid in l:victims
    if win_id2win(l:wid) == 0
      continue
    endif
    if winnr('$') <= 1
      break
    endif
    call win_gotoid(l:wid)
    silent! diffoff
    silent! close!
  endfor

  call merge_preview#util#wipe_tagged('merge_preview_diff')
endfunction

" Create a fresh, full-height window on the right side and return its id.
function! merge_preview#ui#open_diff_anchor() abort
  call win_gotoid(s:state.win_files)
  vertical botright new
  return win_getid()
endfunction

" --- autocmds ---------------------------------------------------------------

function! s:install_autocmds() abort
  augroup merge_preview_session
    autocmd!
    autocmd WinClosed * call merge_preview#ui#_on_win_closed(expand('<amatch>'))
  augroup END
endfunction

" WinClosed fires after a window is removed from the layout, so it is safe
" to close sibling windows from inside the handler. We schedule the actual
" teardown on the next event-loop tick to avoid mutating window state while
" Vim is still finishing the close that triggered us.
function! merge_preview#ui#_on_win_closed(winid_str) abort
  if s:state.tearing_down || !s:state.active
    return
  endif
  let l:wid = str2nr(a:winid_str)
  if l:wid != s:state.win_files && l:wid != s:state.win_commits
    return
  endif
  let s:state.tearing_down = 1
  augroup merge_preview_session
    autocmd!
  augroup END
  call timer_start(0, function('s:deferred_close'))
endfunction

function! s:deferred_close(timer) abort
  call merge_preview#ui#close()
endfunction
