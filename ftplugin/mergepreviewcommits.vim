" ftplugin for the MergePreview commits panel.

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

nnoremap <buffer> <silent> <nowait> <CR> :call merge_preview#on_commit_activate()<CR>
nnoremap <buffer> <silent> <nowait> R    :call merge_preview#reset_to_default()<CR>
nnoremap <buffer> <silent> <nowait> r    :call merge_preview#refresh()<CR>
nnoremap <buffer> <silent> <nowait> q    :call merge_preview#close()<CR>
nnoremap <buffer> <silent> <nowait> ?    :call merge_preview#help()<CR>
