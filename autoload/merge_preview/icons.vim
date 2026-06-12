" autoload/merge_preview/icons.vim — status signs, fold arrows and filetype
" glyphs for the merge-preview panel.
"
" Glyphs are built from their codepoints with nr2char() rather than embedded as
" literal bytes: the Nerd Font glyphs live in the Unicode Private Use Area and
" do not survive every editing/transport path, whereas plain ASCII hex always
" does.

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

" Fold arrow for a directory node (plain Unicode triangles / ASCII fallback).
function! merge_preview#icons#arrow(expanded) abort
  if merge_preview#icons#enabled()
    return a:expanded ? nr2char(0x25be, 1) : nr2char(0x25b8, 1)
  endif
  return a:expanded ? 'v' : '>'
endfunction

" Folder glyph (returns trailing space when present so callers can concat
" blindly). Empty when nerd icons are disabled.
function! merge_preview#icons#folder(expanded) abort
  if !merge_preview#icons#enabled()
    return ''
  endif
  return nr2char(a:expanded ? 0xf07c : 0xf07b, 1) . ' '
endfunction

let s:default_icon = 0xf15b

" Exact file names → codepoint.
let s:name_icons = {
      \ 'Dockerfile': 0xe7b0, 'dockerfile': 0xe7b0,
      \ 'Makefile': 0xe673, 'makefile': 0xe673, 'CMakeLists.txt': 0xe673,
      \ 'LICENSE': 0xf15b,
      \ 'README': 0xf02d, 'README.md': 0xf02d,
      \ '.gitignore': 0xe702, '.gitattributes': 0xe702, '.gitmodules': 0xe702,
      \ '.vimrc': 0xe62b, '.bashrc': 0xe795, '.zshrc': 0xe795,
      \ }

" Lower-cased extension → codepoint.
let s:ext_icons = {
      \ 'vim': 0xe62b, 'lua': 0xe620, 'py': 0xe606, 'pyc': 0xe606, 'rb': 0xe739,
      \ 'js': 0xe60c, 'mjs': 0xe60c, 'cjs': 0xe60c, 'jsx': 0xe7ba,
      \ 'ts': 0xe628, 'tsx': 0xe7ba,
      \ 'json': 0xe60b, 'json5': 0xe60b,
      \ 'html': 0xe736, 'htm': 0xe736, 'xml': 0xe619,
      \ 'css': 0xe749, 'scss': 0xe603, 'sass': 0xe603, 'less': 0xe758,
      \ 'md': 0xe73e, 'markdown': 0xe73e, 'rst': 0xf15c, 'txt': 0xf15c,
      \ 'org': 0xe633,
      \ 'sh': 0xe795, 'bash': 0xe795, 'zsh': 0xe795, 'fish': 0xf489,
      \ 'ps1': 0xf489,
      \ 'c': 0xe61e, 'h': 0xe61e, 'cpp': 0xe61d, 'cc': 0xe61d, 'cxx': 0xe61d,
      \ 'hpp': 0xe61d,
      \ 'go': 0xe627, 'rs': 0xe7a8, 'java': 0xe738, 'class': 0xe738,
      \ 'kt': 0xe634, 'kts': 0xe634,
      \ 'php': 0xe73d, 'pl': 0xe769, 'pm': 0xe769, 'swift': 0xe755,
      \ 'scala': 0xe737, 'clj': 0xe768, 'cs': 0xe648, 'fs': 0xe7a7,
      \ 'ex': 0xe62d, 'exs': 0xe62d, 'erl': 0xe7b1, 'hs': 0xe777,
      \ 'yml': 0xe615, 'yaml': 0xe615, 'toml': 0xe615, 'ini': 0xe615,
      \ 'cfg': 0xe615, 'conf': 0xe615, 'env': 0xe615,
      \ 'sql': 0xe706, 'db': 0xe706, 'sqlite': 0xe706,
      \ 'png': 0xf1c5, 'jpg': 0xf1c5, 'jpeg': 0xf1c5, 'gif': 0xf1c5,
      \ 'svg': 0xf1c5, 'ico': 0xf1c5,
      \ 'pdf': 0xf1c1, 'zip': 0xf1c6, 'tar': 0xf1c6, 'gz': 0xf1c6,
      \ 'tgz': 0xf1c6, 'rar': 0xf1c6,
      \ 'lock': 0xf023, 'log': 0xf15c, 'gradle': 0xe70e, 'mk': 0xe673,
      \ 'dockerignore': 0xe7b0,
      \ }

" Filetype glyph for a file name (returns trailing space when present).
" Empty string when nerd icons are disabled.
function! merge_preview#icons#file(name) abort
  if !merge_preview#icons#enabled()
    return ''
  endif
  if has_key(s:name_icons, a:name)
    return nr2char(s:name_icons[a:name], 1) . ' '
  endif
  let l:ext = tolower(fnamemodify(a:name, ':e'))
  if l:ext !=# '' && has_key(s:ext_icons, l:ext)
    return nr2char(s:ext_icons[l:ext], 1) . ' '
  endif
  return nr2char(s:default_icon, 1) . ' '
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
