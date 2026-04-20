# vim-merge-preview

Preview a feature branch before merging it back — a Vim plugin that opens a
three-pane layout showing changed files, the file diff, and per-file commit
history for the branch vs. the branch it was cut from.

```
+-- Files ---+---- File view ---------+--- Commits ------+
|* M foo.py  | diff / delta / plain   |> abc1234 Add X   |
|  A bar.go  |                        |> def4567 Fix edge|
|  M baz.md  |                        |> 7f9a224 Refactor|
+------------+------------------------+------------------+
```

The base branch is auto-detected (`@{upstream}` → `main` → `master` →
`develop`). Jumping hunks with `]c` / `[c` in the file view moves the
cursor in the commits panel to the commit that owns the hunk (via
`git blame` filtered to the `<merge-base>..HEAD` range).

## Install

With [vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'tpope/vim-fugitive'          " optional but recommended
Plug 'bngoy/vim-merge-preview'
```

Or with Vim 8 packages:

```sh
git clone https://github.com/bngoy/vim-merge-preview \
  ~/.vim/pack/plugins/start/vim-merge-preview
```

For the syntax-highlighted single-pane mode, install
[`delta`](https://github.com/dandavison/delta).

## Usage

| Command              | Effect                                                            |
| -------------------- | ----------------------------------------------------------------- |
| `:MergePreview`      | Open the layout in a new tab; base branch auto-detected.          |
| `:MergePreview main` | Force a specific base branch.                                     |
| `:MergePreviewToggle`| Cycle file view: `diff` → `delta` → `plain` → `diff`.             |
| `:MergePreviewClose` | Tear down the layout.                                             |

### Key mappings (buffer-local)

| Pane        | Key        | Action                                        |
| ----------- | ---------- | --------------------------------------------- |
| Files       | `<CR>` / `o` | Open the file.                              |
| Files       | `q`        | Close the session.                            |
| File view   | `]c` / `[c`| Next / previous hunk + highlight commit.      |
| File view   | `<leader>mt` | Toggle mode.                                |
| File view   | `<leader>mq` | Close session.                              |
| Commits     | `<CR>`     | `git show` the selected commit in a new tab.  |
| Commits     | `za`/`zo`/`zc`/`zM`/`zR` | Native fold controls.           |

### Options

```vim
let g:merge_preview_base = ''            " override base branch
let g:merge_preview_delta_args =
      \ '--paging=never --line-numbers --file-style=omit --hunk-header-style=omit'
```

See `:help mergepreview` for full documentation.

## License

MIT — see [LICENSE](LICENSE).
