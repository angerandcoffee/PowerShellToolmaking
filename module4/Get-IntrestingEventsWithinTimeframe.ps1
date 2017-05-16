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
begin {
    . .\LogInvestigator.ps1
}
process {
    try {
        $Params = @{
            'ComputerName' = $ComputerName
            'StartTimestamp' = $StartTimestamp
            'EndTimestamp' = $EndTimestamp
        }
        Get-WinEventWithin @Params
        Get-TextLogEventWithin @Params -LogFileExtension $LogFileExtension
    } catch {
        Write-Error "$($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
    }
}