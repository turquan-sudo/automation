New-AzPolicyDefinition -Policy "path to policy.json" -Parameter "path to policy.parameters.json" `
-Name "Deploy Windows Domain Join Extension with keyvault configuration" `
-Description "Deploy Windows Domain Join Extension with keyvault configuration when the extension does not exist on a given windows Virtual Machine"