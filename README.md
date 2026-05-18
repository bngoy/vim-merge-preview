# vim-merge-preview

A Vim 8+ plugin that helps you walk every change between the current branch
and the branch it was checked out from, using `vimdiff` as the backbone.

It opens three panels:

- **Top-left**: a NERDTree-style directory tree of every changed file.
  Fixed-width (but manually resizable); its statusline shows the active
  comparison mode and base branch.
- **Bottom-left**: the commits on the current branch that touched the file
  selected above.
- **Right**: a vimdiff view. Activating a commit flips the view to that
  commit against its parent.

Two comparison modes, switchable on the fly with `m` or
`:MergePreviewMode`:

- **local changes** (default): branch commits + staged + unstaged +
  untracked; the right side is the real, editable working file.
- **branch-to-branch**: only what's committed on the branch; the right
  side is the file at HEAD, read-only.

Classic Vim only — Neovim is not supported.

## Install

Drop the repo into a runtime path. With a plugin manager such as vim-plug:

```vim
Plug 'bngoy/vim-merge-preview'
```

Or with native packages:

```sh
mkdir -p ~/.vim/pack/plugins/start
git clone https://github.com/bngoy/vim-merge-preview \
    ~/.vim/pack/plugins/start/vim-merge-preview
```

## Use

```
:MergePreview              " auto-detect base branch
:MergePreview origin/main  " or pass it explicitly
:MergePreviewMode branch   " local <-> branch-to-branch (no arg = toggle)
:MergePreviewClose         " tear it all down
```

Inside the panels:

- Files panel: `<CR>` open file / collapse-expand directory, `m` switch
  mode, `r` refresh, `q` close, `?` help.
- Commits panel: `<CR>` diff that commit, `R` reset to default, `m` switch
  mode, `r` refresh, `q` close.

Scratch (base / historical) buffers get filetype detection for syntax
highlighting; override any time with `:set ft=<ft>` in that window.

## Base branch detection

The plugin walks the following chain until one resolves:

1. The argument to `:MergePreview <branch>`.
2. `g:merge_preview_base_branch`.
3. The upstream of the current branch (`@{u}`).
4. The reflog entry recording where the branch was created.
5. The first existing ref in `g:merge_preview_default_bases`
   (default `['main', 'master', 'develop']`).

If nothing resolves, the plugin asks you to pass the base explicitly.

## Configuration

```vim
let g:merge_preview_base_branch    = ''                    " explicit base
let g:merge_preview_default_bases  = ['main', 'master', 'develop']
let g:merge_preview_files_width    = 40
let g:merge_preview_commits_height = 15
let g:merge_preview_use_tab        = 0                     " 1 = open in :tabnew
let g:merge_preview_arrows         = ['▸', '▾']            " [collapsed, expanded]
let g:merge_preview_diffopt        =
      \ 'internal,filler,closeoff,vertical,algorithm:histogram,indent-heuristic'
```

See `:help merge-preview` for the full reference.

## License

See [LICENSE](LICENSE).
