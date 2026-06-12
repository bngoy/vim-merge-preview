# vim-merge-preview

Preview what merging your current branch into a target branch would look like —
a [NERDTree](https://github.com/preservim/nerdtree)-style file panel on the
left, and [fugitive](https://github.com/tpope/vim-fugitive)
`:Gvdiffsplit`-style side-by-side diffs on the right.

![status signs: + new, ~ modified, - deleted]

```
 Merge Preview          │ base: src/app.js  │ working: src/app.js
 feature/login ⇐ main   │ function login(){ │ function login(){
 base 1a2b3c4           │   return false;   │   return auth();
 +2  ~3  -1             │ }                  │ }
──────────────────────  │                   │
 ▾  src/                │                   │
   ~  app.js            │                   │
   +  auth.js           │                   │
 -  old_helper.js       │                   │
```

## What it does

- `:MergePreview [target]` opens a left panel listing every file that differs
  between your branch and `target`, each tagged with a status sign:
  - `+` (green) — new file
  - `~` (yellow) — modified file (and renames)
  - `-` (red) — deleted file
- With **no target**, it uses the repository's default branch (`origin/HEAD`,
  then `main` / `master` / `trunk` / `develop`) and diffs against the **merge
  base** — the commit your branch was forked from. So you see only the changes
  *your* branch introduces, exactly like a merge/pull request diff.
- Press `<CR>` on a file to open a `Gvdiffsplit`-style vertical diff: the file
  at the merge base on the left, your working copy on the right, with real Vim
  diff highlighting. Added and deleted files are handled too.
- Folders are collapsible and files get Nerd Font icons, NERDTree-style.

**vim-fugitive is _not_ required** — the diff is produced natively. If you do
have fugitive, this lives happily alongside it.

## Install

With a plugin manager, e.g. [vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'bngoy/vim-merge-preview'
```

Or with Vim's built-in package support:

```sh
git clone https://github.com/bngoy/vim-merge-preview \
  ~/.vim/pack/plugins/start/vim-merge-preview
```

Then `:helptags ALL` (or `:Helptags` with fugitive) to index the docs.

## Usage

| Command                       | Effect                                            |
| ----------------------------- | ------------------------------------------------- |
| `:MergePreview`               | Preview against the auto-detected default branch  |
| `:MergePreview main`          | Preview against `main`                            |
| `:MergePreview origin/release`| Preview against any branch / tag / commit         |
| `:MergePreviewToggle`         | Open, or close if already open                    |
| `:MergePreviewClose`          | Close the panel                                   |

### Panel keys

| Key        | Action                                              |
| ---------- | --------------------------------------------------- |
| `<CR>`,`o` | File → open & focus its diff; folder → expand/collapse |
| `go`, `p`  | Open a file's diff but keep the cursor in the panel |
| `za`       | Toggle the folder under the cursor                  |
| `]f`/`[f`  | Open next / previous file's diff (like `<CR>`) — **also works from inside the diff windows**, so you can step through changes without leaving them |
| `J` / `K`  | Move to next / previous file in the panel (without opening) |
| `R`        | Refresh (re-run git)                                |
| `q`        | Close                                               |

## Configuration

```vim
" Width of the left panel (default 38)
let g:merge_preview_panel_width = 45

" Set to 0 for a plain ASCII tree if you don't use a Nerd Font (default 1).
" The +/~/- status signs are always plain ASCII.
let g:merge_preview_use_nerd_icons = 0
```

See `:help merge-preview` for the full reference.

## License

See [LICENSE](LICENSE).
