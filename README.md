# Serverless prototype

Putting some technologies together as a prototype for my next project.

- Serverless - Azure Functions with a consumption plan
- NoSQL - CosmosDB with a MongoDB interface
- Cloud security - Azure Key Vault to encrypt and decrypt sensitive data, as well for getting secrets
- Infrastructure-as-code - Terraform

<img src="diagram.png" />


## Local develompent

_Required:_ [Azure Functions Core Tools](https://github.com/Azure/azure-functions-core-tools) and [Infrastructure](#Infrastructure) setup

Start here

```sh
. init.sh
```

Set environment variables in the `local.settings.json`

Start Functions locally

```sh
func host start
```

Load questions

```sh
curl localhost:7071/api/LoadQuestions
```

Post answers

```sh
curl --data "@shared_code/answers.json" http://localhost:7071/api/PostAnswers
```

Get answers

```sh
curl http://localhost:7071/api/GetAnswers?id=participant@mail.com
```

## Infrastructure

Create the infrastructure with `main.tf`. More info on how to setup Azure connectivity here: [Authenticating using a Service Principal](https://www.terraform.io/docs/providers/azurerm/guides/service_principal_client_secret.html)

```
terraform plan
terraform apply
```

### Local Development 

To setup the local environment create an Application Registration manually. (I didn't have the time to automate)

1. Create an Application Registration in Azure AD
2. Create a `Client Secret` for the app
3. Add the app credentials to `local.settings.json`
4. In the Key Vault add a `Access Policy` for the app with KEY operations `Get`, `Decrypt` and `Encrypt`

Keep in ming that this will not be tracked by Terraform and it will need to be recreated if `main.tf` is applied to the infrastructure (it will remove the app).

Terraform is declarative, meaning that "if else" is not an option so I'm leaving it manual for now. For real use cases this has to be added as extra configuration to Terraform.

## Cloud Deployment

The easiest way to test your app in the Cloud is using the [IDE plugin](https://docs.microsoft.com/en-us/azure/app-service/deploy-local-git) to perform the deployment. Using VS Code Azure plugin*, select the Function and deploy. For a step-by-step check it [here](https://github.com/microsoft/vscode-azurefunctions).

File `local.settings.json` is not deployed to the cloud. You need to set those variables in the `Configuration` blade and `App Settings` tab. Checkout the [Deploy](https://docs.microsoft.com/en-us/azure/azure-functions/functions-how-to-azure-devops?tabs=csharp) blade options to automate your deployment.

_*Current issue [#2108](https://github.com/microsoft/vscode-azurefunctions/issues/2108) will not allow deployment with WSL until fixed._

## Sources

[Azure Functions Python developer guide](https://docs.microsoft.com/en-us/azure/azure-functions/functions-reference-python) (must read)

[Azure KeyVault Keys - Python SDK](https://pypi.org/project/azure-keyvault-keys/)

[Azure Identity - Python SDK](https://github.com/Azure/azure-sdk-for-python/tree/master/sdk/identity/azure-identity)
