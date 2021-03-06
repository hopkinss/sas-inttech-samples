# -------------------------------------------------------------------
# ReadSasDataColumns.ps1 
# Scan a folder and all subfolders for SAS7BDAT files
# and report on the columns within the SAS data set 
# including column name, type, SAS format/informat, and more
#
# Example usages:
#  
#   ReadSasDataColumns.ps1 c:\Data 
#      - puts all output to the console
#
#   ReadSasDataColumns.ps1 c:\Data | Out-GridView
#      - Opens a new output grid view with all data attributes displayed
#
#   ReadSasDataColumns.ps1 c:\Data | Export-CSV -Path C:\Report\columns.csv -NoTypeInformation
#      - Creates a CSV file, ready for use in Excel, with all of the columns attribute information
# -------------------------------------------------------------------
# check for an input file
if ($args.Count -eq 1) {
    $folderToProcess = $args[0] 
}
else {
    Write-Host "EXAMPLE Usage: ReadSasDataColumns.ps1 path"
    Exit -1
}

# check that the input file exists
if (-not (Test-Path $folderToProcess)) {
    Write-Host "`"$folderToProcess`" does not exist."
    Exit -1
}

# check that the SAS Local Data Provider is present
if (-not (Test-Path "HKLM:\SOFTWARE\Classes\sas.LocalProvider")) {
    Write-Host "SAS OLE DB Local Data Provider is not installed.  Download from http://support.sas.com!"
    Exit -1
}

# Get all of the candidate SAS files
foreach ($dataset in Get-ChildItem $folderToProcess -Recurse -Filter "*.sas7bdat") {

    $filePath = Split-Path $dataset.Fullname
    $filename = [System.IO.Path]::GetFileNameWithoutExtension($dataset.FullName)  
    $criteria = @(0) * 3
    $criteria[2] = $filename
    
    $adSchemaColumns = 4

    $objConnection = New-Object -comobject ADODB.Connection
    $objRecordset = New-Object -comobject ADODB.Recordset 
    
    try {
        $objConnection.Open("Provider=SAS.LocalProvider;Data Source=`"$filePath`";")
        $objRecordset = $objConnection.OpenSchema($adSchemaColumns, $criteria)
        if ($objRecordset.EOF) {
            Write-Host "Error trying to open " $dataset.Fullname
        }
	  
        do {
            # build up a new object with the schema values
            $objectRecord = New-Object psobject

            # add file system properties for each record
            $objectRecord | add-member noteproperty `
                -name "File name" `
                -value $dataset.Name;
			
 
				
            $properties = @("COLUMN_NAME", "DESCRIPTION", "ORDINAL_POSITION", "DATA_TYPE", "CHARACTER_MAXIMUM_LENGTH", "FORMAT_NAME", "INFORMAT_NAME", "INDEXED")
            $propertiesDesc = @("Column", "Label", "Pos", "Type", "Length", "Format", "Informat", "Indexed")

				
            # Now read properties from "column schema" internal to data set    
            for ($i = 0; $i -lt $properties.Count; $i++) {
                $value = $objRecordset.Fields.Item($properties[$i]).Value
				
                if ($properties[$i] -eq "FORMAT_NAME") {
                    if ($value.Length -gt 0) {
                        $value = -join ($value, $objRecordset.Fields.Item("FORMAT_LENGTH").Value, ".")
                        if ( ($objRecordset.Fields.Item("DATA_TYPE").Value -eq 5) -and `
                            ($objRecordset.Fields.Item("FORMAT_DECIMAL").Value -gt 0) ) {
                            $value = -join ($value, $objRecordset.Fields.Item("FORMAT_DECIMAL").Value)
                        }
                    }
                }
				
                if ($properties[$i] -eq "INFORMAT_NAME") {
                    if ($value.Length -gt 0) {
                        $value = -join ($value, $objRecordset.Fields.Item("INFORMAT_LENGTH").Value, ".")
                        if ( ($objRecordset.Fields.Item("DATA_TYPE").Value -eq 5) -and `
                            ($objRecordset.Fields.Item("INFORMAT_DECIMAL").Value -gt 0) ) {
                            $value = -join ($value, $objRecordset.Fields.Item("INFORMAT_DECIMAL").Value)
                        }					
                    }
                }
				
                if ($properties[$i] -eq "DATA_TYPE") {
                    if ($value -eq 5) {
                        $value = "NUM"
                    }
                    if ($value -eq 129) {
                        $value = "CHAR"
                    }
                }
				
                # add static properties for each record
                $objectRecord | add-member noteproperty `
                    -name $propertiesDesc[$i] `
                    -value $value;
            }

            $objectRecord | add-member noteproperty `
                -name "Path" `
                -value $filePath;
			  
            $objectRecord | add-member noteproperty `
                -name "File time" `
                -value $dataset.LastWriteTime;
			 
            $objectRecord | add-member noteproperty `
                -name "File size" `
                -value $dataset.Length;   
			 
            # emit the complete record as output
            $objectRecord
            $objRecordset.MoveNext()
        }

        until ( $objRecordset.EOF )    
		
        $objRecordset.Close()
        $objConnection.Close()
    }
    catch {
        Write-Host "Unable to process schema for " $dataset.Fullname
        if (($null -ne $objConnection) -and ($objConnection.Errors.Count -gt 0)) {
            foreach ($adoError in $objConnection.Errors) {
                Write-Host $adoError.Description
            }
        }
        else {
            Write-Host $_.Exception.ToString()
        }
    }
    finally {
        if (($null -ne $objRecordset) -and ($objRecordset.State -ne 0)) {
            $objRecordset.Close()
        }
        if (($null -ne $objConnection) -and ($objConnection.State -ne 0)) {
            $objConnection.Close()
        }
    }	
}

