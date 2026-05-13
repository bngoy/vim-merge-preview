" merge_preview#commits: the bottom-left commits panel.

let s:HEADER_LINES = 2

function! merge_preview#commits#populate(path, oldpath) abort
  let l:state = merge_preview#ui#state()
  let l:commits = merge_preview#git#commits_for_file(l:state.merge_base, a:path, a:oldpath)
  let l:state.commits = l:commits

  let l:lines = ['Commits for: ' . a:path . '   (<CR> diff, R reset, q close)', '']
  if empty(l:commits)
    call add(l:lines, '(no commits on branch for this file)')
  else
    for l:c in l:commits
      call add(l:lines, l:c.sha . '  ' . l:c.subject)
    endfor
  endif

  let l:winid = l:state.win_commits
  if win_id2win(l:winid) == 0
    return
  endif
  let l:prev = win_getid()
  call win_gotoid(l:winid)
  call merge_preview#util#set_lines(l:lines)
  call win_gotoid(l:prev)
endfunction

function! merge_preview#commits#clear() abort
  let l:state = merge_preview#ui#state()
  let l:state.commits = []
  let l:winid = l:state.win_commits
  if win_id2win(l:winid) == 0
    return
  endif
  let l:prev = win_getid()
  call win_gotoid(l:winid)
  call merge_preview#util#set_lines(['Commits', '', '(select a file to view its commits)'])
  call win_gotoid(l:prev)
endfunction

function! merge_preview#commits#activate() abort
  let l:state = merge_preview#ui#state()
  if !l:state.active || empty(l:state.active_path)
    return
  endif
  let l:idx = line('.') - 1 - s:HEADER_LINES
  if l:idx < 0 || l:idx >= len(l:state.commits)
    return
  endif
  let l:c = l:state.commits[l:idx]
  call merge_preview#diff#show_commit(l:c.sha, l:state.active_path)
  call win_gotoid(l:state.win_commits)
endfunction
