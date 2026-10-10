$ErrorActionPreference = 'Stop'

$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
$flutterExecutable = if ($flutterCommand) {
    $flutterCommand.Source
} else {
    'C:\tmp\civiltrust-flutter-sdk\bin\flutter.bat'
}

if (-not (Test-Path -LiteralPath $flutterExecutable)) {
    throw 'Flutter SDK was not found. Install Flutter or add flutter\bin to PATH.'
}

Push-Location $PSScriptRoot
try {
    & $flutterExecutable pub get
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    & $flutterExecutable run -d chrome `
        --dart-define=COORDINATOR_URL=http://localhost:8788 `
        --dart-define=NOTARY_URL=http://localhost:8787
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
