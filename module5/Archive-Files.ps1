<#
.SYNPOPSIS
    Scirpt moves files with certain age and move them to archive folder maintaing orginal folder structure.
.PARAMETER FolderPath
    The folder path to search for files
.PARAMETER Age
    The age of the last time a file has been accessed (in days).
.PARAMETER ArchiveFolderPath
    The folder in which the old files will be moved to.
.PARAMETER Force
    Use this switch parameter if you'd like to overwrite all files.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -Path $_ -PathType Container })]
    [string]$FolderPath,
    [Parameter(Mandatory)]
    [int]$Age,
    [ValidateScript({ Test-Path -Path $_ -PathType Container })]
    [string]$ArchiveFolderPath,
    [switch]$Force
)

process {
    try {
        
        $DateNow = Get-Date

        $FilesToArchive = Get-ChildItem -Path $FolderPath -Recurse -File | where { $_.LastWriteTime -le $DateNow.AddDays(-$Age) }

        if(-not $FilesToArchive) {
            Write-Verbose 'No files found to be archived'
        } else {
            
            foreach($File in $FilesToArchive) {
                $DestinationPath = $ArchiveFolderPath + ($File.FullName | Split-Path -NoQualifier)
                Write-Verbose "The file $($File.FullName) is older than $Age days. It will be moved to $DestinationPath"
                
                if(!(Test-Path -Path $DestinationPath -PathType Leaf)) {
                    Write-Verbose "The destination $DestinationPath doesn't exist and will be created."
                    New-Item -ItemType File -Path $DestinationPath -Force | Out-Null
                } elseif(!$Force.IsPresent) {
                    Write-Verbose "The file  $($File.FullName) already exist in the archive location and will not be overwritten."
                    continue
                }
                Write-Verbose "Moving $($File.FullName) to $DestinationPath"
                Move-Item -Path $File.FullName -Destination $DestinationPath -Force
            }
        }

    } catch {
        Write-Error "$($_.Exception.Message) - Line number: $($_.InvocationInfo.ScriptLineNumber)"
    }
}