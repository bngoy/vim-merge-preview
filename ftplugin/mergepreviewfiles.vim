" ftplugin for the MergePreview files panel.

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

nnoremap <buffer> <silent> <nowait> <CR> :call merge_preview#on_files_activate()<CR>
nnoremap <buffer> <silent> <nowait> m    :call merge_preview#mode()<CR>
nnoremap <buffer> <silent> <nowait> r    :call merge_preview#refresh()<CR>
nnoremap <buffer> <silent> <nowait> q    :call merge_preview#close()<CR>
nnoremap <buffer> <silent> <nowait> ?    :call merge_preview#help()<CR>
