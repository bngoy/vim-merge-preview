" autoload/mergepreview/commits.vim - fold helpers for the commits panel

" A commit header line starts with a 7-hex-digit sha followed by a space.
function! mergepreview#commits#FoldExpr(lnum) abort
  let l:line = getline(a:lnum)
  if l:line =~# '^\x\{7} '
    return '>1'
  endif
  return '1'
endfunction

function! mergepreview#commits#FoldText() abort
  return getline(v:foldstart)
endfunction
