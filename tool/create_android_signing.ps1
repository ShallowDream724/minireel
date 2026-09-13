param([Parameter(Mandatory = $true)][string]$KeytoolPath)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$secretFile = Join-Path $projectRoot 'ANDROID_SIGNING_SECRETS.txt'
$keyDirectory = Join-Path $projectRoot 'android/.signing'
$keystoreFile = Join-Path $keyDirectory 'minireel-release.jks'
if (!(Test-Path -LiteralPath $KeytoolPath -PathType Leaf)) { throw 'keytool was not found.' }
if ((Test-Path -LiteralPath $keystoreFile) -or (Test-Path -LiteralPath $secretFile)) {
    throw 'Signing material already exists. It will not be overwritten or rotated.'
}
foreach ($privatePath in @($secretFile, $keystoreFile)) {
    git -C $projectRoot check-ignore --no-index --quiet -- $privatePath
    if ($LASTEXITCODE -ne 0) { throw 'Signing outputs must be ignored by Git before they are generated.' }
}

function New-SigningPassword {
    $bytes = New-Object byte[] 32
    $random = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $random.GetBytes($bytes) } finally { $random.Dispose() }
    return [BitConverter]::ToString($bytes).Replace('-', '')
}

$storePassword = New-SigningPassword
$keyPassword = New-SigningPassword
$alias = 'minireel'
New-Item -ItemType Directory -Path $keyDirectory -Force | Out-Null
$env:MINIREEL_SIGNING_STORE_PASSWORD = $storePassword
$env:MINIREEL_SIGNING_KEY_PASSWORD = $keyPassword
try {
    $keytoolOutput = & $KeytoolPath -genkeypair -noprompt -storetype JKS -keystore $keystoreFile -alias $alias -keyalg RSA -keysize 3072 -validity 10000 -dname 'CN=MiniReel, OU=Release, O=MiniReel, C=CN' -storepass:env MINIREEL_SIGNING_STORE_PASSWORD -keypass:env MINIREEL_SIGNING_KEY_PASSWORD 2>&1
    if ($LASTEXITCODE -ne 0) { throw ('Key generation failed: ' + ($keytoolOutput -join ' ')) }
    $encodedKeystore = [Convert]::ToBase64String([IO.File]::ReadAllBytes($keystoreFile))
    $lines = @(
        'MiniReel Android release signing - GitHub Repository Secrets',
        'https://github.com/WEP-56/minireel/settings/secrets/actions',
        '',
        'Create the following four repository secrets. Copy only the value after the first =.',
        '',
        "ANDROID_KEYSTORE_BASE64=$encodedKeystore",
        '',
        "ANDROID_KEYSTORE_PASSWORD=$storePassword",
        '',
        "ANDROID_KEY_ALIAS=$alias",
        '',
        "ANDROID_KEY_PASSWORD=$keyPassword",
        '',
        'After saving all four secrets on GitHub, delete this txt file before committing.',
        'The encrypted keystore backup is android/.signing/minireel-release.jks (ignored by Git).',
        'Keep the same signing secrets for future versions so installed apps can be upgraded.'
    )
    [IO.File]::WriteAllText($secretFile, ($lines -join [Environment]::NewLine), [Text.UTF8Encoding]::new($false))
    Write-Output 'Created ANDROID_SIGNING_SECRETS.txt and the encrypted keystore. Secret values were not printed.'
} finally {
    Remove-Item Env:MINIREEL_SIGNING_STORE_PASSWORD -ErrorAction SilentlyContinue
    Remove-Item Env:MINIREEL_SIGNING_KEY_PASSWORD -ErrorAction SilentlyContinue
}
