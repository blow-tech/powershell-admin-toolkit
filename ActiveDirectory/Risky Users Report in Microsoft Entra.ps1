# Deprecated duplicate entry point: performs no Graph queries.
# Schedule only Get_Risky_User-Report.ps1. This prevents duplicate collection when both legacy paths are scheduled.
throw 'This duplicate script is retired. Update the scheduled task to Get_Risky_User-Report.ps1 -TenantId <TenantId>. Add -IncludeHistory only if needed.'
