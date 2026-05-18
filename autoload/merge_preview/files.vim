" merge_preview#files: the top-left files panel (NERDTree-style tree).

let s:HEADER_LINES = 2

function! merge_preview#files#populate() abort
  let l:state = merge_preview#ui#state()
  let l:files = merge_preview#git#changed_files(l:state.merge_base, l:state.mode)
  let l:state.files = l:files
  let l:state.tree = merge_preview#tree#build(l:files)

  let l:mode_label = l:state.mode ==# 'branch' ? 'branch-to-branch' : 'local changes'
  let l:header = printf('%s  [%s]  base: %s   (<CR> open/toggle, m mode, r refresh, q close)',
        \ '▾ merge-preview', l:mode_label, l:state.base)
  let l:lines = [l:header, '']

  if empty(l:files)
    let l:state.tree_nodes = []
    call add(l:lines, '(no changes between HEAD and ' . l:state.base . ')')
  else
    let l:rendered = merge_preview#tree#render(l:state.tree, l:state.collapsed)
    let l:state.tree_nodes = l:rendered.nodes
    call extend(l:lines, l:rendered.lines)
  endif

  call s:write_panel(l:lines)
endfunction

function! s:write_panel(lines) abort
  let l:state = merge_preview#ui#state()
  let l:winid = l:state.win_files
  if win_id2win(l:winid) == 0
    return
  endif
  let l:prev = win_getid()
  let l:save_pos = -1
  if win_getid() == l:winid
    let l:save_pos = line('.')
  endif
  call win_gotoid(l:winid)
  let l:cur = line('.')
  call merge_preview#util#set_lines(a:lines)
  let l:target = l:save_pos > 0 ? l:save_pos : l:cur
  if l:target > line('$')
    let l:target = line('$')
  endif
  call cursor(l:target, 1)
  call win_gotoid(l:prev)
endfunction

function! merge_preview#files#activate() abort
  let l:state = merge_preview#ui#state()
  if !l:state.active
    return
  endif
  let l:idx = line('.') - 1 - s:HEADER_LINES
  if l:idx < 0 || l:idx >= len(l:state.tree_nodes)
    return
  endif
  let l:node = l:state.tree_nodes[l:idx]

  if l:node.is_dir
    if has_key(l:state.collapsed, l:node.path)
      call remove(l:state.collapsed, l:node.path)
    else
      let l:state.collapsed[l:node.path] = 1
    endif
    let l:keep = line('.')
    call merge_preview#files#populate()
    call win_gotoid(l:state.win_files)
    call cursor(min([l:keep, line('$')]), 1)
    return
  endif

  let l:entry = l:node.entry
  let l:state.active_path = l:entry.path
  let l:state.active_oldpath = get(l:entry, 'oldpath', '')
  let l:state.active_status = l:entry.status
  call merge_preview#diff#show_default(l:entry)
  call merge_preview#commits#populate(l:entry.path, l:state.active_oldpath)
  call win_gotoid(l:state.win_files)
endfunction
