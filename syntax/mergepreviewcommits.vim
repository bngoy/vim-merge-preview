" Syntax for the MergePreview commits panel.

if exists('b:current_syntax')
  finish
endif

syntax match mergePreviewCommitHeader  /\%1l.*/
syntax match mergePreviewCommitSha     /^[0-9a-f]\{7,40\}/
syntax match mergePreviewCommitEmpty   /^(.*)$/

highlight default link mergePreviewCommitHeader Title
highlight default link mergePreviewCommitSha    Identifier
highlight default link mergePreviewCommitEmpty  Comment

let b:current_syntax = 'mergepreviewcommits'
