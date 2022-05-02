@{
	AllNodes = @(
		@{
			NodeName="*"
			RetryCount = 20
			RetryIntervalSec = 30
			PSDscAllowPlainTextPassword=$true
			PSDscAllowDomainUser = $true
		},
		@{ 
			NodeName = "localhost"
			Role = "RDS-Session"
		}
	)
}
