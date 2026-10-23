$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Force -Path "artifacts" | Out-Null
$token = (gh auth token).Trim()
$artifactUrl = "https://api.github.com/repos/shaiiiikh-github/LegacyDisplay/actions/artifacts/12509914034/zip"
$zipPath = "artifacts\LegacyDisplay-artifact.zip"

Write-Host "Downloading artifact using native curl.exe..."
& curl.exe -s -S -H "Authorization: Bearer $token" -H "Accept: application/vnd.github+json" -H "User-Agent: LegacyDisplay" -L $artifactUrl -o $zipPath

if (Test-Path $zipPath) {
    $size = (Get-Item $zipPath).Length
    Write-Host "Downloaded $zipPath ($size bytes)."
    Write-Host "Extracting artifact..."
    Expand-Archive -Path $zipPath -DestinationPath "artifacts" -Force
    Write-Host "Extraction completed:"
    Get-ChildItem -Path "artifacts"
} else {
    Write-Error "Failed to download $zipPath"
}
