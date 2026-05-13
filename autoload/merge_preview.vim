" vim-merge-preview: public facade
" Lazy-loaded by Vim on first :MergePreview invocation.

function! merge_preview#open(...) abort
  let l:base = a:0 > 0 ? a:1 : ''
  call merge_preview#ui#open(l:base)
endfunction

function! merge_preview#close() abort
  call merge_preview#ui#close()
endfunction

function! merge_preview#refresh() abort
  call merge_preview#ui#refresh()
endfunction

function! merge_preview#on_files_activate() abort
  call merge_preview#files#activate()
endfunction

function! merge_preview#on_commit_activate() abort
  call merge_preview#commits#activate()
endfunction

function! merge_preview#reset_to_default() abort
  call merge_preview#diff#reset_to_default()
endfunction

function! merge_preview#complete_branch(arglead, cmdline, cursorpos) abort
  return merge_preview#git#branch_complete(a:arglead)
endfunction

function! merge_preview#help() abort
  echo 'merge-preview:'
  echo '  Files panel:    <CR> activate file, r refresh, q close, ? help'
  echo '  Commits panel:  <CR> activate commit, R reset to default, r refresh, q close'
endfunction
