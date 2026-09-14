# Runs the dependency-free Luau suite from any working directory.
param([string]$LuauPath = "luau")

$luauCommand = Get-Command $LuauPath -ErrorAction SilentlyContinue
if (-not $luauCommand) {
    Write-Error "Luau CLI was not found. Install a Windows binary from https://github.com/luau-lang/luau/releases, add luau.exe to PATH (or pass -LuauPath C:\tools\luau.exe), then run tests/run.ps1. No Luau tests were executed."
    exit 127
}
Push-Location (Split-Path -Parent $PSScriptRoot)
try {
    & $luauCommand.Source tests/run.luau
    $testExitCode = $LASTEXITCODE
} finally {
    Pop-Location
}
exit $testExitCode
