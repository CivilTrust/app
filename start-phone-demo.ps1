param(
    [ValidateRange(1024,65535)][int]$Port = 8790,
    [switch]$SkipBuild,
    [string]$NotaryUrl = ''
)
$ErrorActionPreference = 'Stop'
if ($SkipBuild -and $NotaryUrl) { throw 'NotaryUrl changes require rebuilding; do not combine with SkipBuild.' }

$runtimeDir = Join-Path $PSScriptRoot '.demo'
$statePath = Join-Path $runtimeDir 'state.json'
if (Test-Path -LiteralPath $statePath) {
    throw 'Demo state already exists. Run ./stop-phone-demo.ps1 before starting another demo.'
}
if (-not $SkipBuild) { & (Join-Path $PSScriptRoot 'build-phone-demo.ps1') -NotaryUrl $NotaryUrl }
if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'build/web/index.html'))) {
    throw 'Build Web first with ./build-phone-demo.ps1.'
}
$buildStatePath = Join-Path $PSScriptRoot 'build/phone-demo.json'
if (-not (Test-Path -LiteralPath $buildStatePath)) { throw 'Missing phone build marker. Run ./build-phone-demo.ps1 first.' }
$buildState = Get-Content -LiteralPath $buildStatePath -Raw | ConvertFrom-Json
$mainHash = (Get-FileHash -LiteralPath (Join-Path $PSScriptRoot 'build/web/main.dart.js') -Algorithm SHA256).Hash
if ($buildState.profile -ne 'phone-staging-v1' -or $buildState.mainSha256 -ne $mainHash) {
    throw 'Web build changed or is not a phone staging build. Rebuild with ./build-phone-demo.ps1.'
}
$cloudflared = Get-Command cloudflared -ErrorAction Stop
$node = Get-Command node -ErrorAction Stop
New-Item -ItemType Directory -Path $runtimeDir -Force | Out-Null
$stamp = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss-fff')
$tunnelOut = Join-Path $runtimeDir "tunnel-$stamp.stdout.log"
$tunnelErr = Join-Path $runtimeDir "tunnel-$stamp.stderr.log"
$tunnelProcess = $null
$serverProcess = $null
$previousOrigins = $env:ALLOWED_ORIGINS
$previousEnvironment = $env:APP_ENV
$previousPort = $env:PORT
try {
    # Fail before publishing if another application already owns the port.
    $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, $Port)
    try { $listener.Start() } finally { $listener.Stop() }
    $tunnelProcess = Start-Process -FilePath $cloudflared.Source `
        -ArgumentList 'tunnel','--no-autoupdate','--protocol','http2','--url',"http://127.0.0.1:$Port" `
        -WindowStyle Hidden -PassThru -RedirectStandardOutput $tunnelOut -RedirectStandardError $tunnelErr
    $publicUrl = $null
    for ($attempt = 0; $attempt -lt 60; $attempt++) {
        if ($tunnelProcess.HasExited) { throw "Tunnel exited. Inspect $tunnelErr" }
        $log = (Get-Content -LiteralPath $tunnelErr -Raw -ErrorAction SilentlyContinue) +
            (Get-Content -LiteralPath $tunnelOut -Raw -ErrorAction SilentlyContinue)
        if ($log -match 'https://[a-z0-9-]+\.trycloudflare\.com') { $publicUrl = $Matches[0]; break }
        Start-Sleep -Milliseconds 500
    }
    if (-not $publicUrl) { throw "Tunnel did not provide a URL. Inspect $tunnelErr" }
    $env:ALLOWED_ORIGINS = $publicUrl
    $env:APP_ENV = 'staging'
    $env:PORT = $Port.ToString()
    $serverProcess = Start-Process -FilePath $node.Source -ArgumentList 'coordinator/src/demo-server.js' `
        -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput (Join-Path $runtimeDir "server-$stamp.stdout.log") `
        -RedirectStandardError (Join-Path $runtimeDir "server-$stamp.stderr.log")
    $ready = $false
    for ($attempt = 0; $attempt -lt 20; $attempt++) {
        if ($serverProcess.HasExited) { throw 'Demo server exited. Inspect .demo server logs.' }
        try {
            $health = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/coordinator/health" -TimeoutSec 2
            if ($health.status -eq 'healthy') { $ready = $true; break }
        } catch { Start-Sleep -Milliseconds 250 }
    }
    if (-not $ready) { throw 'Local demo health check failed.' }
    $state = @{
        url = $publicUrl
        port = $Port
        processes = @($serverProcess, $tunnelProcess) | ForEach-Object {
            @{ id = $_.Id; name = $_.ProcessName; startedUtcTicks = $_.StartTime.ToUniversalTime().Ticks }
        }
    }
    $state | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $statePath -Encoding UTF8
    Write-Host "Demo HTTPS: $publicUrl" -ForegroundColor Green
    Write-Host 'Mock data only. Keep Windows awake. URL changes after restart; coordinator sessions are in memory.'
    Write-Host 'On Windows and iPhone: open Thong tin, then Kiem tra ket noi. Stop with ./stop-phone-demo.ps1.'
} catch {
    foreach ($process in @($serverProcess, $tunnelProcess)) {
        if ($process -and -not $process.HasExited) { Stop-Process -Id $process.Id }
    }
    throw
} finally {
    $env:ALLOWED_ORIGINS = $previousOrigins
    $env:APP_ENV = $previousEnvironment
    $env:PORT = $previousPort
}
