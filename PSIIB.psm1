$Script:PSModuleFullName = $PSCommandPath

"$PSScriptRoot\Functions\*.ps1" | Resolve-Path |
Where-Object {-not ($_.ProviderPath.ToLower().Contains(".tests."))} |
ForEach-Object { . $_.ProviderPath }