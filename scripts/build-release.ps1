param(
    [string]$Rojo = "rojo",
    [string]$Wally = "wally"
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
Push-Location $root
try {
    foreach ($tool in @($Rojo, $Wally)) {
        if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
            throw "Required tool '$tool' was not found. Install Rojo 7.7.0 and Wally 0.3.2, or pass -Rojo and -Wally with executable paths."
        }
    }

    New-Item -ItemType Directory -Force dist | Out-Null
    & $Rojo build default.project.json -o dist/Prefs.rbxm
    if ($LASTEXITCODE -ne 0) { throw "Production model build failed." }
    & $Rojo build default.project.json -o dist/Prefs.rbxmx
    if ($LASTEXITCODE -ne 0) { throw "Production XML model build failed." }

    [xml]$model = Get-Content -Raw dist/Prefs.rbxmx
    $items = @($model.SelectNodes("/roblox/Item/descendant-or-self::Item"))
    $names = @($items | ForEach-Object { $_.SelectSingleNode("Properties/string[@name='Name']").InnerText } | Sort-Object)
    $expectedNames = @("Prefs", "Runtime", "Schema", "Store")
    if (@(Compare-Object $expectedNames $names -CaseSensitive).Count -ne 0 -or @($items | Where-Object class -cne "ModuleScript").Count -ne 0) {
        throw "Production model must contain only Prefs, Runtime, Schema, and Store ModuleScripts."
    }
    if (@($model.SelectNodes("/roblox/Item")).Count -ne 1 -or $model.SelectSingleNode("/roblox/Item/Properties/string[@name='Name']").InnerText -cne "Prefs" -or @($model.SelectNodes("/roblox/Item/Item")).Count -ne 3) {
        throw "Production model must have one top-level Prefs ModuleScript with exactly three direct ModuleScript children."
    }
    foreach ($item in $items) {
        $name = $item.SelectSingleNode("Properties/string[@name='Name']").InnerText
        $sourceNode = $item.SelectSingleNode("Properties/*[@name='Source']")
        $sourcePath = if ($name -eq 'Prefs') { 'src/init.luau' } else { "src/$name.luau" }
        $source = Get-Content -Raw $sourcePath
        if (-not $sourceNode -or $sourceNode.InnerText.Length -eq 0 -or $sourceNode.InnerText -cne $source) {
            throw "Production source differs from $sourcePath."
        }
    }

    $manifestJson = & $Wally manifest-to-json
    if ($LASTEXITCODE -ne 0) { throw "Wally manifest validation failed." }
    $manifest = $manifestJson | ConvertFrom-Json
    if ($manifest.package.name -cne "luaucommons/prefs" -or $manifest.package.realm -cne "shared" -or $manifest.package.version -notmatch '^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$') {
        throw "Expected shared luaucommons/prefs package metadata and a semantic version."
    }
    $archivePath = Join-Path $root "dist/Prefs-$($manifest.package.version).zip"
    & $Wally package --output $archivePath
    if ($LASTEXITCODE -ne 0) { throw "Wally packaging failed." }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($archivePath)
    try {
        $files = @($archive.Entries | Where-Object { $_.Name -ne "" } | ForEach-Object { $_.FullName.Replace('\', '/') } | Sort-Object)
        $expectedFiles = @("default.project.json", "LICENSE", "README.md", "src/init.luau", "src/Runtime.luau", "src/Schema.luau", "src/Store.luau", "wally.toml") | Sort-Object
        if (@(Compare-Object $expectedFiles $files -CaseSensitive).Count -ne 0) {
            throw "Wally archive contains unexpected or missing files: $($files -join ', ')"
        }
        foreach ($entry in $archive.Entries | Where-Object { $_.Name -ne "" }) {
            $stream = $entry.Open()
            $memory = [System.IO.MemoryStream]::new()
            try {
                $stream.CopyTo($memory)
                if ($entry.FullName -ceq 'default.project.json') {
                    # Wally rewrites the project name to the package's final segment.
                    $project = [System.Text.Encoding]::UTF8.GetString($memory.ToArray()) | ConvertFrom-Json
                    $sourceProject = Get-Content -Raw default.project.json | ConvertFrom-Json
                    if ($project.name -cne $manifest.package.name.Split('/')[-1] -or ($project.tree | ConvertTo-Json -Depth 20 -Compress) -cne ($sourceProject.tree | ConvertTo-Json -Depth 20 -Compress) -or @($project.PSObject.Properties).Count -ne 2) {
                        throw 'Wally project metadata differs from the expected package name and production tree.'
                    }
                    continue
                }
                $packaged = [Convert]::ToBase64String($memory.ToArray())
                $localContent = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes((Join-Path $root $entry.FullName)))
                if ($packaged -cne $localContent) { throw "Wally archive content differs from $($entry.FullName)." }
            }
            finally { $memory.Dispose(); $stream.Dispose() }
        }
    }
    finally { $archive.Dispose() }

    Write-Host "PASS: production XML model contains exactly four ModuleScripts; Wally archive contains exactly eight matching release files."
    Get-FileHash dist/Prefs.rbxm, dist/Prefs.rbxmx, $archivePath -Algorithm SHA256 | Format-Table -AutoSize
}
finally { Pop-Location }
