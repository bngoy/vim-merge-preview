" mergepreview.vim - preview a branch before merging it back
" Maintainer: https://github.com/bngoy/vim-merge-preview

if exists('g:loaded_mergepreview')
  finish
endif
let g:loaded_mergepreview = 1

if !exists('g:merge_preview_base')
  let g:merge_preview_base = ''
endif

if !exists('g:merge_preview_delta_args')
  let g:merge_preview_delta_args =
        \ '--paging=never --line-numbers --file-style=omit --hunk-header-style=omit'
endif

command! -nargs=? -complete=customlist,mergepreview#CompleteBase
      \ MergePreview call mergepreview#Open(<q-args>)
command! MergePreviewClose  call mergepreview#Close()
command! MergePreviewToggle call mergepreview#ToggleMode()
