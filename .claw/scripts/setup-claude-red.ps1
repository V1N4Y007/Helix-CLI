<#
.SYNOPSIS
    Setup Claude-Red skills for HELIX CLI (claw) skill resolver.
.DESCRIPTION
    Creates flat directory junctions under .claw/skills/ that point to
    Claude-Red's nested Skills/<category>/<skill-name>/ directories.
    This allows claw's built-in Skill tool to resolve Claude-Red skills
    by name (e.g. Skill { skill: "offensive-sqli" }).
.PARAMETER ClaudeRedPath
    Path to the cloned Claude-Red repository. Default: .claw/claude-red
.PARAMETER SkillsPath
    Path to the claw skills directory. Default: .claw/skills
.PARAMETER Category
    Optional: install only a specific category (web, auth, recon, utility, etc.)
.PARAMETER DryRun
    Show what would be linked without making changes.
.EXAMPLE
    .\setup-claude-red.ps1
    .\setup-claude-red.ps1 -Category web
    .\setup-claude-red.ps1 -DryRun
#>
param(
    [string]$ClaudeRedPath = "",
    [string]$SkillsPath = "",
    [string]$Category = "",
    [switch]$DryRun,
    [switch]$List
)

$ErrorActionPreference = "Stop"

# Resolve paths relative to the script's parent's parent (.claw/..)
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not $ProjectRoot) {
    $ProjectRoot = Get-Location
}

if (-not $ClaudeRedPath) {
    $ClaudeRedPath = Join-Path $ProjectRoot ".claw\claude-red"
}
if (-not $SkillsPath) {
    $SkillsPath = Join-Path $ProjectRoot ".claw\skills"
}

$SourceSkills = Join-Path $ClaudeRedPath "Skills"

# Validate Claude-Red is cloned
if (-not (Test-Path $SourceSkills)) {
    Write-Host "[ERROR] Claude-Red Skills directory not found at: $SourceSkills" -ForegroundColor Red
    Write-Host "  Clone it first: git clone https://github.com/SnailSploit/Claude-Red .claw/claude-red" -ForegroundColor Yellow
    exit 1
}

# List categories
if ($List) {
    Write-Host "`nAvailable Claude-Red categories:" -ForegroundColor Cyan
    Get-ChildItem -Path $SourceSkills -Directory | ForEach-Object {
        $count = (Get-ChildItem -Path $_.FullName -Directory | Where-Object {
            Test-Path (Join-Path $_.FullName "SKILL.md")
        }).Count
        Write-Host ("  {0,-25} {1} skill(s)" -f $_.Name, $count) -ForegroundColor White
    }
    exit 0
}

# Create skills directory
if (-not (Test-Path $SkillsPath)) {
    if ($DryRun) {
        Write-Host "[dry-run] Would create: $SkillsPath" -ForegroundColor Yellow
    } else {
        New-Item -ItemType Directory -Path $SkillsPath -Force | Out-Null
    }
}

# Determine source categories
$Categories = @()
if ($Category) {
    $catPath = Join-Path $SourceSkills $Category
    if (-not (Test-Path $catPath)) {
        Write-Host "[ERROR] Category '$Category' not found." -ForegroundColor Red
        Write-Host "  Available:" -ForegroundColor Yellow
        Get-ChildItem -Path $SourceSkills -Directory | ForEach-Object { Write-Host "    $($_.Name)" }
        exit 1
    }
    $Categories += $catPath
} else {
    $Categories = Get-ChildItem -Path $SourceSkills -Directory | Select-Object -ExpandProperty FullName
}

$linked = 0
$skipped = 0

foreach ($catDir in $Categories) {
    $catName = Split-Path -Leaf $catDir
    Write-Host "`n[$catName]" -ForegroundColor Cyan

    Get-ChildItem -Path $catDir -Directory | ForEach-Object {
        $skillDir = $_.FullName
        $skillName = $_.Name
        $skillFile = Join-Path $skillDir "SKILL.md"

        if (-not (Test-Path $skillFile)) {
            Write-Host "  SKIP $skillName (no SKILL.md)" -ForegroundColor DarkGray
            $skipped++
            return
        }

        $targetLink = Join-Path $SkillsPath $skillName

        if (Test-Path $targetLink) {
            Write-Host "  EXISTS $skillName" -ForegroundColor DarkGray
            $skipped++
            return
        }

        if ($DryRun) {
            Write-Host "  [dry-run] Would link: $skillName -> $skillDir" -ForegroundColor Yellow
        } else {
            # Use directory junction (works without admin on NTFS)
            cmd /c mklink /J "$targetLink" "$skillDir" 2>&1 | Out-Null
            if (Test-Path $targetLink) {
                Write-Host "  LINKED $skillName" -ForegroundColor Green
            } else {
                # Fallback: copy the directory
                Copy-Item -Path $skillDir -Destination $targetLink -Recurse
                Write-Host "  COPIED $skillName (junction failed, used copy)" -ForegroundColor Yellow
            }
        }
        $linked++
    }
}

Write-Host "`n---" -ForegroundColor DarkGray
if ($DryRun) {
    Write-Host "Dry run complete. Would link $linked skill(s), $skipped skipped." -ForegroundColor Yellow
} else {
    Write-Host "Setup complete: $linked skill(s) linked, $skipped skipped." -ForegroundColor Green
    Write-Host "Skills directory: $SkillsPath" -ForegroundColor White
    Write-Host "`nVerify with: claw /skills list" -ForegroundColor Cyan
}
