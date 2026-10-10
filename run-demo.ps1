$ErrorActionPreference = 'Stop'

$coordinatorProcess = $null
$startedCoordinator = $false

try {
    try {
        $health = Invoke-RestMethod -Uri 'http://127.0.0.1:8788/health' -TimeoutSec 1
    }
    catch {
        $health = $null
    }

    if ($health.status -ne 'healthy') {
        $coordinatorProcess = Start-Process `
            -FilePath 'node.exe' `
            -ArgumentList 'src/server.js' `
            -WorkingDirectory (Join-Path $PSScriptRoot 'coordinator') `
            -WindowStyle Hidden `
            -PassThru
        $startedCoordinator = $true

        $ready = $false
        for ($attempt = 0; $attempt -lt 20; $attempt++) {
            try {
                $health = Invoke-RestMethod `
                    -Uri 'http://127.0.0.1:8788/health' `
                    -TimeoutSec 1
                if ($health.status -eq 'healthy') {
                    $ready = $true
                    break
                }
            }
            catch {
                Start-Sleep -Milliseconds 250
            }
        }
        if (-not $ready) {
            throw 'Coordinator could not start at http://localhost:8788.'
        }
    }

    Write-Host 'Coordinator: healthy at http://localhost:8788' -ForegroundColor Green
    & (Join-Path $PSScriptRoot 'run-web.ps1')
}
finally {
    if ($startedCoordinator -and
        $coordinatorProcess -and
        -not $coordinatorProcess.HasExited) {
        Stop-Process -Id $coordinatorProcess.Id
    }
}
