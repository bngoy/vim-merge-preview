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

" Auto-detect the integration branch to diff HEAD against.
"
" Strategy: find the branch whose tip is the nearest ancestor of HEAD. For
" each candidate branch B, compute the merge-base with HEAD and count the
" commits in `<merge-base>..HEAD`. The actual parent branch (the one HEAD
" was cut from) produces the smallest count — it's the most recent point
" where our history diverged. Ties are broken by name preference
" (main > master > develop > others).
"
" Candidates are local branches plus `origin/HEAD` (resolved to its target)
" and `origin/main` / `origin/master` / `origin/develop`. Remote branches
" beyond those aren't scanned — in large repos that would be hundreds of
" refs and the heuristic doesn't benefit from them. Override with
" `:MergePreview <ref>` or `g:merge_preview_base` when the heuristic misses.
function! mergepreview#git#DetectBase() abort
  let l:head = mergepreview#git#HeadName()
  let l:head_sha = s:HeadSha()

  let l:candidates = s:CandidateBases(l:head)

  let l:scored = []
  for l:name in l:candidates
    let l:mb = mergepreview#git#MergeBase(l:name)
    if empty(l:mb) | continue | endif
    " Skip branches that are downstream of HEAD (their merge-base equals HEAD)
    " — HEAD has nothing to compare against.
    if l:mb ==# l:head_sha | continue | endif
    let l:ahead = s:CommitCount(l:mb . '..HEAD')
    if l:ahead <= 0 | continue | endif
    call add(l:scored, {
          \ 'name': l:name,
          \ 'ahead': l:ahead,
          \ 'priority': s:BranchPriority(l:name),
          \ })
  endfor

  if !empty(l:scored)
    call sort(l:scored, function('s:CompareCandidates'))
    return l:scored[0].name
  endif

  " Fallback: nothing scored (e.g. detached HEAD, or brand-new branch with no
  " new commits). Return the first reachable conventional branch, skipping
  " any whose name matches HEAD's.
  for l:cand in ['origin/main', 'origin/master', 'main', 'master', 'develop']
    if l:cand ==# l:head || l:cand ==# 'origin/' . l:head | continue | endif
    let l:v = s:Run('rev-parse --verify --quiet ' . shellescape(l:cand))
    if l:v.ok
      return l:cand
    endif
  endfor
  return ''
endfunction

function! s:HeadSha() abort
  let l:r = s:Run('rev-parse HEAD')
  return l:r.ok ? get(l:r.lines, 0, '') : ''
endfunction

function! s:CommitCount(range) abort
  let l:r = s:Run('rev-list --count ' . shellescape(a:range))
  if !l:r.ok | return 0 | endif
  return str2nr(get(l:r.lines, 0, '0'))
endfunction

function! s:CandidateBases(head) abort
  let l:names = []

  let l:locals = s:Run('for-each-ref --format=' . shellescape('%(refname:short)')
        \ . ' refs/heads/')
  if l:locals.ok
    for l:n in l:locals.lines
      if !empty(l:n) && l:n !=# a:head
        call add(l:names, l:n)
      endif
    endfor
  endif

  " Resolve origin/HEAD to its target branch, then add common integration
  " branches on the origin remote.
  let l:origin_head = s:Run('symbolic-ref --short --quiet refs/remotes/origin/HEAD')
  if l:origin_head.ok && !empty(l:origin_head.lines)
    let l:n = l:origin_head.lines[0]
    if !empty(l:n) && l:n !=# 'origin/' . a:head
      call add(l:names, l:n)
    endif
  endif
  for l:n in ['origin/main', 'origin/master', 'origin/develop']
    if l:n ==# 'origin/' . a:head | continue | endif
    let l:v = s:Run('rev-parse --verify --quiet ' . shellescape(l:n))
    if l:v.ok
      call add(l:names, l:n)
    endif
  endfor

  let l:seen = {}
  let l:unique = []
  for l:n in l:names
    if !has_key(l:seen, l:n)
      let l:seen[l:n] = 1
      call add(l:unique, l:n)
    endif
  endfor
  return l:unique
endfunction

function! s:BranchPriority(name) abort
  let l:bare = substitute(a:name, '^[^/]\+/', '', '')
  if l:bare ==# 'main'    | return 0 | endif
  if l:bare ==# 'master'  | return 1 | endif
  if l:bare ==# 'develop' | return 2 | endif
  if l:bare ==# 'dev'     | return 3 | endif
  return 10
endfunction

function! s:CompareCandidates(a, b) abort
  if a:a.ahead != a:b.ahead
    return a:a.ahead - a:b.ahead
  endif
  return a:a.priority - a:b.priority
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

" Return the file contents at a given ref as a list of lines. When the file
" doesn't exist at that ref (e.g. added on HEAD, not yet on the base), return
" an empty list.
function! mergepreview#git#FileAtRef(ref, file) abort
  let l:r = s:Run('show ' . shellescape(a:ref . ':' . a:file))
  if !l:r.ok | return [] | endif
  return l:r.lines
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
