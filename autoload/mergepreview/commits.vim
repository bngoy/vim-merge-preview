" autoload/mergepreview/commits.vim - fold helpers for the commits panel

" A commit header line starts with a 7-hex-digit sha followed by a space.
" The first b:mp_header_lines lines are the panel title and rule; they stay at
" level 0 so they're never folded into the first commit's body.
function! mergepreview#commits#FoldExpr(lnum) abort
  if a:lnum <= get(b:, 'mp_header_lines', 0)
    return '0'
  endif
  let l:line = getline(a:lnum)
  if l:line =~# '^\x\{7} '
    return '>1'
  endif
  return '1'
endfunction

function! mergepreview#commits#FoldText() abort
  return getline(v:foldstart)
endfunction
