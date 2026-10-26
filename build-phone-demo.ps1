param(
    [string]$NotaryUrl = '',
    [string]$FlutterExecutable = ''
)
$ErrorActionPreference = 'Stop'

if ($NotaryUrl) {
    $notaryUri = $null
    if (-not [Uri]::TryCreate($NotaryUrl, [UriKind]::Absolute, [ref]$notaryUri) -or
        $notaryUri.Scheme -ne 'https' -or $notaryUri.IsLoopback -or
        $notaryUri.UserInfo -or $notaryUri.Query -or $notaryUri.Fragment) {
        throw 'NotaryUrl must be a reachable HTTPS base URL without credentials, query or fragment.'
    }
}
if (-not $FlutterExecutable) {
    $flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
    $FlutterExecutable = if ($flutterCommand) { $flutterCommand.Source } else { 'C:\tmp\civiltrust-flutter-sdk\bin\flutter.bat' }
}
if (-not (Test-Path -LiteralPath $FlutterExecutable)) { throw 'Flutter SDK not found.' }

$notaryEnabled = if ($NotaryUrl) { 'true' } else { 'false' }
$notaryBase = if ($NotaryUrl) { $NotaryUrl } else { 'https://notary.invalid' }
Push-Location $PSScriptRoot
try {
    & $FlutterExecutable build web `
        --dart-define=APP_ENV=staging `
        --dart-define=COORDINATOR_URL=/coordinator `
        "--dart-define=NOTARY_ENABLED=$notaryEnabled" `
        "--dart-define=NOTARY_URL=$notaryBase"
    if ($LASTEXITCODE -ne 0) { throw 'Flutter Web build failed.' }
    @{
        profile = 'phone-staging-v1'
        mainSha256 = (Get-FileHash -LiteralPath (Join-Path $PSScriptRoot 'build/web/main.dart.js') -Algorithm SHA256).Hash
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'build/phone-demo.json') -Encoding UTF8
    Write-Host 'Phone demo build ready. Identity/signatures are mock; notary enabled:' $notaryEnabled
}
finally { Pop-Location }
