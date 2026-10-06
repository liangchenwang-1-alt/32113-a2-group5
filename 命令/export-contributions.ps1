# 32113 A2 - build a contribution record from the Git history.
#
# Why: the A2 appendix must contain evidence of "tasks allocated and performed by the
# individuals". If the group works in a Git repo, the history already proves who did
# what - this script turns it into a readable table instead of an opinion.
#
# Usage (from the A2\命令 folder, once the A2 folder is a git repo):
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\export-contributions.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\export-contributions.ps1 -Repo "D:\group\A2"
#
# Output: <repo>\lab-env\advanced-database-lab\workspace\evidence\contributions\contributions_<date>.md
# Read-only with respect to the repo: it runs `git log` and writes one markdown file.

param(
  [string]$Repo = '',
  [string]$OutDir = ''
)

$ErrorActionPreference = 'Continue'
$here = $PSScriptRoot
if (-not $here) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $Repo) { $Repo = Split-Path -Parent $here }        # A2\ is the repo root
if (-not (Test-Path -LiteralPath (Join-Path $Repo '.git'))) {
  Write-Host ("not a git repository: {0}" -f $Repo) -ForegroundColor Red
  Write-Host 'run "git init" in that folder first (see the group sync guide in this folder).'
  exit 1
}
if (-not $OutDir) {
  $OutDir = Join-Path $Repo 'lab-env\advanced-database-lab\workspace\evidence\contributions'
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$out = Join-Path $OutDir ('contributions_' + (Get-Date -Format 'yyyyMMdd') + '.md')

$gitCommon = @('-C', $Repo, '-c', 'core.quotepath=false')

function GitLines([string[]]$gitArgs) {
  $all = @($gitCommon) + $gitArgs
  @(& git @all 2>&1) | ForEach-Object { $_.ToString() }
}

$branch = (GitLines @('rev-parse', '--abbrev-ref', 'HEAD') | Select-Object -First 1)
$totalCommits = (GitLines @('rev-list', '--all', '--count') | Select-Object -First 1)
$firstDate = (GitLines @('log', '--all', '--reverse', '--date=short', '--pretty=format:%ad') | Select-Object -First 1)
$lastDate  = (GitLines @('log', '--all', '--date=short', '--pretty=format:%ad') | Select-Object -First 1)

# ------------------------------------------------------------------ per author
$authors = @{}
$curAuthor = $null
foreach ($line in (GitLines @('log', '--all', '--numstat', '--date=short', '--pretty=format:@@%an|%ae|%ad'))) {
  if ($line -like '@@*') {
    $parts = $line.Substring(2) -split '\|'
    $key = $parts[0] + ' <' + $parts[1] + '>'
    if (-not $authors.ContainsKey($key)) {
      $authors[$key] = [pscustomobject]@{ Name = $key; Commits = 0; Added = 0; Deleted = 0; First = $parts[2]; Last = $parts[2]; Files = @{} }
    }
    $authors[$key].Commits++
    if ($parts[2] -lt $authors[$key].First) { $authors[$key].First = $parts[2] }
    if ($parts[2] -gt $authors[$key].Last)  { $authors[$key].Last  = $parts[2] }
    $curAuthor = $authors[$key]
    continue
  }
  if (-not $curAuthor) { continue }
  if ($line -match '^(\d+|-)\t(\d+|-)\t(.+)$') {
    if ($matches[1] -ne '-') { $curAuthor.Added   += [int]$matches[1] }
    if ($matches[2] -ne '-') { $curAuthor.Deleted += [int]$matches[2] }
    $f = $matches[3].Trim()
    if ($f) { $curAuthor.Files[$f] = 1 + $(if ($curAuthor.Files.ContainsKey($f)) { $curAuthor.Files[$f] } else { 0 }) }
  }
}

# ------------------------------------------------- last editor of every file
$lastEditor = @{}
foreach ($line in (GitLines @('log', '--all', '--name-only', '--date=short', '--pretty=format:@@%an|%ad'))) {
  if ($line -like '@@*') {
    $parts = $line.Substring(2) -split '\|'
    $curName = $parts[0]; $curDate = $parts[1]
    continue
  }
  $f = $line.Trim()
  if ($f -and -not $lastEditor.ContainsKey($f)) {
    $lastEditor[$f] = [pscustomobject]@{ Author = $curName; Date = $curDate }
  }
}

# ---------------------------------------------------------------------- write
$md = New-Object System.Collections.ArrayList
function Add-Line([string]$t) { $md.Add($t) | Out-Null }

Add-Line '# 32113 A2 - contribution record (generated from Git history)'
Add-Line ''
Add-Line ('> generated: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
Add-Line ('> repository: ' + $Repo)
Add-Line ('> branch: ' + $branch + ' | commits: ' + $totalCommits + ' | first: ' + $firstDate + ' | last: ' + $lastDate)
Add-Line ''
Add-Line 'This is mechanical evidence, not a judgement: it counts what was committed under'
Add-Line 'each author name. Work done outside the repo (meetings, testing, talking to the'
Add-Line 'tutor) has to be added by hand in the contribution logbook.'
Add-Line ''
Add-Line '## 1. Commits per member'
Add-Line ''
Add-Line '| Member | Commits | Lines added | Lines deleted | First commit | Last commit | Files touched |'
Add-Line '|---|---|---|---|---|---|---|'
foreach ($a in ($authors.Values | Sort-Object -Property Commits -Descending)) {
  Add-Line ('| {0} | {1} | {2} | {3} | {4} | {5} | {6} |' -f $a.Name, $a.Commits, $a.Added, $a.Deleted, $a.First, $a.Last, $a.Files.Count)
}
Add-Line ''
Add-Line '## 2. Who last touched each file'
Add-Line ''
Add-Line '| File | Last edited by | Date |'
Add-Line '|---|---|---|'
foreach ($k in ($lastEditor.Keys | Sort-Object)) {
  Add-Line ('| {0} | {1} | {2} |' -f $k, $lastEditor[$k].Author, $lastEditor[$k].Date)
}
Add-Line ''
Add-Line '## 3. Files per member'
Add-Line ''
foreach ($a in ($authors.Values | Sort-Object -Property Name)) {
  Add-Line ('### ' + $a.Name)
  Add-Line ''
  foreach ($f in ($a.Files.Keys | Sort-Object)) {
    Add-Line ('- ' + $f + '  (' + $a.Files[$f] + ' commit(s))')
  }
  Add-Line ''
}
Add-Line '## 4. Before pasting this into the appendix'
Add-Line ''
Add-Line '- Check the names match the group members (git uses whatever name/email is configured).'
Add-Line '- Adjust `git config user.name` / `user.email` if someone committed as the wrong person.'
Add-Line '- Add the parts Git cannot see (meetings, rehearsals, asking the tutor) by hand.'

Set-Content -LiteralPath $out -Value ($md -join "`r`n") -Encoding UTF8

Write-Host ('authors found: ' + $authors.Count + ' | commits: ' + $totalCommits)
foreach ($a in ($authors.Values | Sort-Object -Property Commits -Descending)) {
  Write-Host ('  {0,-46} {1} commit(s)' -f $a.Name, $a.Commits)
}
Write-Host ('report written to: ' + $out)
exit 0
