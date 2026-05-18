# PowerShell Script Header Templates
# Copy the relevant block to the top of each script — above any param() block.
# Fill in the fields. Remove sections you don't need.

# =============================================================================
# TEMPLATE — General use (most scripts)
# =============================================================================

<#
.SYNOPSIS
    One sentence. What does this script do?

.DESCRIPTION
    Two to four sentences. Expand on the synopsis — what problem it solves,
    what data source it queries, what it outputs, and any key behaviour
    the operator should know before running it.

.PARAMETER ParameterName
    What this parameter does. Include the default value if there is one.

.PARAMETER AnotherParameter
    Description of this one.

.EXAMPLE
    .\YourScript.ps1 -ParameterName "value"

    What this example does — one line of context.

.EXAMPLE
    .\YourScript.ps1 -ParameterName "value" -AnotherParameter 30

    What the second example demonstrates.

.NOTES
    Author:   blow-tech
    Version:  1.0
    Requires: PowerShell 5.1+, RSAT ActiveDirectory module
    Repo:     https://github.com/blow-tech/powershell-admin-toolkit

.LINK
    https://github.com/blow-tech/powershell-admin-toolkit
#>


# =============================================================================
# EXAMPLE — Get_MFA_Status.ps1 (filled-in version)
# =============================================================================

<#
.SYNOPSIS
    Reports MFA registration status for all Entra ID users.

.DESCRIPTION
    Connects to Microsoft Graph and retrieves the authentication methods
    registered for every Entra ID user account. Identifies accounts with no
    MFA methods registered and exports results to CSV. Designed for compliance
    audits and MFA adoption tracking in M365 environments.

.PARAMETER OutputPath
    Full path for the CSV output file.
    Default: .\MFA_Status_Report.csv in the current working directory.

.PARAMETER AllUsers
    Switch. When specified, includes all users regardless of MFA status.
    Default behaviour: reports only users with no MFA registered.

.EXAMPLE
    .\Get_MFA_Status.ps1

    Runs with defaults. Exports users with no MFA to .\MFA_Status_Report.csv.

.EXAMPLE
    .\Get_MFA_Status.ps1 -OutputPath "C:\Reports\MFA_Status.csv" -AllUsers

    Exports MFA status for every user to the specified path.

.NOTES
    Author:   blow-tech
    Version:  1.0
    Requires: PowerShell 5.1+, Microsoft.Graph module
    Permissions: UserAuthenticationMethod.Read.All (Graph API)
    Repo:     https://github.com/blow-tech/powershell-admin-toolkit

.LINK
    https://github.com/blow-tech/powershell-admin-toolkit
#>


# =============================================================================
# EXAMPLE — Get-LockedOutLocation.ps1 (filled-in version)
# =============================================================================

<#
.SYNOPSIS
    Identifies the source machine responsible for an AD account lockout.

.DESCRIPTION
    Queries Security event logs (Event ID 4740) across all reachable domain
    controllers to locate where an account lockout originated. Returns the
    calling machine name, DC that recorded the event, and timestamp.
    Useful for diagnosing repeated lockouts caused by stale credential caches,
    mapped drives, or scheduled tasks.

.PARAMETER Username
    The SAMAccountName of the locked-out user account. Required.

.PARAMETER DomainController
    Optional. Target a specific DC instead of querying all DCs.
    Default: queries all DCs returned by Get-ADDomainController.

.EXAMPLE
    .\Get-LockedOutLocation.ps1 -Username jsmith

    Queries all DCs for lockout events related to jsmith.

.EXAMPLE
    .\Get-LockedOutLocation.ps1 -Username jsmith -DomainController DC01

    Queries only DC01 for lockout events.

.NOTES
    Author:   blow-tech
    Version:  1.0
    Requires: PowerShell 5.1+, RSAT ActiveDirectory module
    Permissions: Read access to Security event logs on domain controllers
    Repo:     https://github.com/blow-tech/powershell-admin-toolkit

.LINK
    https://github.com/blow-tech/powershell-admin-toolkit
#>


# =============================================================================
# NOTES ON USAGE
# =============================================================================
#
# Place the <# ... #> block ABOVE the param() block at the top of the script.
# PowerShell reads comment-based help before execution, so position matters.
#
# Correct structure:
#
#   <#
#   .SYNOPSIS
#       ...
#   #>
#   [CmdletBinding()]
#   param(
#       [string]$OutputPath = ".\report.csv"
#   )
#
# Once headers are in place, Get-Help works automatically:
#
#   Get-Help .\Get_MFA_Status.ps1
#   Get-Help .\Get_MFA_Status.ps1 -Examples
#   Get-Help .\Get_MFA_Status.ps1 -Full
#
# =============================================================================
