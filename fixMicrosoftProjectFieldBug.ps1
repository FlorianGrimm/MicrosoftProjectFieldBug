#
# modify as needed
#

$url = "https://your/pwa"
$fieldsFileNameSP = "C:\Program Files\Common Files\microsoft shared\Web Server Extensions\15\TEMPLATE\FEATURES\PWSFields\pwsfields.xml"
$ctypesFileNameSP = "C:\Program Files\Common Files\microsoft shared\Web Server Extensions\15\TEMPLATE\FEATURES\PWSCTypes\pwsctypes.xml"

#

function fixPWSFieldBug(){
    # load pwsfields.xml
    $doc = New-Object -TypeName "System.Xml.XmlDocument"
    $doc.Load($fieldsFileNameSP)
    $fields = $doc.DocumentElement.Field

    $fields | %{
        $field = $_
    
        $fieldName = $field.Name
        $pwsFieldName = "pws"+$fieldName

        $field.SetAttribute("Name", $pwsFieldName)
        $field.SetAttribute("StaticName", $fieldName)
    }

    $fields | %{
        $field = $_
        $formula = $field.Formula
        if ($formula -ne $null){
            $formula = $formula.Replace("=Probability*", "=pwsProbability*pws")
            $field.Formula = $formula
        }
        $fieldRefs = $field.FieldRefs.FieldRef
        if ($fieldRefs -ne $null) {
            $fieldRefs | % {
                $fieldRef = $_
                $fieldRefName = $fieldRef.Name
                if (-not $fieldRefName.StartsWith("pws")){ $fieldRefName = "pws$($fieldRefName)" }
                $fieldRef.Name = $fieldRefName
            }
        }
    }

    $fields | %{
        $field = $_
        $fieldName = $field.Name
        $xml = $field.OuterXml       
        $pnpfield = $null
        $pnpfield = Get-PnPField -Identity $fieldName -ErrorAction SilentlyContinue
        if ($pnpfield -eq $null){
            Write-Host "- create $($fieldName) with $($xml)"
            Add-PnPFieldFromXml -FieldXml $xml
        } else {
            Write-Host "- $($fieldName) exists"
        }
        
    }

    $fieldbyid = @{}    
    $fields | %{
        $field = $_
        $fieldID = $field.ID
        if ($fieldID -ne $null){
            $id = new-object -typename "system.guid" -argumentlist @(,$fieldID)
            $fieldbyid[$id] = $field
        } else {
            Write-Host "??? $(field.Name) "
        }
    }
    $doc = New-Object -TypeName "System.Xml.XmlDocument"
    $doc.Load($ctypesFileNameSP)
    $ContentTypes=$doc.DocumentElement.ContentType
    $ctx = Get-PnPContext
    $ContentTypes | % {
        $ContentType = $_
        $FieldRef = $null
       
        $pnpContentType = Get-PnPContentType -Identity ($ContentType.ID)
        if ($pnpContentType -eq $null){        
            Write-Host "- Add ContentType $($ContentType.Name)"
            $pnpContentType = Add-PnPContentType -ContentTypeId ($ContentType.ID) -Name ($ContentType.Name) -Group ($ContentType.Group)
        } else {
            Write-Host "- Already exists ContentType $($ContentType.Name)"
        }

        $ctx.Load($pnpContentType.FieldLinks)
        $ctx.ExecuteQuery()
        $pnpContentTypeFieldLinks = @{}        
        $pnpContentType.FieldLinks | %{
            $FieldLink = $_            
            $pnpContentTypeFieldLinks[$FieldLink.Id] = $FieldLink
        }

        $ContentType.FieldRefs.FieldRef | %{
            $FieldRef = $_            
            $id = new-object -typename "system.guid" -argumentlist @(,($FieldRef.ID))            
            if ($pnpContentTypeFieldLinks[$id] -eq $null){
                Write-Host "- Add ContentType Field $($ContentType.Name) - $($FieldRef.ID) - $($FieldRef.Name)"
                $field = Get-PnPField -Identity $id                        
                Add-PnPFieldToContentType -Field $field -ContentType $pnpContentType
            } else {
                Write-Host "- Already exists ContentType Field $($ContentType.Name) - $($FieldRef.ID) - $($FieldRef.Name)"
            }
        }        
    }
}

#
Connect-PnPOnline -Url $url
fixPWSFieldBug
#