# SessionStart hook for superpowers plugin - PowerShell version

# Equivalent of set -euo pipefail
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

try {
    # Determine plugin root directory
    $SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
    $PLUGIN_ROOT = Join-Path $SCRIPT_DIR '..'
    $PLUGIN_ROOT = (Resolve-Path $PLUGIN_ROOT).Path

    # Check if legacy skills directory exists and build warning
    $warning_message = ""
    $legacy_skills_dir = Join-Path $env:USERPROFILE '.config\superpowers\skills'
    if (Test-Path $legacy_skills_dir) {
        $warning_message = "`n`n<important-reminder>IN YOUR FIRST REPLY AFTER SEEING THIS MESSAGE YOU MUST TELL THE USER:⚠️ **WARNING:** Superpowers now uses Claude Code's skills system. Custom skills in ~/.config/superpowers/skills will not be read. Move custom skills to ~/.claude/skills instead. To make this message go away, remove ~/.config/superpowers/skills</important-reminder>"
    }

    # Read using-superpowers content
    $using_superpowers_path = Join-Path $PLUGIN_ROOT 'skills\using-superpowers\SKILL.md'
    if (Test-Path $using_superpowers_path) {
        $using_superpowers_content = Get-Content -Path $using_superpowers_path -Raw
    } else {
        $using_superpowers_content = "Error reading using-superpowers skill"
    }

    # Escape strings for JSON (escape backslashes and quotes)
    $EscapeForJson = {
        param([string]$input)
        $input = $input -replace '\\', '\\'
        $input = $input -replace '"', '\"'
        # Replace newlines with \n and ensure proper line continuation
        $lines = $input -split "`r?`n"
        return ($lines -join "\n")
    }

    $using_superpowers_escaped = & $EscapeForJson $using_superpowers_content
    $warning_escaped = & $EscapeForJson $warning_message

    # Output context injection as JSON
    $jsonOutput = @"
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "<EXTREMELY_IMPORTANT>\nYou have superpowers.\n\n**The content below is from skills/using-superpowers/SKILL.md - your introduction to using skills:**\n\n$using_superpowers_escaped\n\n$warning_escaped\n</EXTREMELY_IMPORTANT>"
  }
}
"@

    Write-Output $jsonOutput
}
catch {
    # In case of error, output minimal valid JSON to avoid breaking the system
    Write-Output '{ "hookSpecificOutput": { "hookEventName": "SessionStart", "additionalContext": "" } }'
    exit 1
}

exit 0
