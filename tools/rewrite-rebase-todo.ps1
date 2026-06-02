param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$TodoPath
)

$content = Get-Content -LiteralPath $TodoPath -Raw

$content = $content `
  -replace '(?m)^pick 0d1decfe\b', 'edit 0d1decfe' `
  -replace '(?m)^pick 4aec3741\b', 'drop 4aec3741'

Set-Content -LiteralPath $TodoPath -Value $content -NoNewline

