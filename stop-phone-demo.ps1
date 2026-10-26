$ErrorActionPreference = 'Stop'
$statePath = Join-Path $PSScriptRoot '.demo/state.json'
if (-not (Test-Path -LiteralPath $statePath)) { Write-Host 'No phone demo state.'; return }
$state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
foreach ($entry in $state.processes) {
    $process = Get-Process -Id $entry.id -ErrorAction SilentlyContinue
    # A recycled PID must never stop an unrelated user process.
    if ($process -and $process.ProcessName -eq $entry.name -and
        $process.StartTime.ToUniversalTime().Ticks -eq [long]$entry.startedUtcTicks) {
        Stop-Process -Id $process.Id
    }
}
Remove-Item -LiteralPath $statePath
Write-Host 'Demo processes stopped when their recorded PID/start time matched. HTTPS URL is no longer valid.'
