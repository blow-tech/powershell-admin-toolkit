<# Read-only TCP connection attempts to explicit hosts. This produces real network traffic when run;
run only in an approved diagnostic window. UDP is not implemented and is explicitly NotAssessed.
No implicit forest discovery. Results do not prove LDAP bind, DNS resolution or service readiness. #>
[CmdletBinding()]
param([Parameter(Mandatory)][ValidateCount(1,16)][string[]]$ComputerName,[ValidateRange(1,65535)][int[]]$TcpPort=@(135,139,445,389,636,3268,3269,88,53),[ValidateRange(100,10000)][int]$TimeoutMilliseconds=2000)
$ErrorActionPreference='Stop'
if($TcpPort.Count -gt 32){throw 'At most 32 ports per invocation.'}
$failed=$false
foreach($computer in ($ComputerName | Sort-Object -Unique)){
 foreach($port in ($TcpPort | Sort-Object -Unique)){
  $client=New-Object Net.Sockets.TcpClient;$pending=$null;$state='UNKNOWN';$detail=''
  try{$pending=$client.BeginConnect($computer,$port,$null,$null);if(-not $pending.AsyncWaitHandle.WaitOne($TimeoutMilliseconds)){throw 'Timed out'};$client.EndConnect($pending);$state='Connected'}
  catch{$failed=$true;$detail=$_.Exception.Message}
  finally{if($pending){$pending.AsyncWaitHandle.Close()};$client.Close()}
  [pscustomobject]@{ComputerName=$computer;Port=$port;Protocol='TCP';State=$state;Details=$detail}
 }
 [pscustomobject]@{ComputerName=$computer;Port=$null;Protocol='UDP';State='NotAssessed';Details='No UDP validation is implemented.'}
}
if($failed){throw 'One or more TCP attempts were unavailable. Retain the partial evidence; do not infer a service failure solely from connectivity.'}
