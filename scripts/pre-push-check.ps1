# scripts/pre-push-check.ps1
# Verificação de higiene ANTES de qualquer push: garante que nenhum conteúdo
# proprietário/decompilado está rastreado pelo git. Uso:
#   powershell -File scripts\pre-push-check.ps1
$ErrorActionPreference = "Stop"
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  $candidates = @("C:\Program Files\Git\cmd", "C:\Program Files\Git\bin")
  foreach ($c in $candidates) { if (Test-Path (Join-Path $c "git.exe")) { $env:Path += ";$c"; break } }
}
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root

$tracked = & git ls-files
$violations = $tracked | Where-Object {
  $_ -match '(^|/)(sources|work|diffs|workspace)(/|$)' -or
  $_ -match '\.(jar|class)$' -or
  $_ -match '(^|/)eula\.txt$' -or
  $_ -match 'net[/\\]minecraft[/\\].*\.java$' -or
  $_ -match 'com[/\\]mojang[/\\].*\.java$' -or
  $_ -match '(^|/)\.minecraft/' -or
  $_ -match '(^|/)assets/'
}

if ($violations) {
  "ERRO: arquivos proibidos rastreados pelo git:" | Write-Host -ForegroundColor Red
  $violations | ForEach-Object { "  $_" | Write-Host -ForegroundColor Red }
  Pop-Location
  exit 1
}

"OK: nenhum arquivo proibido rastreado ($($tracked.Count) arquivos no índice)." | Write-Host -ForegroundColor Green
Pop-Location
exit 0
