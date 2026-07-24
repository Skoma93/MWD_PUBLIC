[CmdletBinding()]
param(
    [ValidateSet('pull', 'start-simulation', 'start-hardware', 'status', 'logs', 'stop')]
    [string]$Command = 'status'
)

$ErrorActionPreference = 'Stop'
$bundle = Split-Path -Parent $MyInvocation.MyCommand.Path
$commonEnv = Join-Path $bundle '.env.common'
$base = Join-Path $bundle 'compose.yml'
$simulation = Join-Path $bundle 'compose.simulation.yml'
$hardware = Join-Path $bundle 'compose.hardware.yml'

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { throw 'Docker with Compose v2 is required.' }
if (-not (Test-Path -LiteralPath $commonEnv)) {
    Copy-Item -LiteralPath (Join-Path $bundle '.env.common.example') -Destination $commonEnv
    throw "Created $commonEnv. Replace every placeholder, then rerun."
}
if (Select-String -LiteralPath $commonEnv -Pattern 'replace-with|example.invalid|your-org' -Quiet) {
    throw "Replace every placeholder in $commonEnv before deployment."
}

$common = @('--env-file', $commonEnv, '-f', $base)
switch ($Command) {
    'pull' { & docker compose @common pull }
    'start-simulation' { & docker compose @common --env-file (Join-Path $bundle '.env.simulation') -f $simulation pull; if (-not $LASTEXITCODE) { & docker compose @common --env-file (Join-Path $bundle '.env.simulation') -f $simulation up -d } }
    'start-hardware' { & docker compose @common --env-file (Join-Path $bundle '.env.hardware') -f $hardware pull; if (-not $LASTEXITCODE) { & docker compose @common --env-file (Join-Path $bundle '.env.hardware') -f $hardware up -d } }
    'status' { & docker compose @common ps }
    'logs' { & docker compose @common logs --follow --tail 200 }
    'stop' { & docker compose @common stop }
}
if ($LASTEXITCODE) { exit $LASTEXITCODE }
