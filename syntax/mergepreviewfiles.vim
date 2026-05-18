" Syntax for the MergePreview files panel (tree view).

if exists('b:current_syntax')
  finish
endif

" Header is always the first line.
syntax match mergePreviewHeader  /\%1l.*/

" Directory rows: any indentation, then an open/close glyph, then name + '/'.
syntax match mergePreviewDir     /^\s*[▸▾] .*\/$/ contains=mergePreviewArrow
syntax match mergePreviewArrow   /[▸▾]/ contained

" File rows: indentation, a single git status letter, a space, the name.
syntax match mergePreviewAdded    /^\s*A \S.*$/    contains=mergePreviewRenameOld
syntax match mergePreviewDeleted  /^\s*D \S.*$/    contains=mergePreviewRenameOld
syntax match mergePreviewMod      /^\s*[MT] \S.*$/ contains=mergePreviewRenameOld
syntax match mergePreviewRenamed  /^\s*[RC] \S.*$/ contains=mergePreviewRenameOld
syntax match mergePreviewUnmerged /^\s*U \S.*$/    contains=mergePreviewRenameOld
syntax match mergePreviewRenameOld /⟵ .*$/ contained

" Friendly placeholder line when there is nothing to show.
syntax match mergePreviewEmpty   /^(.*)$/

highlight default link mergePreviewHeader     Title
highlight default link mergePreviewDir        Directory
highlight default link mergePreviewArrow      Special
highlight default link mergePreviewAdded      DiffAdd
highlight default link mergePreviewDeleted    DiffDelete
highlight default link mergePreviewMod        DiffChange
highlight default link mergePreviewRenamed    Identifier
highlight default link mergePreviewUnmerged   WarningMsg
highlight default link mergePreviewRenameOld  Comment
highlight default link mergePreviewEmpty      Comment

let b:current_syntax = 'mergepreviewfiles'
