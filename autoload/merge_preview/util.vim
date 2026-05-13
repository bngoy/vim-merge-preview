" merge_preview#util: small shared helpers

function! merge_preview#util#error(msg) abort
  echohl ErrorMsg
  echom 'merge-preview: ' . a:msg
  echohl None
endfunction

function! merge_preview#util#info(msg) abort
  echohl ModeMsg
  echom 'merge-preview: ' . a:msg
  echohl None
endfunction

" Wipe out every buffer tagged with the given buffer-local variable.
function! merge_preview#util#wipe_tagged(var) abort
  for l:bufnr in range(1, bufnr('$'))
    if !bufexists(l:bufnr)
      continue
    endif
    if getbufvar(l:bufnr, a:var, 0)
      execute 'silent! bwipeout!' l:bufnr
    endif
  endfor
endfunction

" Replace the current buffer's contents with the given lines while
" temporarily lifting 'nomodifiable'.
function! merge_preview#util#set_lines(lines) abort
  let l:was_modifiable = &l:modifiable
  let l:was_readonly = &l:readonly
  setlocal modifiable noreadonly
  try
    silent! %delete _
    if !empty(a:lines)
      call setline(1, a:lines)
    endif
  finally
    let &l:modifiable = l:was_modifiable
    let &l:readonly = l:was_readonly
  endtry
endfunction

" Apply the standard read-only panel buffer options to the current buffer.
function! merge_preview#util#apply_panel_options(panel_name) abort
  setlocal buftype=nofile
  setlocal bufhidden=wipe
  setlocal nobuflisted
  setlocal noswapfile
  setlocal nowrap
  setlocal cursorline
  setlocal nonumber
  setlocal norelativenumber
  setlocal signcolumn=no
  setlocal winfixwidth
  setlocal winfixheight
  setlocal nomodifiable
  setlocal readonly
  let b:merge_preview_panel = a:panel_name
endfunction
