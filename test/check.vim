" Force-load every script and assert the public API parsed without errors.
" A syntax error while sourcing aborts that file, leaving its functions
" undefined, which this catches.
runtime! autoload/merge_preview.vim
runtime! autoload/merge_preview/git.vim
runtime! autoload/merge_preview/tree.vim
runtime! autoload/merge_preview/icons.vim
runtime! autoload/merge_preview/diff.vim

let s:ok = 1
for s:fn in [
      \ 'merge_preview#open', 'merge_preview#close', 'merge_preview#toggle',
      \ 'merge_preview#activate', 'merge_preview#refresh',
      \ 'merge_preview#jump_file', 'merge_preview#complete_ref',
      \ 'merge_preview#git#root', 'merge_preview#git#merge_base',
      \ 'merge_preview#git#changed_files', 'merge_preview#git#show',
      \ 'merge_preview#tree#build', 'merge_preview#tree#render',
      \ 'merge_preview#icons#file', 'merge_preview#icons#status_sign',
      \ 'merge_preview#diff#open', 'merge_preview#diff#reset']
  if !exists('*' . s:fn)
    let s:ok = 0
    call writefile(['MISSING ' . s:fn], $MP_OUT, 'a')
  endif
endfor
call writefile(['OK=' . s:ok], $MP_OUT, 'a')
