<# 
.DESCRIPTION 
	
.NOTES 
    File Name  : AD - Get All Servers in Active Directory
    Author     : blow_tech
.LINK 

#> 

Import-Module ActiveDirectory

Get-ADComputer -Filter 'operatingsystem -like "*server*" -and enabled -eq "true"' `
-Properties Name,Operatingsystem,OperatingSystemVersion,IPv4Address `
| Sort-Object -Property Operatingsystem `
| Select-Object -Property Name,Operatingsystem,OperatingSystemVersion,IPv4Address '
| Export-Csv C:\Report\server_dump.csv
