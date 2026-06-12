" merge_preview.vim — preview the merge of the current branch into a target
" branch as a NerdTree-style file list plus Gvdiffsplit-style diffs.
" Maintainer: vim-merge-preview
" License: see LICENSE

if exists('g:loaded_merge_preview') || &compatible
  finish
endif
let g:loaded_merge_preview = 1

let s:save_cpo = &cpoptions
set cpoptions&vim

" Configuration (override in your vimrc).
let g:merge_preview_panel_width   = get(g:, 'merge_preview_panel_width', 38)
let g:merge_preview_use_nerd_icons = get(g:, 'merge_preview_use_nerd_icons', 1)

command! -nargs=? -complete=customlist,merge_preview#complete_ref
      \ MergePreview call merge_preview#open(<q-args>)
command! -nargs=? -complete=customlist,merge_preview#complete_ref
      \ MergePreviewToggle call merge_preview#toggle(<q-args>)
command! MergePreviewClose call merge_preview#close()

let &cpoptions = s:save_cpo
unlet s:save_cpo
