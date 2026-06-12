" autoload/merge_preview/git.vim — thin wrappers around git for vim-merge-preview
" Commands are built as shell strings with every argument shellescape()'d, so
" paths with spaces or special characters are handled safely on every Vim build
" (the List form of system() is not available without the +job feature).

let s:save_cpo = &cpoptions
set cpoptions&vim

" Build "git -C <root> <args...>" with every component shell-escaped.
function! s:git(root, args) abort
  let l:parts = ['git', '-C', a:root] + a:args
  return join(map(copy(l:parts), 'shellescape(v:val)'), ' ')
endfunction

" Run git inside a:root and return the output lines (empty list on failure).
function! s:lines(root, args) abort
  let l:out = systemlist(s:git(a:root, a:args))
  if v:shell_error
    return []
  endif
  return l:out
endfunction

" Locate the toplevel of the work tree that contains a:dir.
function! merge_preview#git#root(dir) abort
  let l:dir = (a:dir !=# '' && isdirectory(a:dir)) ? a:dir : getcwd()
  let l:out = systemlist(s:git(l:dir, ['rev-parse', '--show-toplevel']))
  if v:shell_error || empty(l:out)
    return ''
  endif
  return l:out[0]
endfunction

function! merge_preview#git#current_branch(root) abort
  let l:out = s:lines(a:root, ['rev-parse', '--abbrev-ref', 'HEAD'])
  return empty(l:out) ? 'HEAD' : l:out[0]
endfunction

" Does a:ref resolve to a valid commit?
function! merge_preview#git#ref_exists(root, ref) abort
  call system(s:git(a:root, ['rev-parse', '--verify', '--quiet', a:ref . '^{commit}']))
  return v:shell_error == 0
endfunction

" Best guess at the branch a feature branch was created from.
function! merge_preview#git#default_branch(root) abort
  let l:out = s:lines(a:root, ['symbolic-ref', '--quiet', '--short', 'refs/remotes/origin/HEAD'])
  if !empty(l:out)
    return l:out[0]
  endif
  for l:cand in ['main', 'master', 'trunk', 'develop']
    if merge_preview#git#ref_exists(a:root, l:cand)
      return l:cand
    endif
  endfor
  for l:cand in ['origin/main', 'origin/master']
    if merge_preview#git#ref_exists(a:root, l:cand)
      return l:cand
    endif
  endfor
  return ''
endfunction

" Resolve the comparison target: an explicit arg wins, otherwise fall back to
" the repository's default branch.
function! merge_preview#git#resolve_target(root, arg) abort
  if a:arg !=# ''
    return a:arg
  endif
  return merge_preview#git#default_branch(a:root)
endfunction

" The common ancestor of a:target and HEAD — i.e. the point the current branch
" was forked from. This is the 'base' side of every diff.
function! merge_preview#git#merge_base(root, target) abort
  let l:out = s:lines(a:root, ['merge-base', a:target, 'HEAD'])
  return empty(l:out) ? '' : l:out[0]
endfunction

function! merge_preview#git#short(root, rev) abort
  let l:out = s:lines(a:root, ['rev-parse', '--short', a:rev])
  return empty(l:out) ? a:rev[0:7] : l:out[0]
endfunction

" Files that differ between a:base and the working tree, as a list of
" {status, path, oldpath}. status is one of A/M/D/R/C/T.
function! merge_preview#git#changed_files(root, base) abort
  let l:out = s:lines(a:root, ['diff', '--name-status', '-M', a:base, '--'])
  let l:files = []
  for l:line in l:out
    if l:line ==# ''
      continue
    endif
    let l:parts = split(l:line, "\t")
    if len(l:parts) < 2
      continue
    endif
    let l:status = toupper(l:parts[0][0])
    if (l:status ==# 'R' || l:status ==# 'C') && len(l:parts) >= 3
      call add(l:files, {'status': l:status, 'path': l:parts[2], 'oldpath': l:parts[1]})
    else
      call add(l:files, {'status': l:status, 'path': l:parts[1], 'oldpath': ''})
    endif
  endfor
  return l:files
endfunction

" Contents of a:path as it exists at a:rev (empty list if absent).
function! merge_preview#git#show(root, rev, path) abort
  return s:lines(a:root, ['show', a:rev . ':' . a:path])
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
