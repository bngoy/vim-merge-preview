" Render the preview panel for $MP_REPO against $MP_TARGET and write the lines
" to $MP_OUT. Exercises git parsing + tree build + render without any UI.
let s:root = merge_preview#git#root($MP_REPO)
let s:base = merge_preview#git#merge_base(s:root, $MP_TARGET)
if s:base ==# ''
  let s:base = $MP_TARGET
endif
let s:files = merge_preview#git#changed_files(s:root, s:base)
let s:counts = {'add': 0, 'mod': 0, 'del': 0}
for s:f in s:files
  if s:f.status ==# 'A'
    let s:counts.add += 1
  elseif s:f.status ==# 'D'
    let s:counts.del += 1
  else
    let s:counts.mod += 1
  endif
endfor
let s:state = {
      \ 'root': s:root,
      \ 'target': $MP_TARGET,
      \ 'base': s:base,
      \ 'base_short': merge_preview#git#short(s:root, s:base),
      \ 'branch': merge_preview#git#current_branch(s:root),
      \ 'tree': merge_preview#tree#build(s:files),
      \ 'files': s:files,
      \ 'counts': s:counts,
      \ }
let [s:lines, s:map] = merge_preview#tree#render(s:state)
call writefile(s:lines, $MP_OUT)
