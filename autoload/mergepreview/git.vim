" autoload/mergepreview/git.vim - thin git wrappers for mergepreview.vim

function! s:Run(args) abort
  let l:out = systemlist('git ' . a:args)
  if v:shell_error != 0
    return {'ok': 0, 'lines': l:out, 'code': v:shell_error}
  endif
  return {'ok': 1, 'lines': l:out, 'code': 0}
endfunction

function! mergepreview#git#InRepo() abort
  let l:r = s:Run('rev-parse --is-inside-work-tree')
  return l:r.ok && get(l:r.lines, 0, '') ==# 'true'
endfunction

function! mergepreview#git#DetectBase() abort
  let l:up = s:Run('rev-parse --abbrev-ref --symbolic-full-name @{upstream}')
  if l:up.ok && !empty(l:up.lines)
    let l:name = l:up.lines[0]
    " strip remote prefix (origin/main -> main) for display; use full ref for merge-base
    return l:name
  endif
  for l:cand in ['main', 'master', 'develop']
    let l:v = s:Run('rev-parse --verify --quiet ' . shellescape(l:cand))
    if l:v.ok
      return l:cand
    endif
  endfor
  return ''
endfunction

function! mergepreview#git#MergeBase(base) abort
  let l:r = s:Run('merge-base HEAD ' . shellescape(a:base))
  if !l:r.ok || empty(l:r.lines)
    return ''
  endif
  return l:r.lines[0]
endfunction

function! mergepreview#git#HeadName() abort
  let l:r = s:Run('rev-parse --abbrev-ref HEAD')
  return l:r.ok ? get(l:r.lines, 0, '') : ''
endfunction

function! mergepreview#git#ChangedFiles(merge_base) abort
  let l:r = s:Run('diff --name-status ' . shellescape(a:merge_base) . '...HEAD')
  if !l:r.ok
    return []
  endif
  let l:files = []
  for l:line in l:r.lines
    if empty(l:line)
      continue
    endif
    let l:parts = split(l:line, "\t")
    if len(l:parts) < 2
      continue
    endif
    " rename entries are "Rnnn\told\tnew"; prefer the new path
    let l:status = l:parts[0][0]
    let l:path = l:parts[-1]
    call add(l:files, {'status': l:status, 'path': l:path})
  endfor
  return l:files
endfunction

function! mergepreview#git#CommitShasInRange(merge_base) abort
  let l:r = s:Run('log --format=%H ' . shellescape(a:merge_base) . '..HEAD')
  if !l:r.ok
    return {}
  endif
  let l:set = {}
  for l:sha in l:r.lines
    if !empty(l:sha)
      let l:set[l:sha] = 1
      let l:set[l:sha[0:6]] = 1
    endif
  endfor
  return l:set
endfunction

function! mergepreview#git#CommitsForFile(merge_base, file) abort
  " Use a rare delimiter to separate commits.
  let l:sep = '__MP_COMMIT_BOUNDARY__'
  let l:fmt = '--format=' . l:sep . '%n%h%n%s%n%b'
  let l:cmd = 'log ' . l:fmt . ' '
        \ . shellescape(a:merge_base) . '..HEAD -- ' . shellescape(a:file)
  let l:r = s:Run(l:cmd)
  if !l:r.ok
    return []
  endif
  let l:commits = []
  let l:cur = {}
  let l:state = 'sep'
  for l:line in l:r.lines
    if l:line ==# l:sep
      if !empty(l:cur)
        call add(l:commits, l:cur)
      endif
      let l:cur = {'sha': '', 'subject': '', 'body': []}
      let l:state = 'sha'
    elseif l:state ==# 'sha'
      let l:cur.sha = l:line
      let l:state = 'subject'
    elseif l:state ==# 'subject'
      let l:cur.subject = l:line
      let l:state = 'body'
    else
      call add(l:cur.body, l:line)
    endif
  endfor
  if !empty(l:cur)
    call add(l:commits, l:cur)
  endif
  " trim trailing blank body lines per commit
  for l:c in l:commits
    while !empty(l:c.body) && l:c.body[-1] =~# '^\s*$'
      call remove(l:c.body, -1)
    endwhile
  endfor
  return l:commits
endfunction

function! mergepreview#git#HunksFor(merge_base, file) abort
  let l:cmd = 'diff --unified=0 ' . shellescape(a:merge_base) . '...HEAD -- '
        \ . shellescape(a:file)
  let l:r = s:Run(l:cmd)
  if !l:r.ok
    return []
  endif
  let l:hunks = []
  for l:line in l:r.lines
    let l:m = matchlist(l:line, '^@@ -\d\+\%(,\d\+\)\? +\(\d\+\)\%(,\(\d\+\)\)\? @@')
    if empty(l:m)
      continue
    endif
    let l:start = str2nr(l:m[1])
    let l:len = empty(l:m[2]) ? 1 : str2nr(l:m[2])
    " A hunk of length 0 means pure deletion; anchor it at the given line.
    if l:len == 0
      let l:end = l:start
    else
      let l:end = l:start + l:len - 1
    endif
    call add(l:hunks, {'start': l:start, 'end': l:end})
  endfor
  return l:hunks
endfunction

function! mergepreview#git#BlameShaForLine(file, line) abort
  let l:cmd = 'blame --porcelain -L ' . a:line . ',' . a:line
        \ . ' HEAD -- ' . shellescape(a:file)
  let l:r = s:Run(l:cmd)
  if !l:r.ok || empty(l:r.lines)
    return ''
  endif
  let l:header = l:r.lines[0]
  return matchstr(l:header, '^\x\{7,40}')
endfunction
