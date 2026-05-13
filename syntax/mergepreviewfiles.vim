" Syntax for the MergePreview files panel.

if exists('b:current_syntax')
  finish
endif

syntax match mergePreviewHeader  /\%1l.*/
syntax match mergePreviewAdded   /^A\s\+.*/
syntax match mergePreviewDeleted /^D\s\+.*/
syntax match mergePreviewMod     /^M\s\+.*/
syntax match mergePreviewRenamed /^[RC]\s\+.*/
syntax match mergePreviewType    /^T\s\+.*/
syntax match mergePreviewUnmerged /^U\s\+.*/
syntax match mergePreviewEmpty   /^(.*)$/

highlight default link mergePreviewHeader   Title
highlight default link mergePreviewAdded    DiffAdd
highlight default link mergePreviewDeleted  DiffDelete
highlight default link mergePreviewMod      DiffChange
highlight default link mergePreviewRenamed  Identifier
highlight default link mergePreviewType     Type
highlight default link mergePreviewUnmerged WarningMsg
highlight default link mergePreviewEmpty    Comment

let b:current_syntax = 'mergepreviewfiles'
