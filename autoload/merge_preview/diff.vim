" autoload/merge_preview/diff.vim — open a Gvdiffsplit-style diff for a file
" node: panel │ base version (left) │ working copy (right).

let s:save_cpo = &cpoptions
set cpoptions&vim

" Windows we manage for the diff pair, tracked by window-id.
let s:win = {}

function! s:valid(id) abort
  return a:id > 0 && win_id2win(a:id) > 0
endfunction

" Ensure the base/work window pair exists to the right of the panel, reusing
" them across invocations. Returns [base_winid, work_winid].
function! s:ensure_windows(panel) abort
  if s:valid(get(s:win, 'base', 0)) && s:valid(get(s:win, 'work', 0))
    return [s:win.base, s:win.work]
  endif
  call win_gotoid(a:panel)
  wincmd l
  if win_getid() == a:panel
    " Panel is the rightmost window — create a work window beside it.
    rightbelow vertical new
  endif
  let l:work = win_getid()
  leftabove vertical new
  let l:base = win_getid()
  let s:win = {'base': l:base, 'work': l:work}
  return [l:base, l:work]
endfunction

" Load a:lines into the window as a read-only scratch buffer, applying the
" filetype that a:name would normally trigger (for syntax in the diff).
function! s:scratch(winid, lines, name) abort
  call win_gotoid(a:winid)
  silent! diffoff
  enew
  setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted nolist
  setlocal nonumber norelativenumber signcolumn=no foldcolumn=0
  setlocal modifiable
  silent! call setline(1, a:lines)
  setlocal nomodifiable
  if a:name !=# ''
    silent! execute 'doautocmd filetypedetect BufRead ' . fnameescape(a:name)
  endif
endfunction

function! s:work_file(winid, fullpath) abort
  call win_gotoid(a:winid)
  silent! diffoff
  execute 'edit ' . fnameescape(a:fullpath)
endfunction

" Open the diff for a:node using metadata in a:state.
function! merge_preview#diff#open(state, node) abort
  let l:panel = bufwinid(a:state.bufnr)
  if l:panel == -1
    return
  endif
  let [l:base, l:work] = s:ensure_windows(l:panel)
  let l:status = a:node.status
  let l:basepath = get(a:node, 'oldpath', '') !=# '' ? a:node.oldpath : a:node.path
  let l:name = fnamemodify(a:node.path, ':t')

  " Right side: the working copy (empty for a deleted file).
  if l:status ==# 'D'
    call s:scratch(l:work, [], l:name)
  else
    call s:work_file(l:work, a:state.root . '/' . a:node.path)
  endif

  " Left side: the file as it exists at the merge base (empty for a new file).
  if l:status ==# 'A'
    call s:scratch(l:base, [], l:name)
  else
    let l:content = merge_preview#git#show(a:state.root, a:state.base, l:basepath)
    call s:scratch(l:base, l:content, l:name)
  endif

  call win_gotoid(l:base) | diffthis | setlocal foldlevel=99
  call win_gotoid(l:work) | diffthis | setlocal foldlevel=99
  call win_gotoid(l:work)
  silent! normal! gg
  silent! normal! ]c
endfunction

" Tear down diff state so the next open() rebuilds cleanly.
function! merge_preview#diff#reset() abort
  if s:valid(get(s:win, 'base', 0))
    call win_gotoid(s:win.base) | silent! diffoff
  endif
  if s:valid(get(s:win, 'work', 0))
    call win_gotoid(s:win.work) | silent! diffoff
  endif
  let s:win = {}
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
