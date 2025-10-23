#!/usr/bin/env pwsh
# Bisection script to find which test creates unwanted files/state
# Usage: .\find-polluter.ps1 <file_or_dir_to_check> <test_pattern>
# Example: .\find-polluter.ps1 '.git' 'src/**/*.test.ts'

# Enable strict mode and stop on errors
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Check arguments
if ($args.Count -ne 2) {
    Write-Host "Usage: $($MyInvocation.MyCommand.Name) <file_to_check> <test_pattern>" -ForegroundColor Red
    Write-Host "Example: $($MyInvocation.MyCommand.Name) '.git' 'src/**/*.test.ts'" -ForegroundColor Yellow
    exit 1
}

$POLLUTION_CHECK = $args[0]
$TEST_PATTERN = $args[1]

Write-Host "Searching for test that creates: $POLLUTION_CHECK" -ForegroundColor Cyan
Write-Host "Test pattern: $TEST_PATTERN" -ForegroundColor Cyan
Write-Host ""

# Get list of test files using .NET-style glob (PowerShell doesn't support ** natively, so resolve manually)
function Get-TestFiles {
    param([string]$Pattern)

    # Split pattern into base path and glob
    $parts = $Pattern -split '/'
    $root = $parts[0]
    $glob = ($parts[1..$parts.Length] -join '/')

    if ($root -eq '.') { $root = '' }

    # Use Get-ChildItem with recursion and filter
    $files = Get-ChildItem -Path . -Recurse -File -Filter '*.test.ts' -ErrorAction SilentlyContinue
    if ($glob) {
        $regex = '^' + [regex]::Escape($root) + $glob.Replace('**', '.*').Replace('*', '[^/]*') + '$'
        $files = $files | Where-Object { $_.FullName -replace '\\', '/' -match $regex }
    }
    return $files | Sort-Object FullName
}

# Simple glob to regex conversion for ** and *
function Convert-GlobToRegex {
    param([string]$Pattern)
    $escaped = [regex]::Escape($Pattern)
    $escaped = $escaped -replace '\*\*', '.*' -replace '\*', '[^/]*'
    return "^$escaped$"
}

# Use .NET Directory to find files matching pattern (handles **)
$testFiles = @()
$patternRegex = Convert-GlobToRegex $TEST_PATTERN

Get-ChildItem -Recurse -File | ForEach-Object {
    $relativePath = $_.FullName.Substring((Get-Location).Path.Length + 1) -replace '\\', '/'
    if ($relativePath -match $patternRegex) {
        $testFiles += $_
    }
}

$testFiles = $testFiles | Sort-Object FullName
$TOTAL = $testFiles.Count

Write-Host "Found $TOTAL test files" -ForegroundColor Green
Write-Host ""

$COUNT = 0
foreach ($testFile in $testFiles) {
    $COUNT++
    $relativePath = $testFile.FullName.Substring((Get-Location).Path.Length + 1)

    # Skip if pollution already exists
    if (Test-Path $POLLUTION_CHECK) {
        Write-Host "Pollution already exists before test $COUNT/$TOTAL" -ForegroundColor Yellow
        Write-Host "   Skipping: $relativePath" -ForegroundColor Gray
        continue
    }

    Write-Host "[$COUNT/$TOTAL] Testing: $relativePath" -ForegroundColor White

    # Run the test silently
    $null = npm test $testFile.FullName 2>$null

    # Check if pollution appeared
    if (Test-Path $POLLUTION_CHECK) {
        Write-Host ""
        Write-Host "FOUND POLLUTER!" -ForegroundColor Red -BackgroundColor Yellow
        Write-Host "   Test: $relativePath" -ForegroundColor Red
        Write-Host "   Created: $POLLUTION_CHECK" -ForegroundColor Red
        Write-Host ""
        Write-Host "Pollution details:" -ForegroundColor Cyan
        Get-Item $POLLUTION_CHECK | Format-List -Property *
        if ((Get-Item $POLLUTION_CHECK) -is [System.IO.DirectoryInfo]) {
            Get-ChildItem $POLLUTION_CHECK -Force | Format-Table Name, Length, LastWriteTime
        }
        Write-Host ""
        Write-Host "To investigate:" -ForegroundColor Magenta
        Write-Host "  npm test `"$($testFile.FullName)`"" -ForegroundColor Gray
        Write-Host "  code `"$($testFile.FullName)`"" -ForegroundColor Gray
        exit 1
    }
}

Write-Host ""
Write-Host "No polluter found - all tests clean!" -ForegroundColor Green
exit 0