# MicrosoftProjectFieldBug

An issue of ProjectServer - more specifically in the lists of the projects.


## Motivation

ContentTypes on SiteCollection level can be used in lists. Changes to SiteCollection - ContentType are propagated to the lists.
For the ProjectServer's lists, there are ContentTypes on the list, but not the corresponding SiteCollection ContentType.
This is more than just beauty. Example: If you use templates and add your own fields and want to change the order, that does not work.

## The Problem

![ProjectServer Issue ContentType](./ListSettings.png)

Steps to see whats going on
- Go to a project site (OnPremise 2013/2016 or Office365)
- go to an issue list, to the list settings
- Activate "Allow management of content types".
- under ContentType: Open the Issue - ContentType

Where is the problem?

Go to the ParentContentType - you see Item. This is strange. Why? For this I must now take a little.
(In addition, no value is displayed under Source.)

## I'm sitting here in a boring room

    The ProjectServer lists in SharePoint have those ContentTypes: 


|  Name | ContentTypeId  |
|-------|----------------|
| $Resources:pws,CType_PWS_Commitment | 0x010074416DB49FB844b99C763FA7171E7D1F|
| $Resources:pws,CType_PWS_Document | 0x0101008A98423170284beeB635F43C3CF4E98B|
| $Resources:pws,CType_PWS_Issue | 0x0100DD9A1416BBC74a968F6E648718051133|
| $Resources:pws,CType_PWS_Risk | 0x010024290FBE2869495eB819832776560730|


*Remarks:*

1) The names are in the SharePoint format for internationalization.
2) The ContentTypeId is hierarchical. A ContentType has an parent (except for the root ContentType 0x system).
   The format of the ContentTypeIds is described in https://msdn.microsoft.com/en-us/library/office/aa543822(v=office.14).aspx.

The Issue - ContentType (0x0100DD9A1416BBC74a968F6E648718051133) has  Item(0x01) as Parent.

A ContentType in a list has an parent. If this ContentType is specific to this list, it is the ContentType "Item" (0x01) - (or something like that).
SharePoint can also share ContentTypes for lists. To do this, a child of the ContentType is appended to the list.
So the ContentType of the list has the ContentTypeId 0x0100DD9A1416BBC74a968F6E64871805113300GUID.

The "Issue" ContentType of the list does not have this - because he has directly referred to "Item" (0x01).
If you do not know exactly what I mean, create your own ContentType and a list and look at the situation there.

Looking more closely at the "Issue" ContentType, one finds that the ContentTypeId is 0x0100DD9A1416BBC74a968F6E64871805113300GUID.
You can either try SharePointManger - http://spm.codeplex.com
or look more closely at the URL for editing the ContentType.<br/>
The page from which the screenshot was taken is: .../PWSFieldBug/_layouts/15/start.aspx#/_layouts/15/ManageContentType.aspx?List=...ctype=0x0100DD9A1416BBC74A968F6E648718051133008F14FA0EBB1CBA4E8E5318D2DE914FD1<br/>
The ctype Paremeter is the ContentTypeId.
If we walk through the hierarchy above:
- 0x0100DD9A1416BBC74A968F6E648718051133008F14FA0EBB1CBA4E8E5318D2DE914FD1  The ContentTypeId of the List ContentType.
- 0x0100DD9A1416BBC74A968F6E648718051133 The ContentTypeId of the SiteCollection ContentType.
- 0x01 - Item

## Forgotten Sons

    Why is this ContentType missing? Why do the lists work?

The ContentTypes are part of a feature.
The PWSCTypes (PWSCTypes \ pwsctypes.xml) feature defines the ProjectServer ContentTypes.

Unfortunately, you can not enable the feature because it has a dependency on the PWSFields feature.

And PWSFields feature can not be activated because it uses names already given to Fields.
Pwsfields.xml defines the fields that are referenced in the ContentTypes via FieldRefs.


## The Naming of Cats is a difficult matter

    A SharePoint Field (aka Column) has 3 names: Name, StaticName, and DisplayName.

The SharePoint SDK provides a not helpful explanation: https://msdn.microsoft.com/en-us/library/aa979575(v=office.15).aspx

A not little clear explanation is:

The name must be unique.
The different APIs do not always use the same name, where DisplayName is sometimes language-dependent.

A Field "Description" is defined in FEATURES\fields\fieldswss3.xml:

```XML
<Field ID="{3f155110-a6a2-4d70-926c-94648101f0e8}"
        Name="Description" />
```

A Field "Description" is defined in FEATURES\PWSFields\pwsfields.xml:
```XML
  <Field ID="413213C2-3E91-4dc8-9D47-216B83AB8027"
      Name="Description" />
```

The ID is different, but "Name" has the same value - both features can not be enabled at the same time. 
And FEATURES\fields is always activated (and must also, because there are all core fields in it).

## Hello is there anybody in there?

    So why does the whole thing work at all?


Well, a SharePoint list under WSS2 did not have any ContentTypes. There were only the fields in the list.
WSS3 has brought ContentTypes. A field in the ContentType also has a field in the list.
If you define a list in CAML you can define the definition under "Fields".
If you want to use specific SiteCollection - ContentTypes, you can include them using ContentTypeRef.
You can also do both.
If you look more closely at "TEMPLATE\FEATURES\PWSIssues\PWSISSUE\schema.xml", this is done.

The fields are there, the ContentType is used without existing.

## No, Woman, No Cry

A few solutions to this can be found on the net, these delete and wildly create any lists, ContentTypes ...

The approach proposed here aims to generate the Fields and the ContentType as close as possible to the original definition.

The basis for this is https://github.com/OfficeDev/PnP-powershell and the definitions of SharePoint.

The idea:

- Adapt the definitions of the fields, so that name conflicts no longer occur (pws as a prefix for the names), which adapt FieldRefs and formulas
- Create the fields with the modified defnition.
- Create the ContentTypes.
- Add the Fields to the ContentType.

Here we go.

- Install https://github.com/OfficeDev/PnP-powershell.
- Open the script in the ISE.
- Adjust the value for $url - specify the SiteCollection to which you want to change it.
- If necessary, adjust the paths according to SharePoint version.
- Run the script.
- Testing.

The script must be configured.

```powershell
# 
$url = "https://your/pwa"
$fieldsFileNameSP = "C:\Program Files\Common Files\microsoft shared\Web Server Extensions\15\TEMPLATE\FEATURES\PWSFields\pwsfields.xml"
$ctypesFileNameSP = "C:\Program Files\Common Files\microsoft shared\Web Server Extensions\15\TEMPLATE\FEATURES\PWSCTypes\pwsctypes.xml"

function fixPWSFieldBug(){ ...  }

Connect-PnPOnline -Url $url
fixPWSFieldBug
```

## Ade zur guten Nacht

I hope you find it helpful.

Please test yourself.
