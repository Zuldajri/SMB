@{
	AllNodes = @(
		@{
			NodeName="*"
			RetryCount = 20
			RetryIntervalSec = 30
			PSDscAllowPlainTextPassword=$false
			PSDscAllowDomainUser = $true
		},
		@{ 
			NodeName = "localhost"
			Role = "DC-Primary","RDS-All"
		}
	)
}
