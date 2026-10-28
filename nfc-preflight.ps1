[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
# Read-only inventory. No secrets, device identifiers, uploads or account writes.
$project = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'ios/Runner.xcodeproj/project.pbxproj') -Raw
$plist = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'ios/Runner/Info.plist') -Raw
$tools = @{}
foreach ($toolName in @('flutter', 'node', 'git', 'gh', 'xcodebuild')) {
    $tools[$toolName] = [bool](Get-Command $toolName -ErrorAction SilentlyContinue)
}
[ordered]@{
    milestone = 'G0 - inventory only, not NFC acceptance'
    device = 'iPhone 12 / iOS 26.2 (user-reported; hardware test pending)'
    appleDeveloperProgram = 'BLOCKED: team has no Apple Developer Program / App Store Connect'
    cccdSdkAndTrustPolicy = 'BLOCKED: no SDK, AID, trust anchors or verifier supplied'
    nativeSigning = 'BLOCKED: no signing assets configured or tested'
    iosUsageDescriptionPresent = $plist.Contains('NFCReaderUsageDescription')
    iosTeamConfigured = [bool]($project -match 'DEVELOPMENT_TEAM\s*=\s*[^;\s]+')
    nfcEntitlementsConfigured = [bool]($project -match 'CODE_SIGN_ENTITLEMENTS\s*=')
    unsignedCiPrepared = Test-Path -LiteralPath (Join-Path $PSScriptRoot '.github/workflows/ios-preflight.yml')
    toolAvailability = $tools
    verdict = 'G0 external gates BLOCKED; G1 software readiness can be tested on Windows. No real NFC verification claimed.'
} | ConvertTo-Json -Depth 3
