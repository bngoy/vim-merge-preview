" autoload/merge_preview.vim — orchestration for the :MergePreview command:
" panel lifecycle, rendering and node activation.

let s:save_cpo = &cpoptions
set cpoptions&vim

" The single live preview session. Empty when no panel is open.
let s:state = {}

function! s:err(msg) abort
  echohl ErrorMsg | echomsg 'merge-preview: ' . a:msg | echohl None
  return 0
endfunction

function! s:count(files) abort
  let l:c = {'add': 0, 'mod': 0, 'del': 0}
  for l:file in a:files
    if l:file.status ==# 'A'
      let l:c.add += 1
    elseif l:file.status ==# 'D'
      let l:c.del += 1
    else
      let l:c.mod += 1
    endif
  endfor
  return l:c
endfunction

" Recompute base/files/tree/counts for the stored root + target.
function! s:recompute() abort
  let l:base = merge_preview#git#merge_base(s:state.root, s:state.target)
  if l:base ==# ''
    let l:base = s:state.target
  endif
  let l:files = merge_preview#git#changed_files(s:state.root, l:base)
  let s:state.base = l:base
  let s:state.base_short = merge_preview#git#short(s:state.root, l:base)
  let s:state.files = l:files
  let s:state.tree = merge_preview#tree#build(l:files)
  let s:state.counts = s:count(l:files)
endfunction

function! s:config_panel_buffer() abort
  setlocal buftype=nofile bufhidden=hide noswapfile nobuflisted
  setlocal filetype=mergepreview
endfunction

function! s:config_panel_window() abort
  setlocal nonumber norelativenumber nowrap nolist nospell
  setlocal winfixwidth cursorline signcolumn=no foldcolumn=0
  setlocal nomodifiable
endfunction

function! s:setup_mappings() abort
  nnoremap <buffer><silent> <CR>  :call merge_preview#activate('edit')<CR>
  nnoremap <buffer><silent> o     :call merge_preview#activate('edit')<CR>
  nnoremap <buffer><silent> go    :call merge_preview#activate('preview')<CR>
  nnoremap <buffer><silent> p     :call merge_preview#activate('preview')<CR>
  nnoremap <buffer><silent> <2-LeftMouse> :call merge_preview#activate('edit')<CR>
  nnoremap <buffer><silent> za    :call merge_preview#toggle_node()<CR>
  nnoremap <buffer><silent> R     :call merge_preview#refresh()<CR>
  nnoremap <buffer><silent> q     :call merge_preview#close()<CR>
  nnoremap <buffer><silent> J     :call merge_preview#jump_file(1)<CR>
  nnoremap <buffer><silent> K     :call merge_preview#jump_file(-1)<CR>
endfunction

function! s:open_panel() abort
  if s:state.bufnr > 0 && bufexists(s:state.bufnr)
    let l:win = bufwinid(s:state.bufnr)
    if l:win != -1
      call win_gotoid(l:win)
      return
    endif
    topleft vertical new
    execute 'vertical resize ' . g:merge_preview_panel_width
    execute 'buffer ' . s:state.bufnr
    call s:config_panel_window()
    return
  endif
  topleft vertical new
  execute 'vertical resize ' . g:merge_preview_panel_width
  let s:state.bufnr = bufnr('%')
  silent! file MergePreview
  call s:config_panel_buffer()
  call s:config_panel_window()
  call s:setup_mappings()
endfunction

function! s:rerender() abort
  let l:win = bufwinid(s:state.bufnr)
  if l:win == -1
    return
  endif
  call win_gotoid(l:win)
  let [l:lines, l:map] = merge_preview#tree#render(s:state)
  setlocal modifiable
  silent! %delete _
  call setline(1, l:lines)
  setlocal nomodifiable
  call setbufvar(s:state.bufnr, 'merge_preview_map', l:map)
endfunction

function! s:rerender_keep_cursor() abort
  let l:win = bufwinid(s:state.bufnr)
  if l:win == -1
    return
  endif
  call win_gotoid(l:win)
  let l:line = line('.')
  call s:rerender()
  call cursor(min([l:line, line('$')]), 1)
endfunction

function! s:node_under_cursor() abort
  let l:map = getbufvar(s:state.bufnr, 'merge_preview_map', [])
  let l:idx = line('.') - 1
  if l:idx < 0 || l:idx >= len(l:map)
    return {}
  endif
  return l:map[l:idx]
endfunction

" :MergePreview [target]
function! merge_preview#open(arg) abort
  let l:prev_buf = (type(s:state) == v:t_dict && has_key(s:state, 'bufnr')) ? s:state.bufnr : -1
  let l:start = expand('%:p:h')
  let l:root = merge_preview#git#root(l:start)
  if l:root ==# ''
    return s:err('not inside a git repository')
  endif
  let l:target = merge_preview#git#resolve_target(l:root, a:arg)
  if l:target ==# ''
    return s:err('could not determine a target branch; pass one: :MergePreview <branch>')
  endif
  if !merge_preview#git#ref_exists(l:root, l:target)
    return s:err('target ref not found: ' . l:target)
  endif
  let s:state = {
        \ 'root': l:root,
        \ 'target': l:target,
        \ 'branch': merge_preview#git#current_branch(l:root),
        \ 'bufnr': l:prev_buf,
        \ }
  call s:recompute()
  call s:open_panel()
  call s:rerender()
  normal! gg
endfunction

function! merge_preview#refresh() abort
  if empty(s:state) || !has_key(s:state, 'root')
    return
  endif
  call s:recompute()
  call s:rerender_keep_cursor()
  echo 'merge-preview: refreshed'
endfunction

function! merge_preview#close() abort
  call merge_preview#diff#reset()
  if has_key(s:state, 'bufnr') && s:state.bufnr > 0
    let l:win = bufwinid(s:state.bufnr)
    if l:win != -1
      call win_gotoid(l:win)
      close
    endif
    if bufexists(s:state.bufnr)
      silent! execute 'bwipeout ' . s:state.bufnr
    endif
  endif
  let s:state = {}
endfunction

function! merge_preview#toggle(arg) abort
  if has_key(s:state, 'bufnr') && s:state.bufnr > 0 && bufwinid(s:state.bufnr) != -1
    call merge_preview#close()
  else
    call merge_preview#open(a:arg)
  endif
endfunction

" Open the node under the cursor. a:mode is 'edit' (focus the diff) or
" 'preview' (keep focus in the panel).
function! merge_preview#activate(mode) abort
  let l:node = s:node_under_cursor()
  if empty(l:node) || !has_key(l:node, 'type')
    return
  endif
  if l:node.type ==# 'dir'
    let l:node.expanded = !l:node.expanded
    call s:rerender_keep_cursor()
    return
  endif
  call merge_preview#diff#open(s:state, l:node)
  if a:mode ==# 'preview'
    call win_gotoid(bufwinid(s:state.bufnr))
  endif
endfunction

function! merge_preview#toggle_node() abort
  let l:node = s:node_under_cursor()
  if !empty(l:node) && has_key(l:node, 'type') && l:node.type ==# 'dir'
    let l:node.expanded = !l:node.expanded
    call s:rerender_keep_cursor()
  endif
endfunction

" Move the cursor to the next (a:dir=1) or previous (a:dir=-1) file line.
function! merge_preview#jump_file(dir) abort
  let l:map = getbufvar(s:state.bufnr, 'merge_preview_map', [])
  let l:idx = line('.') - 1 + a:dir
  while l:idx >= 0 && l:idx < len(l:map)
    let l:node = l:map[l:idx]
    if !empty(l:node) && has_key(l:node, 'type') && l:node.type ==# 'file'
      call cursor(l:idx + 1, 1)
      return
    endif
    let l:idx += a:dir
  endwhile
endfunction

" Command completion: branches and remote refs.
function! merge_preview#complete_ref(arglead, cmdline, cursorpos) abort
  let l:root = merge_preview#git#root(expand('%:p:h'))
  if l:root ==# ''
    return []
  endif
  let l:cmd = join(map(['git', '-C', l:root, 'for-each-ref',
        \ '--format=%(refname:short)', 'refs/heads', 'refs/remotes'],
        \ 'shellescape(v:val)'), ' ')
  let l:out = systemlist(l:cmd)
  if v:shell_error
    return []
  endif
  return filter(l:out, 'v:val =~# "^" . a:arglead')
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
