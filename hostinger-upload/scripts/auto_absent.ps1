param(
  [string]$BaseUrl = "http://localhost/faculty-attendance-api/api/index.php",
  [string]$CredentialFile = "",
  [string]$Username = "",
  [string]$Password = "",
  [string]$Date = "",
  [string]$CutoffTime = "",
  [string]$LogPath = ""
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($Date)) {
  $Date = (Get-Date).ToString('yyyy-MM-dd')
}

if ([string]::IsNullOrWhiteSpace($CutoffTime)) {
  $CutoffTime = (Get-Date).ToString('HH:mm:ss')
}

function Write-Log {
  param([string]$Message)

  $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"
  if (-not [string]::IsNullOrWhiteSpace($LogPath)) {
    $dir = Split-Path -Parent $LogPath
    if (-not [string]::IsNullOrWhiteSpace($dir) -and -not (Test-Path $dir)) {
      New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    Add-Content -Path $LogPath -Value $line
  } else {
    Write-Output $line
  }
}

function Get-HttpErrorBody {
  param($Exception)

  try {
    if ($null -ne $Exception -and $null -ne $Exception.Response) {
      $stream = $Exception.Response.GetResponseStream()
      if ($null -ne $stream) {
        $reader = New-Object System.IO.StreamReader($stream)
        $body = $reader.ReadToEnd()
        $reader.Close()
        return $body
      }
    }
  } catch {
    return ""
  }

  return ""
}

function Get-HttpStatusCode {
  param($Exception)

  try {
    if ($null -ne $Exception -and $null -ne $Exception.Response -and $null -ne $Exception.Response.StatusCode) {
      return [int]$Exception.Response.StatusCode
    }
  } catch {
    return $null
  }

  return $null
}

try {
  $cred = $null

  if (-not [string]::IsNullOrWhiteSpace($CredentialFile)) {
    if (-not (Test-Path $CredentialFile)) {
      throw "Credential file not found: $CredentialFile"
    }
    $cred = Import-Clixml -Path $CredentialFile
  } elseif (-not [string]::IsNullOrWhiteSpace($Username) -and -not [string]::IsNullOrWhiteSpace($Password)) {
    $secure = ConvertTo-SecureString $Password -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential($Username, $secure)
  } else {
    throw "Provide -CredentialFile or (-Username and -Password)."
  }

  $plainPassword = $cred.GetNetworkCredential().Password

  $token = $null
  try {
    $loginBody = @{ username = $cred.UserName; password = $plainPassword } | ConvertTo-Json
    $login = Invoke-RestMethod -Method Post -Uri "$BaseUrl/auth/login" -ContentType "application/json" -Body $loginBody

    if ($login.success -ne $true -or -not $login.data -or -not $login.data.token) {
      throw "Login failed (no token in response)."
    }

    $token = $login.data.token
  } catch {
    $status = Get-HttpStatusCode -Exception $_.Exception
    $details = $null
    try { $details = $_.ErrorDetails.Message } catch { $details = $null }
    $body = if (-not [string]::IsNullOrWhiteSpace($details)) { $details } else { (Get-HttpErrorBody -Exception $_.Exception) }
    Write-Log "auto-absent login error: user=$($cred.UserName) status=$status message=$($_.Exception.Message) body=$body"
    exit 1
  }

  $result = $null
  try {
    $absentBody = @{ date = $Date; cutoff_time = $CutoffTime } | ConvertTo-Json
    $result = Invoke-RestMethod -Method Post -Uri "$BaseUrl/attendance/auto-absent" -ContentType "application/json" -Headers @{ Authorization = "Bearer $token" } -Body $absentBody
  } catch {
    $body = Get-HttpErrorBody -Exception $_.Exception
    Write-Log "auto-absent call error: $($_.Exception.Message) body=$body"
    exit 1
  }

  $inserted = $null
  if ($result -and $result.data -and $result.data.inserted -ne $null) {
    $inserted = $result.data.inserted
  }

  Write-Log "auto-absent ok date=$Date cutoff=$CutoffTime inserted=$inserted"
} catch {
  $body = Get-HttpErrorBody -Exception $_.Exception
  Write-Log "auto-absent error: $($_.Exception.Message) body=$body"
  exit 1
}
