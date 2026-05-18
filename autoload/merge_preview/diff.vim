" merge_preview#diff: load the right-pane vimdiff views.

" Run a diff-building function with the panel layout pinned: 'equalalways'
" is disabled so creating/closing the diff windows doesn't redistribute
" width across every window, and the files/commits panel sizes are
" snapshotted beforehand and restored afterward.
function! s:with_stable_layout(Fn, arg) abort
  let l:save_ea = &equalalways
  call merge_preview#ui#snapshot_panel_sizes()
  set noequalalways
  try
    call a:Fn(a:arg)
  finally
    call merge_preview#ui#restore_panel_sizes()
    let &equalalways = l:save_ea
  endtry
endfunction

" Show the default diff for a file entry.
"   local  mode: file at the branch point  vs  the working tree (editable).
"   branch mode: file at the branch point  vs  the file at HEAD (read-only).
function! merge_preview#diff#show_default(entry) abort
  call s:with_stable_layout(function('s:do_show_default'), a:entry)
endfunction

function! s:do_show_default(entry) abort
  let l:state = merge_preview#ui#state()
  let l:base_label = l:state.base
  let l:base_rev = !empty(l:state.merge_base) ? l:state.merge_base : l:state.base
  let l:path = a:entry.path
  let l:status = a:entry.status
  let l:oldpath = !empty(get(a:entry, 'oldpath', '')) ? a:entry.oldpath : l:path
  let l:branch_mode = (l:state.mode ==# 'branch')

  call merge_preview#ui#close_diff_area()

  if merge_preview#git#is_submodule(l:path)
    call win_gotoid(merge_preview#ui#open_diff_anchor())
    call s:populate_scratch('[submodule] ' . l:path,
          \ ['[submodule]', '', l:path, '', 'Submodule diffs are not supported.'], '')
    return
  endif

  if merge_preview#git#is_binary(l:base_rev, '', l:path)
    call win_gotoid(merge_preview#ui#open_diff_anchor())
    call s:populate_scratch('[binary] ' . l:path,
          \ ['[binary file]', '', l:path, '', 'Diff not shown for binary files.'], '')
    return
  endif

  call win_gotoid(merge_preview#ui#open_diff_anchor())

  let l:left_blob = merge_preview#git#show_blob(l:base_rev, l:oldpath)

  if l:status ==# 'A'
    " New on branch: nothing on the base side.
    call s:right_side(l:branch_mode, l:path, l:base_label)
    let l:ft = s:current_ft(l:path)
    diffthis
    leftabove vnew
    call s:populate_scratch('[base: ' . l:base_label . '] ' . l:path . ' (new file)',
          \ [], l:ft)
    diffthis
  elseif l:status ==# 'D'
    " Deleted on branch: nothing on the working/HEAD side.
    call s:populate_scratch('[base: ' . l:base_label . '] ' . l:oldpath,
          \ l:left_blob.ok ? l:left_blob.lines : [], l:oldpath)
    diffthis
    rightbelow vnew
    let l:rname = l:branch_mode ? '[HEAD] ' : '[working] '
    call s:populate_scratch(l:rname . l:path . ' (deleted)', [], l:oldpath)
    diffthis
  else
    call s:right_side(l:branch_mode, l:path, l:base_label)
    let l:ft = s:current_ft(l:path)
    diffthis
    leftabove vnew
    if !l:left_blob.ok
      call s:populate_scratch('[base: ' . l:base_label . '] ' . l:oldpath . ' (not in base)',
            \ [], l:ft)
    else
      call s:populate_scratch('[base: ' . l:base_label . '] ' . l:oldpath,
            \ l:left_blob.lines, l:ft)
    endif
    diffthis
  endif
endfunction

" Load the right-hand side: the real working file (local mode, editable) or
" a read-only scratch of the file at HEAD (branch mode).
function! s:right_side(branch_mode, path, base_label) abort
  if a:branch_mode
    let l:blob = merge_preview#git#show_blob('HEAD', a:path)
    call s:populate_scratch('[HEAD] ' . a:path
          \ . (l:blob.ok ? '' : ' (not at HEAD)'),
          \ l:blob.ok ? l:blob.lines : [], a:path)
  else
    call s:load_working_file(a:path)
  endif
endfunction

" Filetype of the current buffer, falling back to the path for scratch
" buffers that have no detectable type yet.
function! s:current_ft(path) abort
  return !empty(&filetype) ? &filetype : a:path
endfunction

" Show <sha> vs its parent for the given path.
function! merge_preview#diff#show_commit(sha, current_path) abort
  call s:with_stable_layout(function('s:do_show_commit'),
        \ {'sha': a:sha, 'path': a:current_path})
endfunction

function! s:do_show_commit(arg) abort
  let l:sha = a:arg.sha
  let l:current_path = a:arg.path
  let l:state = merge_preview#ui#state()
  call merge_preview#ui#close_diff_area()

  let l:parents = merge_preview#git#commit_parents(l:sha)

  let l:anchor = merge_preview#ui#open_diff_anchor()
  call win_gotoid(l:anchor)

  if empty(l:parents)
    let l:blob = merge_preview#git#show_blob(l:sha, l:current_path)
    let l:lines = ['[Initial commit ' . l:sha . ' — no parent to diff against]', '']
          \ + (l:blob.ok ? l:blob.lines : [])
    call s:populate_scratch('[' . l:sha . '] ' . l:current_path, l:lines, l:current_path)
    return
  endif

  let l:is_merge = len(l:parents) > 1
  let l:notice = l:is_merge
        \ ? ['[Merge commit — diffing against first parent ' . l:parents[0] . ']', '']
        \ : []
  let l:parent = l:sha . '^1'

  let l:parent_path = merge_preview#git#rename_at_commit(l:sha, l:current_path)

  " Right side: child version.
  let l:child_blob = merge_preview#git#show_blob(l:sha, l:current_path)
  let l:right_lines = l:notice + (l:child_blob.ok ? l:child_blob.lines : [])
  let l:right_name = '[' . l:sha . '] ' . l:current_path
        \ . (l:child_blob.ok ? '' : ' (not in commit)')
  call s:populate_scratch(l:right_name, l:right_lines, l:current_path)
  diffthis

  " Left side: parent version.
  leftabove vnew
  let l:parent_blob = merge_preview#git#show_blob(l:parent, l:parent_path)
  let l:left_lines = l:notice + (l:parent_blob.ok ? l:parent_blob.lines : [])
  let l:left_name = '[' . l:sha . '^] ' . l:parent_path
        \ . (l:parent_blob.ok ? '' : ' (not in parent)')
  call s:populate_scratch(l:left_name, l:left_lines, l:current_path)
  diffthis
endfunction

function! merge_preview#diff#reset_to_default() abort
  let l:state = merge_preview#ui#state()
  if empty(l:state.active_path)
    return
  endif
  for l:e in l:state.files
    if l:e.path ==# l:state.active_path
      call merge_preview#diff#show_default(l:e)
      return
    endif
  endfor
endfunction

" --- internals --------------------------------------------------------------

function! s:load_working_file(path) abort
  let l:abspath = merge_preview#ui#state().repo_root . '/' . a:path
  execute 'silent edit ' . fnameescape(l:abspath)
endfunction

" Replace the current buffer with a scratch holding the given lines.
" path_for_ft (optional) gives a path used to derive filetype highlighting,
" or a literal filetype name. Empty = no syntax.
function! s:populate_scratch(name, lines, path_for_ft) abort
  setlocal modifiable noreadonly
  setlocal buftype=nofile
  setlocal bufhidden=wipe
  setlocal nobuflisted
  setlocal noswapfile
  let b:merge_preview_scratch = 1

  silent! %delete _
  if !empty(a:lines)
    call setline(1, a:lines)
  endif

  execute 'silent file ' . fnameescape(a:name)
  setlocal fileformat=unix
  setlocal nomodifiable readonly

  if !empty(a:path_for_ft)
    call s:apply_filetype(a:path_for_ft)
  endif
endfunction

" path_or_ft can be a filetype name (no dot, no slash) or a path-with-extension.
function! s:apply_filetype(path_or_ft) abort
  if a:path_or_ft !~# '[./]' && a:path_or_ft !~# '\s'
    " Looks like a bare filetype name (e.g. 'python').
    let &l:filetype = a:path_or_ft
    return
  endif
  " Trigger Vim's filetype detection using the path as <afile>.
  let l:save_ei = &eventignore
  set eventignore=
  try
    silent execute 'doautocmd filetypedetect BufRead ' . fnameescape(a:path_or_ft)
  finally
    let &eventignore = l:save_ei
  endtry
endfunction
