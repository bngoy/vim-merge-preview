" autoload/merge_preview/tree.vim — build a nested file tree from a flat list of
" changed files and render it NerdTree-style.

let s:save_cpo = &cpoptions
set cpoptions&vim

function! s:new_dir(name, path) abort
  return {'type': 'dir', 'name': a:name, 'path': a:path,
        \ 'children': [], 'expanded': 1}
endfunction

function! s:find_dir(dir, name) abort
  for l:child in a:dir.children
    if l:child.type ==# 'dir' && l:child.name ==# a:name
      return l:child
    endif
  endfor
  return {}
endfunction

function! s:insert(dir, parts, file) abort
  if len(a:parts) == 1
    call add(a:dir.children, {
          \ 'type': 'file',
          \ 'name': a:parts[0],
          \ 'path': a:file.path,
          \ 'status': a:file.status,
          \ 'oldpath': get(a:file, 'oldpath', '')})
    return
  endif
  let l:head = a:parts[0]
  let l:child = s:find_dir(a:dir, l:head)
  if empty(l:child)
    let l:dpath = a:dir.path ==# '' ? l:head : a:dir.path . '/' . l:head
    let l:child = s:new_dir(l:head, l:dpath)
    call add(a:dir.children, l:child)
  endif
  call s:insert(l:child, a:parts[1:], a:file)
endfunction

function! s:cmp(a, b) abort
  if a:a.type !=# a:b.type
    return a:a.type ==# 'dir' ? -1 : 1
  endif
  return a:a.name <# a:b.name ? -1 : (a:a.name ># a:b.name ? 1 : 0)
endfunction

function! s:sort(node) abort
  call sort(a:node.children, function('s:cmp'))
  for l:child in a:node.children
    if l:child.type ==# 'dir'
      call s:sort(l:child)
    endif
  endfor
endfunction

" Build the tree model (a root 'dir' node) from changed_files output.
function! merge_preview#tree#build(files) abort
  let l:root = s:new_dir('', '')
  for l:file in a:files
    call s:insert(l:root, split(l:file.path, '/'), l:file)
  endfor
  call s:sort(l:root)
  return l:root
endfunction

function! s:render_children(dir, depth, lines, map) abort
  for l:node in a:dir.children
    let l:indent = repeat('  ', a:depth)
    if l:node.type ==# 'dir'
      let l:arrow = merge_preview#icons#arrow(l:node.expanded)
      let l:glyph = merge_preview#icons#folder(l:node.expanded)
      call add(a:lines, l:indent . l:arrow . ' ' . l:glyph . l:node.name . '/')
      call add(a:map, l:node)
      if l:node.expanded
        call s:render_children(l:node, a:depth + 1, a:lines, a:map)
      endif
    else
      let l:sign = merge_preview#icons#status_sign(l:node.status)
      let l:icon = merge_preview#icons#file(l:node.name)
      call add(a:lines, l:indent . l:sign . ' ' . l:icon . l:node.name)
      call add(a:map, l:node)
    endif
  endfor
endfunction

" Render the panel for a:state. Returns [lines, map] where map[i] is the node
" displayed on buffer line i+1 (an empty dict for header/decoration lines).
function! merge_preview#tree#render(state) abort
  let l:lines = []
  let l:map = []
  call add(l:lines, ' Merge Preview') | call add(l:map, {})
  call add(l:lines, ' ' . a:state.branch . ' ⇐ ' . a:state.target) | call add(l:map, {})
  call add(l:lines, ' base ' . a:state.base_short) | call add(l:map, {})
  let l:c = a:state.counts
  call add(l:lines, printf(' +%d  ~%d  -%d', l:c.add, l:c.mod, l:c.del)) | call add(l:map, {})
  call add(l:lines, repeat('─', 30)) | call add(l:map, {})
  if empty(a:state.tree.children)
    call add(l:lines, ' (no changes)') | call add(l:map, {})
  else
    call s:render_children(a:state.tree, 0, l:lines, l:map)
  endif
  return [l:lines, l:map]
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
