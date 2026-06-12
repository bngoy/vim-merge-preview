" autoload/merge_preview/icons.vim — status signs, fold arrows and filetype
" glyphs for the merge-preview panel.

let s:save_cpo = &cpoptions
set cpoptions&vim

function! merge_preview#icons#enabled() abort
  return get(g:, 'merge_preview_use_nerd_icons', 1)
endfunction

" Single-character status sign shown at the start of every file line.
function! merge_preview#icons#status_sign(status) abort
  if a:status ==# 'A'
    return '+'
  elseif a:status ==# 'D'
    return '-'
  else
    " M, R, C, T are all 'changed'
    return '~'
  endif
endfunction

" Fold arrow for a directory node.
function! merge_preview#icons#arrow(expanded) abort
  if merge_preview#icons#enabled()
    return a:expanded ? '▾' : '▸'
  endif
  return a:expanded ? 'v' : '>'
endfunction

" Folder glyph (returns trailing space when present so callers can concat
" blindly). Empty when nerd icons are disabled.
function! merge_preview#icons#folder(expanded) abort
  if !merge_preview#icons#enabled()
    return ''
  endif
  return a:expanded ? " " : " "
endfunction

let s:default_icon = ''

let s:name_icons = {
      \ 'Dockerfile': '',
      \ 'dockerfile': '',
      \ 'Makefile': '',
      \ 'makefile': '',
      \ 'CMakeLists.txt': '',
      \ 'LICENSE': '',
      \ 'README': '',
      \ 'README.md': '',
      \ '.gitignore': '',
      \ '.gitattributes': '',
      \ '.gitmodules': '',
      \ '.vimrc': '',
      \ '.bashrc': '',
      \ '.zshrc': '',
      \ }

let s:ext_icons = {
      \ 'vim': '', 'lua': '', 'py': '', 'pyc': '', 'rb': '',
      \ 'js': '', 'mjs': '', 'cjs': '', 'jsx': '', 'ts': '', 'tsx': '',
      \ 'json': '', 'json5': '', 'html': '', 'htm': '', 'xml': '',
      \ 'css': '', 'scss': '', 'sass': '', 'less': '',
      \ 'md': '', 'markdown': '', 'rst': '', 'txt': '', 'org': '',
      \ 'sh': '', 'bash': '', 'zsh': '', 'fish': '', 'ps1': '',
      \ 'c': '', 'h': '', 'cpp': '', 'cc': '', 'cxx': '', 'hpp': '',
      \ 'go': '', 'rs': '', 'java': '', 'class': '', 'kt': '', 'kts': '',
      \ 'php': '', 'pl': '', 'pm': '', 'swift': '', 'scala': '', 'clj': '',
      \ 'cs': '', 'fs': '', 'ex': '', 'exs': '', 'erl': '', 'hs': '',
      \ 'yml': '', 'yaml': '', 'toml': '', 'ini': '', 'cfg': '', 'conf': '',
      \ 'sql': '', 'db': '', 'sqlite': '',
      \ 'png': '', 'jpg': '', 'jpeg': '', 'gif': '', 'svg': '', 'ico': '',
      \ 'pdf': '', 'zip': '', 'tar': '', 'gz': '', 'tgz': '', 'rar': '',
      \ 'lock': '', 'log': '', 'env': '', 'gradle': '', 'mk': '',
      \ 'tf': '', 'tfvars': '', 'dockerignore': '',
      \ }

" Filetype glyph for a file name (returns trailing space when present).
" Empty string when nerd icons are disabled.
function! merge_preview#icons#file(name) abort
  if !merge_preview#icons#enabled()
    return ''
  endif
  if has_key(s:name_icons, a:name)
    return s:name_icons[a:name] . ' '
  endif
  let l:ext = tolower(fnamemodify(a:name, ':e'))
  if l:ext !=# '' && has_key(s:ext_icons, l:ext)
    return s:ext_icons[l:ext] . ' '
  endif
  return s:default_icon . ' '
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
