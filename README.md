# vim-merge-preview

A Vim 8+ plugin that helps you walk every change between the current branch
and the branch it was checked out from, using `vimdiff` as the backbone.

It opens three panels:

- **Top-left**: every file changed between the base branch and the working
  tree — committed, staged, unstaged, and untracked, combined.
- **Bottom-left**: the commits on the current branch that touched the file
  selected above.
- **Right**: a vimdiff view. By default it shows the working tree against
  the base branch; activating a commit flips the view to that commit
  against its parent.

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
:MergePreviewClose         " tear it all down
```

Inside the panels:

- Files panel: `<CR>` open file, `r` refresh, `q` close, `?` help.
- Commits panel: `<CR>` diff that commit, `R` reset to default, `r` refresh,
  `q` close.

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
let g:merge_preview_diffopt        =
      \ 'internal,filler,closeoff,vertical,algorithm:histogram,indent-heuristic'
```

See `:help merge-preview` for the full reference.

## License

See [LICENSE](LICENSE).
