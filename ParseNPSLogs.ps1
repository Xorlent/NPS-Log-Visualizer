# Many thanks to https://github.com/geek-at for the inspiration and PHP code used to develop this project!

<#
BACKFILL: If $true, Load any files found within the specified NPS log path.
     If backfill has previously run (as indicated by the presence of a .\backfilled.txt file,
     backfill beginning on the day following the previous run.
BACKFILL: If $false, just open today's file, fill according to the .\lasttime.txt DTS, and tail the log to catch new events.
#>
param([bool]$BACKFILLFLAG = $false)

. .\radius_functions.ps1 # load the field translation functions

$ConfigFile = '.\ParseNPS-Config.xml'
$ConfigParams = [xml](get-content $ConfigFile)

<#
IGNOREUSER: Skip logs with the specified username.  Some admins want to see RADIUS test user logs while others do not.
Microsoft NPS configuration guidance, including how to disable logging of the test user, can be found here:
https://github.com/Xorlent/Cybersec-Links/blob/main/Microsoft-NPS.md
#>

$IGNOREUSER = 'svc-radius'
$PATH = 'C:\NPSLogs'        # Location of your NPS logs
$DBNAME = 'radius'            # Name of the InfluxDB UDP database
$DBSERVER = 'localhost'       # InfluxDB hostname
$DBPORT = 8089                # InfluxDB UDP port
$ONLYNEWDATA = $true          # Push log data created since the last processed record only (keys off of lasttime.txt)

<#
$PATH = $ConfigParams.configuration.log.path.value
$DBNAME = $ConfigParams.configuration.server.dbname.value
$DBSERVER = $ConfigParams.configuration.server.dbserver.value
$DBPORT = $ConfigParams.configuration.server.dbport.value
$IGNOREUSER = $ConfigParams.configuration.option.ignoreuser.value
$ONLYNEWDATA = $ConfigParams.configuration.option.newdata.value
#>

$UDPCLIENT = New-Object System.Net.Sockets.UdpClient $DBSERVER, $DBPORT
$FOLLOWINGLOG = $false

if($ONLYNEWDATA)
{
    if (Test-Path -Path .\lasttime.txt -PathType Leaf){$lasttime = Get-Content .\lasttime.txt -Raw}
    else {$lasttime = 0}
}

function saveLastTime($time)
{
    $time | Out-File -FilePath .\lasttime.txt
}

function fill($backfill)
{
    if(!$backfill)
    {
	$datestring = (Get-Date).ToString("yyMMdd")
        $file = $PATH + '\IN' + $datestring + '.log'
    }
    else 
    {
        $file = $backfill
    }

    if (-not(Test-Path -Path $file -PathType Leaf)) {
        Write-Output "No log file $file found to process."
        return -1
    }
    Write-Output "...Processing $file..."

    $fileHandle = [System.IO.File]::OpenText($file)

    :nextLine while ($d = $fileHandle.ReadLine())
    {
        parseLog $d
    }
    $fileHandle.Close()
    $fileHandle.Dispose()
}

function follow()
{
    $datestring = (Get-Date).ToString("yyMMdd")
    $file = $PATH + '\IN' + $datestring + '.log'

    if (-not(Test-Path -Path $file -PathType Leaf)) {
        Write-Output "No log file $file found to process."
        return -1
    }
    $FOLLOWINGLOG = $true
    Write-Output "...Tailing log file $file"
    Get-Content -Wait -Tail 0 -Path $file | % {parseLog}
}

function parseLog($f)
{
    if(!$f){
    	$f = $_
    }
    if($f.Length -lt 1){return}
    if($f.Contains($IGNOREUSER)){return}
    $f = $f.Trim()
    $g = $f.Split(',')
    $date = $g[2].Replace('"', '')
    $time = $g[3].Replace('"', '')

    #$timestamp = [DateTime]::ParseExact(($date + " " + $time), "yyyy-MM-dd H:m:s", $null).Ticks / 10000000 # European DT format
    $timestamp = [DateTime]::ParseExact(($date + " " + $time), "MM/dd/yyyy H:m:s", $null).Ticks / 10000000 # US DT Format
    
    if ($FOLLOWINGLOG){
    	$logDayofMonth = $date.Split('/')
    	$currentDayofMonth = Get-Date -Format "dd"
     	if($currentDayofMonth -gt $logDayofMonth[1]){
      	    powershell.exe -File ".\ParseNPSLogs.ps1"
	        exit 0
      	}
    }
    if ($ONLYNEWDATA -and $timestamp -le $lasttime){return}

    $logDTS = Get-Date ($date + " " + $time) -Format 'MM/dd/yyyy HH:mm:ss'
    $server = $g[0].Replace('"', '')
    $origin = $g[6].Replace('"', '')
    $uname = $g[7].Replace('"', '')
    $type = $g[4].Replace('"', '')
    $client = $g[5].Replace('"', '')

    if($client.Contains('/'))
    {
        $startTrim = $client.IndexOf('/') + 1
        $endTrim = $client.length - $startTrim
        $client = $client.Substring($startTrim,$endTrim)
    }

    $client_mac = $g[8].Replace('"', '').Replace('-', ':').Trim()
    if($client_mac.Contains('|'))
    {
        $client_mac = $client_mac.Substring(0,$client_mac.IndexOf('|'))  ## EAT THE DOUBLE MAC
    }
    if ($client_mac -and -not $client_mac.Contains(':') -and $client_mac.Length -eq 12)
    {
        $client_mac = $client_mac.Insert(10,":")
        $client_mac = $client_mac.Insert(8,":")
        $client_mac = $client_mac.Insert(6,":")
        $client_mac = $client_mac.Insert(4,":")
        $client_mac = $client_mac.Insert(2,":")
    }

    $ap_ip = $g[15].Replace('"', '')
    $ap_radname_full = $g[16].ToLower().Replace('"', '')
    $policy = $g[60].Replace('"', '')
    $auth = TranslateAuth($g[23].Replace('"', ''))
    $policy2 = $g[24]
    $reason = $g[25].Replace('"', '')
    $rs = TranslateReason($reason)
    $authmethod = $g[30]

    # $ap_host = $g[11].Replace('"', '')
    # $ap_radname = $g[16].Substring(0, 5).ToLower().Replace('"', '')
    # $speed = $g[20].Replace('"', '')

    $tt = TranslatePackageType($type)
    $tq = [Math]::Round($timestamp / 900) * 900

    if ($origin.Contains('\'))
    {
        $startTrim = $origin.IndexOf('\') + 1
        $endTrim = $origin.length - $startTrim
        $OU = $origin.Substring(0,$origin.IndexOf('\'))
        $origin_client = $origin.Substring($startTrim,$endTrim)
    }
    elseif ($origin.Contains('/'))
    {
        $startTrim = $origin.IndexOf('/') + 1
        $endTrim = $origin.length - $startTrim
        $OU = $origin.Substring(0,$origin.IndexOf('/'))
        $origin_client = $origin.Substring($startTrim,$endTrim)
    }
    else
    {
        $origin_client = $origin
    }

    $influxtime = ([DateTimeOffset]$logDTS).ToUnixTimeSeconds() # Convert to Unix timestamp
    $influxtime = [string]$influxtime + "000000000" # Add requisite nanoseconds

    if($OU) {$OU = SanitizeStringForInflux($OU)}
    else {$OU = ''}

    $origin_client = SanitizeStringForInflux($origin_client)

    switch($type)
    {
        1 { #Requesting access
                    
            # Making sure all tag values are set and if not, set them to "0"
            $policy2 = if ($policy2) { SanitizeStringForInflux($policy2) } else { 'nomatch' }
            $client_mac = if ($client_mac) { $client_mac } else { '0' }
            $ap_radname_full = if ($ap_radname_full) { $ap_radname_full } else { '0' }
            $origin_client = if ($origin_client) { $origin_client } else { '0' }

            sendToDB "$DBNAME,type=auth-request,device=$ap_radname_full,deviceip=$ap_ip,netpolicy=$policy2,special=$client_mac,special_type=mac value=`"$origin_client`",special=`"$client_mac`"" $influxtime
            }

        2 { #Accepted

            # Making sure all tag values are set and if not, set them to "0"
            $authmethod =  if ($authmethod) { SanitizeStringForInflux($authmethod) } else { 'other' }
            $OU = if ($OU) { $OU } else { '0' }
            $ap_radname_full = if ($ap_radname_full) { $ap_radname_full } else { '0' }
            $origin_client = if ($origin_client) { $origin_client } else { '0' }

            sendToDB "$DBNAME,type=auth-accept,device=$ap_radname_full,deviceip=$ap_ip,authmethod=$authmethod,special=$OU,special_type=OU value=`"$origin_client`"" $influxtime
            }

        3 { #Rejected

            #making sure all tag values are set and if not, set them to "0"
            $ap_radname_full = if ($ap_radname_full) { $ap_radname_full } else { '0' }
            $reason = if ($reason) { $reason } else { '0' }
            $origin_client = if ($origin_client) { $origin_client } else { '0' }
            $rs = if ($rs) { $rs } else { '0' }

            sendToDB "$DBNAME,type=auth-rejected,device=$ap_radname_full,deviceip=$ap_ip,special=$reason,special_type=reason value=`"$origin_client`",special_val=`"$rs`"" $influxtime
            }

        4 { #Accounting-Request

            #making sure all tag values are set and if not, set them to "0"
            $ap_radname_full = if ($ap_radname_full) { $ap_radname_full } else { '0' }
            $origin_client = if ($origin_client) { $origin_client } else { '0' }
            if ($client_mac) {
                sendToDB "$DBNAME,type=accounting-request,device=$ap_radname_full,deviceip=$ap_ip,special=$client_mac,special_type=mac value=`"$origin_client`",special=`"$client_mac`"" $influxtime
            } 
            else {
                if ($client) {
                sendToDB "$DBNAME,type=accounting-request,device=$ap_radname_full,deviceip=$ap_ip,special=$client,special_type=user value=`"$client`"" $influxtime
                }
            }
            }

        5 { #Accounting-Response

            #making sure all tag values are set and if not, set them to "0"
            $client_mac = if ($client_mac) { $client_mac } else { '0' }
            $ap_radname_full = if ($ap_radname_full) { $ap_radname_full } else { '0' }
            $origin_client = if ($origin_client) { $origin_client } else { '0' }

            sendToDB "$DBNAME,type=accounting-response,device=$ap_radname_full,deviceip=$ap_ip,special=$client_mac,special_type=mac value=`"$origin_client`",special=`"$client_mac`"" $influxtime
            }

        11 { #Access-Challenge

            #making sure all tag values are set and if not, set them to "0"
            $policy2 = if ($policy2) { SanitizeStringForInflux($policy2) } else { 'nomatch' }
            $client_mac = if ($client_mac) { $client_mac } else { '0' }
            $ap_radname_full = if ($ap_radname_full) { $ap_radname_full } else { '0' }
            $origin_client = if ($origin_client) { $origin_client } else { '0' }

            sendToDB "$DBNAME,type=auth-challenge,device=$ap_radname_full,deviceip=$ap_ip,netpolicy=$policy2,special=$client_mac,special_type=mac value=`"$origin_client`",special=`"$client_mac`"" $influxtime
            }
        #default {}
    }
    saveLastTime($timestamp)
}

function sendToDB($data,$time)
{
    $data = $data + ' ' + $time
    $bytearray = $([System.Text.Encoding]::ASCII).getbytes($data)
    if ($bytearray.count -lt 996) {
    	$UDPCLIENT.Send($bytearray, $bytearray.length) | out-null
    	Write-Host " ____________________________________________________________ "
    	Write-Host $data
    	Write-Host " ------------------------------------------------------------ "
    }
    else{
    	Write-Host " _DATA NOT SENT__DATA NOT SENT__DATA NOT SENT__DATA NOT SENT_ "
    	Write-Host $data
    	Write-Host " -------------LENGTH EXCEEDS UDP PACKET LIMIT---------------- "
     }
}

function sanitizeStringForInflux($string)
{
    $StringRet = $string.trim()
    if($StringRet.Contains(',')){$stringRet = $stringRet.replace(',','\,')}
    if($StringRet.Contains(' ')){$stringRet = $stringRet.replace(' ','\ ')}
    if($StringRet.Contains('=')){$stringRet = $stringRet.replace('=','\=')}
    return $stringRet
}

# START READING LOGS...
if($BACKFILLFLAG -eq $true)
{
    if (Test-Path -Path .\backfilled.txt -PathType Leaf){
    	$backfillDTS = Get-Content .\backfilled.txt
        $today = Get-Date -Format 'yyMMdd'
        if($backfillDTS -eq $today){fill $false}
        else{
            $readableDate = $backfillDTS.Substring(2,2) + '/' + $backfillDTS.Substring(4,2) + '/' + $backfillDTS.Substring(0,2)
            Write-Output "WARNING: Data was already backfilled on $readableDate.  *****TO OVERRIDE, PLEASE DELETE THE FILE .\backfilled.txt AND RE-RUN THE SCRIPT*****"
            $catchup = Read-Host 'Press c to catch up since the last time you backfilled data through today OR press ENTER to load todays log'
            if($catchup.ToLower() -eq 'c'){
                Write-Output "Catching up"
                $logList = Get-ChildItem $PATH -File -Filter *.log | Sort-Object -Property Name
                Foreach ($backfillFile in $logList){
                    $fileDate = $backfillFile.Name
                    $fileDate = $fileDate -replace '.log',''
                    $fileDate = $fileDate -replace 'IN',''
                    if($fileDate -gt $backfillDTS){
    	                Write-Output "...Backfilling log data for $backfillFile..."
    	                fill $backfillFile.FullName
                    }
                    else{Write-Output "Skipping $backfillFile..."}
                }
                (Get-Date).ToString("yyMMdd") | Out-File -FilePath .\backfilled.txt
            } 
            else {fill $false}
        }
    }
    else{
        $logList = Get-ChildItem $PATH -File -Filter *.log | Sort-Object -Property Name
        Foreach ($backfillFile in $logList){
    	    Write-Output "...Backfilling log data for $backfillFile..."
    	    fill $backfillFile.FullName
        }
        Get-Date -Format 'yyMMdd' | Out-File -FilePath .\backfilled.txt
    }
}
else{
    fill $false
    }
follow
