function Get-WinEventWithin {
[CmdletBinding()]
param(
    [ValidateScript({Test-Connection -ComputerName $_ -Quiet -Count 1})]
    [string]$ComputerName = 'localhost',
    [Parameter(Mandatory)]
    [datetime]$StartTimestamp,
    [Parameter(Mandatory)]
    [datetime]$EndTimestamp
)
    process {
        try {
            $Logs = (Get-WinEvent -ListLog * -ComputerName $ComputerName | Where-Object { $_.RecordCount }).LogName

            $FilterTable = @{
                'StartTime' = $StartTimestamp
                'EndTime' = $EndTimestamp
                'LogName' = $Logs
            }

            Get-WinEvent -ComputerName $ComputerName -FilterHashtable $FilterTable -ErrorAction 'SilentlyContinue'
        } catch {
            Write-Error "$($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
        }
    }
}

function Get-TextLogEventWithin {
    [CmdletBinding()]
param(
    [ValidateScript({Test-Connection -ComputerName $_ -Quiet -Count 1})]
    [string]$ComputerName = 'localhost',
    [Parameter(Mandatory)]
    [datetime]$StartTimestamp,
    [Parameter(Mandatory)]
    [datetime]$EndTimestamp,
    [string]$LogFileExtension = 'log'
)
process {
        try {
            if($ComputerName -eq 'localhost'){
                ## look for log files on local drives
                $Locations = (Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType = '3'").DeviceID
            } else {
                 ## look for log files on shares
                $Shares = Get-CimInstance -ComputerName $ComputerName -ClassName Win32_Share | Where-Object { $_.Path -match '^\w{1}:\\$'}

                [System.Collections.ArrayList]$Locations = @()
                foreach($Share in $Shares) {
                    $Share = "\\$ComputerName\$($Share.Name)"
                    if(!(Test-Path $Share)) {
                        Write-Warning "Unable to asses '$Share' share on '$ComputerName'"
                    } else {
                        $Locations.Add($Share) | Out-Null
                    }
                }
            }

            ## hashtable to perform splatting Get-ChildItem
            $GciParams = @{
                Path = $Locations
                Filter = "*.$LogFileExtension"
                Recurse = $true
                ErrorAction = 'SilentlyContinue'
                File = $true
            }

            $WhereFilter = {($_.LastWriteTime -ge $StartTimestamp) -and ($_.LastWriteTime -le $EndTimestamp) -and ($_.Length -ne 0)}

            Get-ChildItem @GciParams | Where-Object $WhereFilter
        } catch {
            Write-Error "$($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
        }
    }
}