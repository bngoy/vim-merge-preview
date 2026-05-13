" vim-merge-preview: navigate branch changes with vimdiff
" Maintainer: vim-merge-preview contributors
" License:    See LICENSE

if exists('g:loaded_merge_preview')
  finish
endif
let g:loaded_merge_preview = 1

if v:version < 800
  echohl ErrorMsg
  echom 'merge-preview: requires Vim 8.0 or newer'
  echohl None
  finish
endif

let s:save_cpo = &cpoptions
set cpoptions&vim

let g:merge_preview_base_branch    = get(g:, 'merge_preview_base_branch', '')
let g:merge_preview_default_bases  = get(g:, 'merge_preview_default_bases', ['main', 'master', 'develop'])
let g:merge_preview_files_width    = get(g:, 'merge_preview_files_width', 40)
let g:merge_preview_commits_height = get(g:, 'merge_preview_commits_height', 15)
let g:merge_preview_use_tab        = get(g:, 'merge_preview_use_tab', 0)
let g:merge_preview_diffopt        = get(g:, 'merge_preview_diffopt',
      \ 'internal,filler,closeoff,vertical,algorithm:histogram,indent-heuristic')

command! -nargs=? -complete=customlist,merge_preview#complete_branch
      \ MergePreview        call merge_preview#open(<q-args>)
command! MergePreviewClose   call merge_preview#close()
command! MergePreviewRefresh call merge_preview#refresh()

let &cpoptions = s:save_cpo
unlet s:save_cpo
