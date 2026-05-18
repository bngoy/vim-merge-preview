" merge_preview#tree: build and render a NERDTree-style directory tree.
"
" A node is a dict:
"   {name, path, is_dir, children (dict), order (list of keys), entry}
" entry is the original {path,status,oldpath,sources} for file leaves.

function! merge_preview#tree#build(files) abort
  let l:root = {'name': '', 'path': '', 'is_dir': 1, 'children': {}, 'order': [], 'entry': {}}
  for l:f in a:files
    let l:parts = split(l:f.path, '/')
    let l:node = l:root
    let l:acc = ''
    let l:n = len(l:parts)
    let l:i = 0
    while l:i < l:n
      let l:part = l:parts[l:i]
      let l:acc = empty(l:acc) ? l:part : l:acc . '/' . l:part
      let l:is_leaf = (l:i == l:n - 1)
      if !has_key(l:node.children, l:part)
        let l:node.children[l:part] = {
              \ 'name': l:part,
              \ 'path': l:acc,
              \ 'is_dir': l:is_leaf ? 0 : 1,
              \ 'children': {},
              \ 'order': [],
              \ 'entry': l:is_leaf ? l:f : {},
              \ }
        call add(l:node.order, l:part)
      endif
      let l:node = l:node.children[l:part]
      let l:i += 1
    endwhile
  endfor
  return l:root
endfunction

function! s:cmp(a, b) abort
  return a:a.name ==# a:b.name ? 0 : (a:a.name ># a:b.name ? 1 : -1)
endfunction

" Render the tree. collapsed is a dict of dir-path -> 1.
" Returns {lines: [...], nodes: [...]} with one node per line.
function! merge_preview#tree#render(root, collapsed) abort
  let l:out = {'lines': [], 'nodes': []}
  call s:render_children(a:root, 0, a:collapsed, l:out)
  return l:out
endfunction

function! s:render_children(node, depth, collapsed, out) abort
  let l:dirs = []
  let l:files = []
  for l:key in a:node.order
    let l:child = a:node.children[l:key]
    if l:child.is_dir
      call add(l:dirs, l:child)
    else
      call add(l:files, l:child)
    endif
  endfor
  call sort(l:dirs, function('s:cmp'))
  call sort(l:files, function('s:cmp'))

  let l:indent = repeat('  ', a:depth)

  for l:d in l:dirs
    " Cascade single-subdirectory chains: a/ -> a/b/ -> a/b/c/.
    let l:disp = l:d.name
    let l:cur = l:d
    while len(l:cur.order) == 1 && l:cur.children[l:cur.order[0]].is_dir
      let l:cur = l:cur.children[l:cur.order[0]]
      let l:disp .= '/' . l:cur.name
    endwhile
    let l:is_collapsed = get(a:collapsed, l:cur.path, 0)
    let l:arrow = l:is_collapsed
          \ ? g:merge_preview_arrows[0] : g:merge_preview_arrows[1]
    call add(a:out.lines, l:indent . l:arrow . ' ' . l:disp . '/')
    call add(a:out.nodes, l:cur)
    if !l:is_collapsed
      call s:render_children(l:cur, a:depth + 1, a:collapsed, a:out)
    endif
  endfor

  for l:fl in l:files
    let l:e = l:fl.entry
    let l:label = l:e.status . ' ' . l:fl.name
    if l:e.status =~# '^[RC]' && !empty(get(l:e, 'oldpath', ''))
          \ && l:e.oldpath !=# l:e.path
      let l:label .= '  ⟵ ' . l:e.oldpath
    endif
    call add(a:out.lines, l:indent . '  ' . l:label)
    call add(a:out.nodes, l:fl)
  endfor
endfunction
