<# Read-only bounded dfsrdiag evidence for explicitly named hosts. Requires Windows DFS tools
and appropriate remote read permissions; no forest discovery or automatic export. #>
[CmdletBinding()]
param([Parameter(Mandatory)][ValidateCount(1,16)][ValidatePattern('^[A-Za-z0-9][A-Za-z0-9.-]*$')][string[]]$ComputerName,[ValidateRange(1,300)][int]$TimeoutSeconds=60)
$ErrorActionPreference='Stop'
$command=(Get-Command dfsrdiag.exe -CommandType Application -ErrorAction Stop).Source
$rows=@(foreach($computer in ($ComputerName | Sort-Object -Unique)){
 $process=$null
 try{
  $info=New-Object Diagnostics.ProcessStartInfo
  $info.FileName=$command;$info.Arguments="ReplicationState /member:$computer /all";$info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
  $process=New-Object Diagnostics.Process;$process.StartInfo=$info;$null=$process.Start()
  $stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
  if(-not $process.WaitForExit(1000*$TimeoutSeconds)){$process.Kill();$null=$process.WaitForExit(5000);throw 'DFSR diagnostic timed out.'}
  if(-not $stdout.Wait(5000) -or -not $stderr.Wait(5000)){throw 'DFSR output stream did not close.'}
  if($process.ExitCode -ne 0){throw "DFSR diagnostic failed ($($process.ExitCode)): $($stderr.Result)"}
  [pscustomobject]@{ComputerName=$computer;ExitCode=$process.ExitCode;RawEvidence=$stdout.Result;Health='NotAssessed'}
 } finally{if($process){$process.Dispose()}}
})
$rows
