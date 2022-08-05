# VM Join Policy

## Setup
1. Configure AD Service Account for domain join. Scope delegated domain join access to specific OU's
2. Create a keyvault to store the AD account and credentials. Add two secrets to the keyvault, 1-username (fqdn) 2-password
3. Create a User defined managed Identity, give this MI access to get and secrets from the created keyvault
4. run azcmd.ps1 with your environmental parameters
5. Assign definition to target scope Username and password fields should match the keyvault secret key rather than specifying the username and password explicitly.


## Troubleshooting
If the extension installation fails please review the resource deployment log, for more detailed information please review the target machines event log. Also check c:\Windows\Debug for verbose join information
