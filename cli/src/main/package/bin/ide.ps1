# Dot-source this script to persist environment variables in the current PowerShell session:
#   . ide.ps1 [args...]
# Running directly (.\ide.ps1) will NOT persist environment variables to the parent session.

$fBYellow = "`e[93m"
$fBRed = "`e[91m"
$RESET = "`e[0m"

# Add Git PATH entries for PowerShell - https://github.com/devonfw/IDEasy/issues/764
$gitHome = $null
foreach ($hive in @("HKLM:\Software\GitForWindows", "HKCU:\Software\GitForWindows")) {
  try {
    if (Test-Path $hive) {
      $installPath = (Get-ItemProperty $hive -ErrorAction SilentlyContinue).InstallPath
      if ($installPath) {
        $gitHome = $installPath
        break
      }
    }
  } catch { }
}

if ($gitHome) {
  $gitBin = Join-Path $gitHome "usr\bin"
  $gitCore = Join-Path $gitHome "mingw64\libexec\git-core"
  if ((Test-Path $gitBin) -and ($env:PATH -notlike "*$gitBin*")) {
    $env:PATH += ";$gitBin"
  }
  if ((Test-Path $gitCore) -and ($env:PATH -notlike "*$gitCore*")) {
    $env:PATH += ";$gitCore"
  }
}

# Build IDE_OPTIONS array
$ideOptionsArr = @()
if ($env:IDE_OPTIONS) {
  $ideOptionsArr = $env:IDE_OPTIONS -split '\s+' | Where-Object { $_ -ne '' }
}

# Run ideasy with arguments if provided
if ($args.Count -gt 0) {
  & ideasy @ideOptionsArr @args
  $exitCode = $LASTEXITCODE
  if ($exitCode -ne 0) {
    Write-Host ""
    Write-Host "${fBRed}Error: IDEasy failed with exit code ${exitCode}${RESET}"
    Write-Host ""
    Write-Host "${fBYellow}Please use (git-)bash (integrated in Windows Terminal) for full IDEasy support:"
    Write-Host "https://github.com/devonfw/IDEasy/blob/main/documentation/advanced-tooling-windows.adoc#tabs-for-shells${RESET}"
    return
  }

  # After successful create, auto-cd into the new project (see #1458)
  for ($i = 0; $i -lt $args.Count; $i++) {
    if ($args[$i] -eq 'create') {
      for ($j = $i + 1; $j -lt $args.Count; $j++) {
        if (-not $args[$j].StartsWith('-')) {
          $projectPath = Join-Path $env:IDE_ROOT $args[$j]
          if (Test-Path $projectPath -PathType Container) {
            Set-Location $projectPath
          }
          break
        }
      }
      break
    }
  }
}

# Set environment variables from ideasy env output (VAR=VALUE format)
$envLines = & ideasy @ideOptionsArr env
if ($LASTEXITCODE -eq 0) {
  foreach ($line in $envLines) {
    $eqIdx = $line.IndexOf('=')
    if ($eqIdx -gt 0) {
      $varName = $line.Substring(0, $eqIdx)
      $varValue = $line.Substring($eqIdx + 1)
      Set-Item -Path "env:$varName" -Value $varValue
    }
  }
  if ($args.Count -eq 0) {
    Write-Host "IDE environment variables have been set for $env:IDE_HOME in workspace $env:WORKSPACE"
  }
}

Write-Host ""
Write-Host "${fBYellow}Please use (git-)bash (integrated in Windows Terminal) for full IDEasy support:"
Write-Host "https://github.com/devonfw/IDEasy/blob/main/documentation/advanced-tooling-windows.adoc#tabs-for-shells${RESET}"
