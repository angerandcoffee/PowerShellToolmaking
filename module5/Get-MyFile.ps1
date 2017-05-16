param([string[]]$ComputerName = 'localhost', [string]$Criteria, [hashtable]$Attributes)

foreach($Computer in $ComputerName) {
    $CimInstParams = @{'ClassName' = 'Win_Share'}
    if($Computer -ne 'localhost') {
        $CimInstParams.ComputerName = $Computer
    }
    $DriveShares = (Get-CimInstance $CimInstParams | Where-Object { $_.Name -match '^[A-Z]\$$'}).Name

    foreach($Drive in $DriveShares)
    {
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
            Default {
                Write-Error "Unrecognized criteria '$Criteria'"
            }
        }
    }
}