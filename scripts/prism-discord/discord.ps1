# Prism: keeps the Discord status of mpv (Rich Presence). Started by main.lua next to this file.
# mpv writes the wanted activity (JSON) to the -State file; this helper sends it to the Discord app
# through its pipe \\.\pipe\discord-ipc-N. Empty file = no status. Missing file = no change.
# Ends by itself when mpv (-MpvPid) is gone; Discord then clears the status.
# Kept ASCII-only: Windows PowerShell 5.1 reads BOM-less files as cp1251.
param(
    [Parameter(Mandatory)] [string] $State,
    [Parameter(Mandatory)] [int] $MpvPid,
    [Parameter(Mandatory)] [string] $ClientId,
    [string] $Log = ""     # for tests: Discord's answers are appended here
)

$utf8 = New-Object System.Text.UTF8Encoding($false)
$script:pipe = $null
$last = $null
$retry = [DateTime]::MinValue

function Close-Pipe {
    if ($script:pipe) { try { $script:pipe.Dispose() } catch {} }
    $script:pipe = $null
}

function Read-Exact([int] $n) {
    $buf = New-Object byte[] $n
    $got = 0
    while ($got -lt $n) {
        $r = $script:pipe.Read($buf, $got, $n - $got)
        if ($r -le 0) { throw "pipe closed" }
        $got += $r
    }
    return ,$buf
}

# one frame (op code, length, JSON) and the answer as text
function Send-Frame([int] $op, [string] $json) {
    $body = $utf8.GetBytes($json)
    $frame = New-Object byte[] (8 + $body.Length)
    [BitConverter]::GetBytes([int] $op).CopyTo($frame, 0)
    [BitConverter]::GetBytes([int] $body.Length).CopyTo($frame, 4)
    $body.CopyTo($frame, 8)
    $script:pipe.Write($frame, 0, $frame.Length)
    $script:pipe.Flush()
    $head = Read-Exact 8
    $len = [BitConverter]::ToInt32($head, 4)
    $answer = $utf8.GetString((Read-Exact $len))
    if ($Log) { [IO.File]::AppendAllText($Log, $answer + "`r`n", $utf8) }
    return $answer
}

function Connect-Discord {
    for ($i = 0; $i -lt 10; $i++) {
        try {
            $p = New-Object System.IO.Pipes.NamedPipeClientStream(".", "discord-ipc-$i", [System.IO.Pipes.PipeDirection]::InOut)
            $p.Connect(300)
            $script:pipe = $p
            $answer = Send-Frame 0 ('{"v":1,"client_id":"' + $ClientId + '"}')
            if ($answer -match '"READY"') { return $true }
            Close-Pipe
        } catch { Close-Pipe }
    }
    return $false
}

while ($true) {
    if (-not (Get-Process -Id $MpvPid -ErrorAction SilentlyContinue)) { break }
    $want = $null
    if (Test-Path -LiteralPath $State) {
        try { $want = [IO.File]::ReadAllText($State, $utf8).Trim() } catch { $want = $null }
    }
    if ($null -ne $want -and $want -ne $last) {
        if (-not $script:pipe -and $want -ne "" -and (Get-Date) -ge $retry) {
            if (-not (Connect-Discord)) { $retry = (Get-Date).AddSeconds(20) }
        }
        if ($script:pipe) {
            $activity = if ($want -eq "") { "null" } else { $want }
            try {
                $null = Send-Frame 1 ('{"cmd":"SET_ACTIVITY","nonce":"' + [guid]::NewGuid() + '","args":{"pid":' + $MpvPid + ',"activity":' + $activity + '}}')
                $last = $want
            } catch { Close-Pipe }
        } elseif ($want -eq "") {
            $last = $want
        }
    }
    Start-Sleep -Milliseconds 1000
}
Close-Pipe
Remove-Item -LiteralPath $State -ErrorAction SilentlyContinue
