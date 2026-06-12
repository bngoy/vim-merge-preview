" syntax/mergepreview.vim — highlighting for the merge-preview panel.

if exists('b:current_syntax')
  finish
endif

syntax match MergePreviewHeader /\%1l.*/
syntax match MergePreviewBranch /\%2l.*/
syntax match MergePreviewBase   /\%3l.*/
syntax match MergePreviewCount  /\%4l.*/
syntax match MergePreviewSep    /^─\+$/
syntax match MergePreviewDir    /^\s*[▾▸v>]\s.*$/

" Status signs are the first non-blank character on file lines. Defined last so
" they win over the line-level matches above.
syntax match MergePreviewAdd /^\s*\zs+/
syntax match MergePreviewDel /^\s*\zs-/
syntax match MergePreviewMod /^\s*\zs\~/

highlight default link MergePreviewHeader Title
highlight default link MergePreviewBranch Identifier
highlight default link MergePreviewBase   Comment
highlight default link MergePreviewCount  Comment
highlight default link MergePreviewSep    Comment
highlight default link MergePreviewDir    Directory

highlight default MergePreviewAdd ctermfg=green  guifg=#98c379
highlight default MergePreviewDel ctermfg=red    guifg=#e06c75
highlight default MergePreviewMod ctermfg=yellow guifg=#e5c07b

let b:current_syntax = 'mergepreview'
