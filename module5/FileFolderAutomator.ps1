function Archive-File { 
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
}

function Get-MyAcl { 
<#
.SYNOPSIS
    This allows an easy method to get a file system access ACE
.PARAMETER Path
    The path of a file
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateScript({Test-Path -Path $_})]
    [string]$Path
)

process {
    try {
        (Get-Acl -Path $Path).Access
    } catch {
        Write-Error "$($_.Exception.Message) - Line number: $($_.InvocationInfo.ScriptLineNumber)"
    }
}
}

function Get-MyFile { 
param ([string[]]$Computername = 'localhost', [string]$Criteria, [hashtable]$Attributes)

foreach ($Computer in $Computername) {
	## Enumerate all of the default admin shares
    $CimInstParams = @{'ClassName' = 'Win32_Share'}
    if ($Computer -ne 'localhost') {
	    $CimInstParams.Computername = $Computer    
    }
    $DriveShares = (Get-CimInstance @CimInstParams | where { $_.Name -match '^[A-Z]\$$' }).Name
	foreach ($Drive in $DriveShares) {
		switch ($Criteria) {
			'Extension' {
                Get-ChildItem -Path "\\$Computer\$Drive" -Filter "*.$($Attributes.Extension)" -Recurse
			}
			'Age' {
				$Today = Get-Date
                $DaysOld = $Attributes.DaysOld
                Get-ChildItem -Path "\\$Computer\$Drive" -Recurse | Where-Object { $_.LastWriteTime -le $Today.AddDays(-$DaysOld)}
			}
			'Name' {
                $Name = $Attributes.Name
				Get-ChildItem -Path "\\$Computer\$Drive" -Filter "*$Name*" -Recurse
			}
            default {
                Write-Error "Unrecognized criteria '$Criteria'"
            }
		}
	}
}
}

function Remove-MyAcl {
<#
.SYNPOSIS
    This function allows an easy method to remove system ACEs
.PARAMETER Path
    The file path of a file
.PARAMETER Identity
    The security principal to match with the ACE user would like to remove.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -Path $_})]
    [string]$Path,
    [Parameter(Mandatory)]
    [string]$Identity    
)

process {
    try {
        $Acl = (Get-Item $Path).GetAccessControl('Access')
        $Acl.Access | Where-Object { $_.IdentityReference -eq $Identity } | foreach { $Acl.RemoveAccessRule($_) | Out-Null }
        Set-Acl -Path $Path -AclObject $Acl
    } catch {
        Write-Error "$($_.Exception.Message) - Line number: $($_.InvocationInfo.ScripLineNumber)"
    }
}
}

function Set-MyAcl { 
<#
.SYNOPSIS
	This allows an easy method to set a file system access ACE
.PARAMETER Path
 	The file path of a file
.PARAMETER Identity
	The security principal you'd like to set the ACE to.  This should be specified like
	DOMAIN\user or LOCALMACHINE\User.
.PARAMETER Right
	One of many file system rights.  For a list http://msdn.microsoft.com/en-us/library/system.security.accesscontrol.filesystemrights(v=vs.110).aspx
.PARAMETER InheritanceFlags
	The flags to set on how you'd like the object inheritance to be set.  Possible values are
	ContainerInherit, None or ObjectInherit. http://msdn.microsoft.com/en-us/library/system.security.accesscontrol.inheritanceflags(v=vs.110).aspx
.PARAMETER PropagationFlags
	The flag that specifies on how you'd permission propagation to behave. Possible values are
	InheritOnly, None or NoPropagateInherit. http://msdn.microsoft.com/en-us/library/system.security.accesscontrol.propagationflags(v=vs.110).aspx
.PARAMETER Type
	The type (Allow or Deny) of permissions to add. http://msdn.microsoft.com/en-us/library/w4ds5h86(v=vs.110).aspx
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateScript({Test-Path -Path $_})]
    [string]$Path,
    [Parameter(Mandatory)]
    [string]$Identity,   
    [Parameter(Mandatory)]
    [string]$Right,
    [Parameter(Mandatory)]
    [ValidateSet('ContainerInherit','None','ObjectInherit','ContainerInherit,ObjectInherit')]
    [string]$InheritanceFlags,
    [Parameter(Mandatory)]
    [ValidateSet('InheritOnly', 'None', 'NoPropagateInherit')]
    [string]$PropagationFlags,
    [Parameter(Mandatory)]
    [ValidateSet('Allow','Deny')]
    [string]$Type
)

process {
     try {
        $Acl = (Get-Item $Path).GetAccessControl('Access')
        $Ar = New-Object System.Security.AccessControl.FileSystemAccessRule($Identity, $Right, $InheritanceFlags, $PropagationFlags, $Type)
        $Acl.SetAccessRule($Ar)
        Set-Acl $Path $Acl
     } catch {
        Write-Error -Message "Error: $($_.Exception.Message) - Line number: $($_.InvocationInfo.SriptLineNumber)"
     }
}
}