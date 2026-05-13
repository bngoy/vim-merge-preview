" merge_preview#git: all git command wrappers

let s:repo_root = ''

" Re-detect the git toplevel for the current working directory.
" Returns 1 on success, 0 otherwise. Caches the result in s:repo_root.
function! merge_preview#git#set_repo_root() abort
  let l:out = systemlist('git rev-parse --show-toplevel')
  if v:shell_error != 0 || empty(l:out)
    let s:repo_root = ''
    return 0
  endif
  let s:repo_root = l:out[0]
  return 1
endfunction

function! merge_preview#git#repo_root() abort
  return s:repo_root
endfunction

" Run `git -C <root> <args>` and return {ok, lines, raw}.
function! s:git(args) abort
  if empty(s:repo_root)
    return {'ok': 0, 'lines': [], 'raw': ''}
  endif
  let l:null = has('win32') ? 'NUL' : '/dev/null'
  let l:cmd = 'git -C ' . shellescape(s:repo_root) . ' ' . a:args . ' 2>' . l:null
  let l:lines = systemlist(l:cmd)
  return {'ok': v:shell_error == 0, 'lines': l:lines, 'raw': join(l:lines, "\n")}
endfunction

function! merge_preview#git#current_branch() abort
  let l:r = s:git('rev-parse --abbrev-ref HEAD')
  if !l:r.ok || empty(l:r.lines)
    return ''
  endif
  return l:r.lines[0]
endfunction

function! merge_preview#git#verify_ref(ref) abort
  if empty(a:ref)
    return 0
  endif
  let l:r = s:git('rev-parse --verify --quiet ' . shellescape(a:ref))
  return l:r.ok
endfunction

" Resolve the base branch using the documented fallback chain.
" Returns the branch name on success, '' on failure.
function! merge_preview#git#detect_base(override) abort
  let l:current = merge_preview#git#current_branch()

  " 1. explicit :MergePreview <branch> override
  if !empty(a:override)
    if merge_preview#git#verify_ref(a:override)
      return a:override
    endif
    call merge_preview#util#error('base branch ' . a:override . ' does not exist')
    return ''
  endif

  " 2. g:merge_preview_base_branch
  if !empty(g:merge_preview_base_branch)
        \ && merge_preview#git#verify_ref(g:merge_preview_base_branch)
        \ && g:merge_preview_base_branch !=# l:current
    return g:merge_preview_base_branch
  endif

  " 3. upstream
  let l:r = s:git('rev-parse --abbrev-ref --symbolic-full-name @{u}')
  if l:r.ok && !empty(l:r.lines) && l:r.lines[0] !=# '@{u}' && l:r.lines[0] !=# l:current
    return l:r.lines[0]
  endif

  " 4. reflog: oldest entry first usually carries the creation point
  if l:current !=# 'HEAD' && !empty(l:current)
    let l:reflog = s:git('reflog show ' . shellescape(l:current))
    if l:reflog.ok
      for l:line in reverse(copy(l:reflog.lines))
        let l:m = matchlist(l:line,
              \ '\v^[0-9a-f]+\s+\S+:\s+(branch:\s+Created from|checkout:\s+moving from)\s+(\S+)')
        if !empty(l:m)
          let l:cand = l:m[2]
          " 'HEAD' as a reflog source is unhelpful (it just means the user
          " checked out by SHA or the source branch wasn't recorded). Skip
          " it and let later steps try the fallback list.
          if l:cand !=# 'HEAD' && l:cand !=# l:current
                \ && merge_preview#git#verify_ref(l:cand)
            return l:cand
          endif
        endif
      endfor
    endif
  endif

  " 5. fallback list
  for l:cand in g:merge_preview_default_bases
    if l:cand !=# l:current && merge_preview#git#verify_ref(l:cand)
      return l:cand
    endif
  endfor

  return ''
endfunction

function! merge_preview#git#merge_base(base) abort
  let l:r = s:git('merge-base ' . shellescape(a:base) . ' HEAD')
  if !l:r.ok || empty(l:r.lines)
    return ''
  endif
  return l:r.lines[0]
endfunction

" Tokens from `git diff -z --name-status` come NUL-separated. systemlist()
" translates NULs to NLs *within* each line entry but does NOT re-split on
" the resulting NLs, so the whole stream often arrives as a single string.
" Join and split on NL to recover one element per token; drop the trailing
" empty entry produced by the final terminator.
function! s:parse_z_tokens(lines) abort
  let l:joined = join(a:lines, "\n")
  let l:toks = split(l:joined, "\n", 1)
  while !empty(l:toks) && l:toks[-1] ==# ''
    call remove(l:toks, -1)
  endwhile
  return l:toks
endfunction

" Promote the file status using rough precedence so multi-source entries
" (e.g. committed + unstaged) end up with the most informative letter.
function! s:status_rank(s) abort
  let l:order = {'D': 5, 'A': 4, 'R': 3, 'C': 3, 'T': 2, 'M': 1, 'U': 4}
  return get(l:order, a:s, 0)
endfunction

" Merge one `git diff -z` invocation into an accumulator dict keyed by
" final path. Each value is {status, oldpath, sources}.
function! s:collect_diff(acc, args, source) abort
  let l:r = s:git('diff -z --name-status -M ' . a:args)
  if !l:r.ok
    return
  endif
  let l:toks = s:parse_z_tokens(l:r.lines)
  let l:i = 0
  while l:i < len(l:toks)
    let l:status = l:toks[l:i]
    if l:status =~# '^[RC]'
      if l:i + 2 >= len(l:toks)
        break
      endif
      let l:old = l:toks[l:i + 1]
      let l:new = l:toks[l:i + 2]
      let l:i += 3
      let l:entry = get(a:acc, l:new, {'status': '', 'oldpath': '', 'sources': {}})
      if s:status_rank(l:status[0]) >= s:status_rank(l:entry.status)
        let l:entry.status = l:status[0]
        let l:entry.oldpath = l:old
      endif
      let l:entry.sources[a:source] = 1
      let a:acc[l:new] = l:entry
    else
      if l:i + 1 >= len(l:toks)
        break
      endif
      let l:path = l:toks[l:i + 1]
      let l:i += 2
      if empty(l:path)
        continue
      endif
      let l:entry = get(a:acc, l:path, {'status': '', 'oldpath': '', 'sources': {}})
      if s:status_rank(l:status[0]) >= s:status_rank(l:entry.status)
        let l:entry.status = l:status[0]
      endif
      let l:entry.sources[a:source] = 1
      let a:acc[l:path] = l:entry
    endif
  endwhile
endfunction

" Return a list of {path, status, oldpath, sources} for every changed file.
" Combines branch commits, staged, unstaged, and untracked.
function! merge_preview#git#changed_files(merge_base) abort
  let l:acc = {}
  if !empty(a:merge_base)
    call s:collect_diff(l:acc, shellescape(a:merge_base) . '..HEAD', 'c')
  endif
  call s:collect_diff(l:acc, '--cached', 's')
  call s:collect_diff(l:acc, '', 'u')
  call s:collect_untracked(l:acc)

  let l:files = []
  for l:path in sort(keys(l:acc))
    let l:entry = l:acc[l:path]
    call add(l:files, {
          \ 'path': l:path,
          \ 'status': l:entry.status,
          \ 'oldpath': l:entry.oldpath,
          \ 'sources': l:entry.sources,
          \ })
  endfor
  return l:files
endfunction

" Untracked files don't appear in `git diff`. Pull them via ls-files and
" treat each as an addition.
function! s:collect_untracked(acc) abort
  let l:r = s:git('ls-files -z --others --exclude-standard')
  if !l:r.ok
    return
  endif
  for l:path in s:parse_z_tokens(l:r.lines)
    if empty(l:path)
      continue
    endif
    let l:entry = get(a:acc, l:path, {'status': '', 'oldpath': '', 'sources': {}})
    if s:status_rank('A') >= s:status_rank(l:entry.status)
      let l:entry.status = 'A'
    endif
    let l:entry.sources['u'] = 1
    let a:acc[l:path] = l:entry
  endfor
endfunction

" Commits on the current branch that touched the given path (and its old
" name if it was renamed). Returns a list of {sha, subject}.
function! merge_preview#git#commits_for_file(merge_base, path, oldpath) abort
  if empty(a:merge_base)
    return []
  endif
  let l:pathspec = shellescape(a:path)
  if !empty(a:oldpath) && a:oldpath !=# a:path
    let l:pathspec .= ' ' . shellescape(a:oldpath)
  endif
  let l:r = s:git('log --no-color --pretty=format:''%h %s'' '
        \ . shellescape(a:merge_base) . '..HEAD -- ' . l:pathspec)
  if !l:r.ok
    return []
  endif
  let l:commits = []
  for l:line in l:r.lines
    if empty(l:line)
      continue
    endif
    let l:sp = stridx(l:line, ' ')
    if l:sp < 0
      call add(l:commits, {'sha': l:line, 'subject': ''})
    else
      call add(l:commits, {'sha': l:line[: l:sp - 1], 'subject': l:line[l:sp + 1 :]})
    endif
  endfor
  return l:commits
endfunction

" Return {ok, lines} for `git show <rev>:<path>`.
function! merge_preview#git#show_blob(rev, path) abort
  let l:r = s:git('show ' . shellescape(a:rev . ':' . a:path))
  return {'ok': l:r.ok, 'lines': l:r.lines}
endfunction

" Detect binary via numstat: binary entries are reported as `-\t-\t<path>`.
function! merge_preview#git#is_binary(rev_a, rev_b, path) abort
  let l:range = shellescape(a:rev_a)
  if !empty(a:rev_b)
    let l:range .= ' ' . shellescape(a:rev_b)
  endif
  let l:r = s:git('diff --numstat ' . l:range . ' -- ' . shellescape(a:path))
  if !l:r.ok || empty(l:r.lines)
    return 0
  endif
  return l:r.lines[0] =~# '^-\t-\t'
endfunction

function! merge_preview#git#commit_parents(sha) abort
  let l:r = s:git('rev-list --parents -n 1 ' . shellescape(a:sha))
  if !l:r.ok || empty(l:r.lines)
    return []
  endif
  let l:parts = split(l:r.lines[0])
  return l:parts[1:]
endfunction

" If the given commit renamed (or copied) <newpath>, return the old path
" recorded in that commit; otherwise return <newpath>.
function! merge_preview#git#rename_at_commit(sha, newpath) abort
  let l:r = s:git('show --name-status -M --pretty=format: ' . shellescape(a:sha))
  if !l:r.ok
    return a:newpath
  endif
  for l:line in l:r.lines
    if empty(l:line)
      continue
    endif
    let l:parts = split(l:line, '\t')
    if len(l:parts) >= 3 && l:parts[0] =~# '^[RC]' && l:parts[2] ==# a:newpath
      return l:parts[1]
    endif
  endfor
  return a:newpath
endfunction

function! merge_preview#git#branch_complete(arglead) abort
  if !merge_preview#git#set_repo_root()
    return []
  endif
  let l:r = s:git('branch --all --format=''%(refname:short)''')
  if !l:r.ok
    return []
  endif
  let l:lead = a:arglead
  return filter(copy(l:r.lines), 'stridx(v:val, l:lead) == 0')
endfunction

function! merge_preview#git#is_submodule(path) abort
  let l:r = s:git('submodule status -- ' . shellescape(a:path))
  return l:r.ok && !empty(l:r.lines)
endfunction
