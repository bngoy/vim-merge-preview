" Interactive smoke test. Sourced from test/run.sh in a TTY so window and diff
" commands behave normally. Kept in a file (rather than inline -c args) to avoid
" shell quoting fragility.
"
" Verifies: opening a file gives the 3-pane diff; and that ]f / [f issued from
" *inside the diff window* (where they would otherwise be the built-in gf and
" error) step to the next / previous file, opening each, with the panel cursor
" kept in sync. Panel file lines are 7..10 (src/ at 6).
execute 'cd ' . fnameescape($MP_REPO)
let v:errmsg = ''
MergePreview main
let s:panel = bufwinid('MergePreview')

" Open the first file (app.js, line 7) and land focus in the diff.
call cursor(7, 1)
call merge_preview#activate('edit')
let s:wins = winnr('$')
let s:diff = &diff
let s:in_panel_after_open = (bufwinid('MergePreview') == win_getid())
let s:l0 = line('.', s:panel)

" Now drive navigation from the diff window via ]f / [f.
normal ]f
let s:l1 = line('.', s:panel)
normal ]f
let s:l2 = line('.', s:panel)
normal [f
let s:l3 = line('.', s:panel)

call writefile([
      \ 'wins=' . s:wins,
      \ 'diff=' . s:diff,
      \ 'err=' . v:errmsg,
      \ 'in_panel=' . s:in_panel_after_open,
      \ 'nav=' . s:l0 . ',' . s:l1 . ',' . s:l2 . ',' . s:l3,
      \ ], $MP_OUT)
