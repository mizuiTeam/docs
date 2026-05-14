$files = Get-ChildItem -Path . -Filter *.mdx -Recurse | Where-Object { $_.FullName -notmatch '\\node_modules\\' }
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$latin1 = [System.Text.Encoding]::GetEncoding(1252)
$fixedEnc = 0
$fixedDash = 0
$failed = @()
foreach ($f in $files) {
  $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
  if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    $bytes = $bytes[3..($bytes.Length-1)]
  }
  $text = [System.Text.Encoding]::UTF8.GetString($bytes)
  $changed = $false
  if ($text -match 'Ã.|Â.') {
    try {
      $rebytes = $latin1.GetBytes($text)
      $candidate = [System.Text.Encoding]::UTF8.GetString($rebytes)
      if ($candidate.IndexOf([char]0xFFFD) -lt 0) {
        $text = $candidate
        $fixedEnc++
        $changed = $true
      } else {
        $failed += $f.FullName
      }
    } catch { $failed += $f.FullName }
  }
  $emdash = [char]0x2014
  $endash = [char]0x2013
  if ($text.IndexOf($emdash) -ge 0 -or $text.IndexOf($endash) -ge 0) {
    $text = [regex]::Replace($text, "\s*$emdash\s*", ', ')
    $text = [regex]::Replace($text, "\s*$endash\s*", '-')
    $fixedDash++
    $changed = $true
  }
  if ($changed) {
    [System.IO.File]::WriteAllText($f.FullName, $text, $utf8NoBom)
  }
}
Write-Host "Encoding corrigido: $fixedEnc"
Write-Host "Arquivos com travessoes removidos: $fixedDash"
if ($failed.Count -gt 0) { Write-Host "FALHOU em:"; $failed | ForEach-Object { Write-Host "  $_" } }
