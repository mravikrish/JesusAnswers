# Runs the API on this Windows PC with the local PostgreSQL, using backend\.env.
# Build first:  cd backend; .\mvnw -DskipTests package
# Then:         powershell -ExecutionPolicy Bypass -File backend\deploy\run-windows.ps1
# Logs go to backend\run\api.log. Tailscale Funnel makes it reachable from phones.
$ErrorActionPreference = 'Stop'
$backend = Split-Path $PSScriptRoot -Parent
$run = Join-Path $backend 'run'
New-Item -ItemType Directory -Force $run | Out-Null

# Run a copy, so rebuilding doesn't fight over a locked jar.
$jar = Get-ChildItem (Join-Path $backend 'target\*.jar') | Sort-Object LastWriteTime | Select-Object -Last 1
if (-not $jar) { throw 'No jar in backend\target. Build it first.' }
Copy-Item $jar.FullName (Join-Path $run 'app.jar') -Force

foreach ($line in Get-Content (Join-Path $backend '.env')) {
    if ($line -match '^\s*([A-Z_][A-Z0-9_]*)=(.*)$') {
        [Environment]::SetEnvironmentVariable($Matches[1], $Matches[2], 'Process')
    }
}

# Windows-ROOT: trust the certificates Windows trusts (Avast intercepts HTTPS on this PC).
$ErrorActionPreference = 'Continue'   # Java's stderr lines must not stop the script
& java '-Djavax.net.ssl.trustStoreType=Windows-ROOT' '-XX:MaxRAMPercentage=25' -jar (Join-Path $run 'app.jar') 2>&1 |
    ForEach-Object { "$_" } | Out-File (Join-Path $run 'api.log') -Append -Encoding utf8
