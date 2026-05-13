" merge_preview#files: the top-left files panel.

let s:HEADER_LINES = 2

function! merge_preview#files#populate() abort
  let l:state = merge_preview#ui#state()
  let l:files = merge_preview#git#changed_files(l:state.merge_base)
  let l:state.files = l:files

  let l:lines = ['Base: ' . l:state.base . '   (press <CR> to diff, r refresh, q close)', '']
  if empty(l:files)
    call add(l:lines, '(no changes between HEAD and ' . l:state.base . ')')
  else
    for l:entry in l:files
      call add(l:lines, s:format_file(l:entry))
    endfor
  endif

  let l:winid = l:state.win_files
  if win_id2win(l:winid) == 0
    return
  endif
  let l:prev = win_getid()
  call win_gotoid(l:winid)
  call merge_preview#util#set_lines(l:lines)
  call win_gotoid(l:prev)
endfunction

function! s:format_file(entry) abort
  if a:entry.status =~# '^[RC]' && !empty(a:entry.oldpath) && a:entry.oldpath !=# a:entry.path
    return a:entry.status . '  ' . a:entry.oldpath . ' → ' . a:entry.path
  endif
  return a:entry.status . '  ' . a:entry.path
endfunction

function! merge_preview#files#activate() abort
  let l:state = merge_preview#ui#state()
  if !l:state.active
    return
  endif
  let l:idx = line('.') - 1 - s:HEADER_LINES
  if l:idx < 0 || l:idx >= len(l:state.files)
    return
  endif
  let l:entry = l:state.files[l:idx]
  let l:state.active_path = l:entry.path
  let l:state.active_oldpath = l:entry.oldpath
  let l:state.active_status = l:entry.status
  call merge_preview#diff#show_default(l:entry)
  call merge_preview#commits#populate(l:entry.path, l:entry.oldpath)
  call win_gotoid(l:state.win_files)
endfunction
