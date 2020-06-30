#
# get_projdeps.ps1
#
function get-csprojdeps
{
	[CmdletBinding()]
	param 
	(
		[parameter(Mandatory=$true)]
		[string] $path
	)
	return get-csprojdependencies (Get-Item $path).FullName
}