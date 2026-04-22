# vim-merge-preview

Preview a feature branch before merging it back — a Vim plugin that opens a
three-pane layout showing changed files, the file diff, and per-file commit
history for the branch vs. the branch it was cut from.

```
+-- Files ----------+---- File view -----------+--- Commits ---------------+
| Changes: feat vs  | diff / delta /           | Commits touching foo.py   |
| main              | difft / plain            | (main..HEAD)              |
|-------------------|                          |---------------------------|
|* M foo.py         |                          |> abc1234 Add X            |
|  A bar.go         |                          |> def4567 Fix edge         |
|  M baz.md         |                          |> 7f9a224 Refactor         |
+-------------------+--------------------------+---------------------------+
```

The base branch is auto-detected as the **nearest ancestor**: for every
local branch plus `origin/HEAD`, `origin/main`, `origin/master`, and
`origin/develop`, the plugin computes the merge-base with HEAD and picks
the branch whose `<merge-base>..HEAD` is shortest — i.e. the branch HEAD
was most recently cut from. In a simple main-based workflow this is
`main`; in stacked or `develop`-based workflows it picks the correct
intermediate branch. Ties break in favor of `main` > `master` > `develop`.
Override with `:MergePreview <ref>` or `g:merge_preview_base`.

Jumping hunks with `]c` / `[c` in the file view moves the cursor in the
commits panel to the commit that owns the hunk (via `git blame` filtered
to the `<merge-base>..HEAD` range).

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

For the single-pane file-view modes, install
[`delta`](https://github.com/dandavison/delta) (syntax-highlighted unified
diff) and/or
[`difftastic`](https://github.com/Wilfred/difftastic) (tree-sitter-based
structural diff). Both are optional; the toggle skips modes whose tool
isn't on `$PATH`.

## Usage

| Command              | Effect                                                            |
| -------------------- | ----------------------------------------------------------------- |
| `:MergePreview`      | Open the layout in a new tab; base branch auto-detected.          |
| `:MergePreview main` | Force a specific base branch.                                     |
| `:MergePreviewToggle`| Cycle file view: `diff` → `delta` → `difft` → `plain`. Missing tools are skipped. |
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
let g:merge_preview_difft_args = '--color=always --background=dark'
```

### File-view modes

| Mode    | What it shows                                                      | Requires   |
| ------- | ------------------------------------------------------------------ | ---------- |
| `diff`  | Side-by-side Vim diff: merge-base version left, HEAD version right | (built-in) |
| `delta` | Single-pane, syntax-highlighted unified diff                       | `delta`    |
| `difft` | Single-pane structural (tree-sitter) diff                          | `difft`    |
| `plain` | Single-pane raw unified diff with `filetype=diff`                  | (built-in) |

See `:help mergepreview` for full documentation.

## Troubleshooting

**`mergepreview: no files changed between <base> and HEAD`** — HEAD and
the detected base have no diff. Most common causes:

- *Bare/partial clone without `origin/HEAD`.* Some fresh clones (especially
  bare clones or clones made with `--no-local-branches`) don't have
  `refs/remotes/origin/HEAD` set, so the plugin can't see the remote's
  default branch. Either set it once —
  ```sh
  git remote set-head origin --auto
  ```
  — or skip detection by naming the base explicitly: `:MergePreview main`.

- *Current branch's upstream is itself* (e.g. `feat/x` tracks
  `origin/feat/x`). Auto-detect now prefers `origin/HEAD` and local
  integration branches over `@{upstream}`, so this shouldn't trigger on a
  normal clone; if it does, the bare-clone fix above usually resolves it.

- *You want a non-standard base.* Pass it explicitly:
  ```vim
  :MergePreview some/team-branch
  " or in vimrc:
  let g:merge_preview_base = 'some/team-branch'
  ```

**`:MergePreviewToggle` shows an error message in the middle pane** — the
external tool (`delta` or `difft`) exited non-zero. The error text from the
tool is shown in the terminal buffer so you can see what went wrong
(broken config, `delta` version mismatch, `difft` crash). Toggle again to
advance to the next mode; the cycle still works.

## License

MIT — see [LICENSE](LICENSE).
