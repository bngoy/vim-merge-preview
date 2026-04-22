" mergepreview.vim - preview a branch before merging it back
" Maintainer: https://github.com/bngoy/vim-merge-preview

if exists('g:loaded_mergepreview')
  finish
endif
let g:loaded_mergepreview = 1

if !exists('g:merge_preview_base')
  let g:merge_preview_base = ''
endif

" Extra diffopt values layered on top of the user's setting while a session
" is open. Vim 9.1 introduced inline:char for word-level highlighting; keep
" it separable so older Vims skip it automatically.
if !exists('g:merge_preview_diffopt_extras')
  let g:merge_preview_diffopt_extras =
        \ 'linematch:60,algorithm:histogram,indent-heuristic,inline:char'
endif

command! -nargs=? -complete=customlist,mergepreview#CompleteBase
      \ MergePreview call mergepreview#Open(<q-args>)
command! MergePreviewClose      call mergepreview#Close()
command! MergePreviewToggle     call mergepreview#ToggleMode()
command! MergePreviewDifftDebug call mergepreview#ui#DifftDebug(mergepreview#Session())
