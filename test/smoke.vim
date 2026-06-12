" Interactive smoke test: open the panel, exercise ]f / [f navigation and open
" a diff, then write the observed state to $MP_OUT. Sourced from test/run.sh in
" a TTY so window and diff commands behave normally. Kept in a file (rather than
" inline -c args) to avoid shell quoting fragility.
execute 'cd ' . fnameescape($MP_REPO)
let v:errmsg = ''
MergePreview main
call cursor(1, 1)
normal ]f
let s:l1 = line('.')
normal ]f
let s:l2 = line('.')
normal [f
let s:l3 = line('.')
call merge_preview#activate('edit')
call writefile([
      \ 'wins=' . winnr('$'),
      \ 'diff=' . &diff,
      \ 'err=' . v:errmsg,
      \ 'nav=' . s:l1 . ',' . s:l2 . ',' . s:l3,
      \ ], $MP_OUT)
