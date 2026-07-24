[CmdletBinding()]
param(
    [ValidateSet('simulation', 'hardware')]
    [string]$Mode = 'simulation',
    [switch]$ConfigureOnly
)

$ErrorActionPreference = 'Stop'
$bundle = Split-Path -Parent $MyInvocation.MyCommand.Path
$commonEnvironment = Join-Path $bundle '.env.common'
$modeEnvironment = Join-Path $bundle ".env.$Mode"
$manager = Join-Path $bundle 'manage.ps1'

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw 'Docker Desktop or Docker Engine with Compose v2 is required. Install Docker, start it, then rerun.'
}
& docker compose version | Out-Host
if ($LASTEXITCODE) { throw 'Docker Compose v2 is unavailable.' }
& docker info *> $null
if ($LASTEXITCODE) { throw 'The Docker daemon is unavailable. Start Docker and rerun.' }

if (-not (Test-Path -LiteralPath $commonEnvironment)) {
    Copy-Item -LiteralPath (Join-Path $bundle '.env.common.example') -Destination $commonEnvironment
    Write-Host "Created private configuration: $commonEnvironment" -ForegroundColor Yellow
}
if (-not (Test-Path -LiteralPath $modeEnvironment)) {
    Copy-Item -LiteralPath (Join-Path $bundle ".env.$Mode.example") -Destination $modeEnvironment
    Write-Host "Created private configuration: $modeEnvironment" -ForegroundColor Yellow
    Write-Host 'Set registry, tag, URLs, OIDC values, secrets, and mode settings.'
    Write-Host 'Then run this installer again.'
    exit 2
}

if (Select-String -LiteralPath $commonEnvironment,$modeEnvironment -Pattern 'replace-with|example.invalid|your-org' -Quiet) {
    throw 'Configuration still contains placeholders in the common or mode environment file.'
}
if ($ConfigureOnly) {
    Write-Host 'Docker and configuration checks passed; no images or containers were changed.' -ForegroundColor Green
    exit 0
}

& $manager -Command pull
if ($LASTEXITCODE) { exit $LASTEXITCODE }
& $manager -Command "start-$Mode"
if ($LASTEXITCODE) { exit $LASTEXITCODE }
& $manager -Command status

Write-Host "Installation complete. Open the application URL configured in $commonEnvironment." -ForegroundColor Green
