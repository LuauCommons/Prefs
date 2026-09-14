param([string]$Rojo = "rojo")

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
Push-Location $root
try {
    if (-not (Get-Command $Rojo -ErrorAction SilentlyContinue)) { throw "Rojo was not found. Install the version in aftman.toml or pass -Rojo with its executable path." }
    foreach ($path in @('dist/Prefs.rbxm', 'dist/Prefs.rbxmx')) {
        if (-not (Test-Path -LiteralPath $path)) { throw 'Run scripts/build-release.ps1 first.' }
    }

    & $Rojo build tests/release/default.project.json -o dist/PrefsReleaseSmoke.rbxlx
    if ($LASTEXITCODE -ne 0) { throw 'Release smoke place build failed.' }
    [xml]$model = Get-Content -Raw dist/Prefs.rbxmx
    [xml]$place = Get-Content -Raw dist/PrefsReleaseSmoke.rbxlx

    function Get-ItemAtPath($document, [string]$path) {
        $parent = $document.DocumentElement
        foreach ($name in $path.Split('/')) {
            $instances = @($parent.SelectNodes('Item') | Where-Object { $_.SelectSingleNode("Properties/string[@name='Name']").InnerText -ceq $name })
            if ($instances.Count -ne 1) { throw "Expected exactly one instance at $path." }
            $parent = $instances[0]
        }
        return $parent
    }

    function Normalize-Source([string]$source) {
        return ($source -replace "`r`n", "`n").TrimEnd("`n")
    }

    $production = Get-ItemAtPath $model 'Prefs'
    $installed = Get-ItemAtPath $place 'ReplicatedStorage/Packages/Prefs'
    foreach ($module in @($production, $installed)) {
        $items = @($module.SelectNodes('descendant-or-self::Item'))
        $names = @($items | ForEach-Object { $_.SelectSingleNode("Properties/string[@name='Name']").InnerText } | Sort-Object)
        if (@(Compare-Object @('Prefs', 'Runtime', 'Schema', 'Store') $names -CaseSensitive).Count -ne 0 -or @($items | Where-Object class -cne 'ModuleScript').Count -ne 0 -or @($module.SelectNodes('Item')).Count -ne 3) {
            throw 'Production and installed models must each contain only Prefs with Runtime, Schema, and Store children.'
        }
    }
    foreach ($name in @('Prefs', 'Runtime', 'Schema', 'Store')) {
        $suffix = if ($name -ceq 'Prefs') { '' } else { "/$name" }
        $expected = Get-ItemAtPath $model "Prefs$suffix"
        $actual = Get-ItemAtPath $place "ReplicatedStorage/Packages/Prefs$suffix"
        $sourcePath = if ($name -ceq 'Prefs') { 'src/init.luau' } else { "src/$name.luau" }
        $source = Get-Content -Raw $sourcePath
        foreach ($item in @($expected, $actual)) {
            $sourceNode = $item.SelectSingleNode("Properties/*[@name='Source']")
            if (-not $sourceNode -or $sourceNode.InnerText.Length -eq 0 -or (Normalize-Source $sourceNode.InnerText) -cne (Normalize-Source $source)) {
                throw "Release artifact or installed source differs from $sourcePath. Rebuild the release artifacts."
            }
        }
    }

    $fixtures = @(
        @{ Path = 'ReplicatedStorage/Packages/Preferences'; Class = 'ModuleScript'; Source = 'examples/Basic/Preferences.luau' },
        @{ Path = 'ServerScriptService/PreferencesServer'; Class = 'Script'; Source = 'examples/Basic/Server.server.luau' },
        @{ Path = 'StarterPlayer/StarterPlayerScripts/PreferencesClient'; Class = 'LocalScript'; Source = 'examples/Basic/Client.client.luau' },
        @{ Path = 'ServerScriptService/Verify'; Class = 'Script'; Source = 'tests/release/Verify.server.luau' },
        @{ Path = 'ServerScriptService/RuntimeSpec'; Class = 'ModuleScript'; Source = 'tests/runtime.spec.luau' },
        @{ Path = 'StarterPlayer/StarterPlayerScripts/Verify'; Class = 'LocalScript'; Source = 'tests/release/Verify.client.luau' }
    )
    foreach ($fixture in $fixtures) {
        $item = Get-ItemAtPath $place $fixture.Path
        if ($item.class -cne $fixture.Class -or (Normalize-Source $item.SelectSingleNode("Properties/*[@name='Source']").InnerText) -cne (Normalize-Source (Get-Content -Raw $fixture.Source))) {
            throw "Smoke fixture differs from $($fixture.Source) at $($fixture.Path)."
        }
    }
    Write-Host 'PASS: smoke place embeds the exact production .rbxm with four matching modules and six matching example/test scripts.'
    Write-Host 'Built dist/PrefsReleaseSmoke.rbxlx. Open it in Roblox Studio and run Play to execute the smoke tests; this build does not run them.'
}
finally { Pop-Location }
