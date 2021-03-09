

## Prerequisites

- [Auth0 account](https://auth0.com/)


## Instructions

- Clone this repository:
```shell
git clone git@github.com:dlavric/oidc-vault.git
```

- Execute start-vault.sh:
```shell
$ chmod +x start-vault.sh
$ ./start-vault.sh
```

- Export the vault variables:
```shell
# export the environment variable
$ export VAULT_ADDR="http://127.0.0.1:8200"

# export the environment variable through OIDC interface
$ export VAULT_OIDC_ADDR="http://127.0.0.1:8250"

# export the env variable to authenticate with Vault
$ export VAULT_TOKEN=root
```

1. In the Auth0 dashboard, select Applications.

2. Select Default App and Settings. Dashboard

3. Copy the Domain.

4. In the terminal, set the variable AUTH0_DOMAIN to the Domain:
```shell
$ export AUTH0_DOMAIN=<Domain>
```

5. Copy the Client ID.

In a terminal, set the variable AUTH0_CLIENT_ID to the Client ID.
```
$ export AUTH0_CLIENT_ID=<Client ID>
```

6. Copy the Client Secret.

In a terminal, set the variable AUTH0_CLIENT_SECRET to the Client Secret.
```
$ export AUTH0_CLIENT_SECRET=<Client Secret>
```

7. In Auth0, in the Allowed Callback URLs field, enter the following:
```shell
# address enables the Vault CLI to login via the OIDC method
http://localhost:8250/oidc/callback,
http://127.0.0.1:8250/oidc/callback,

# address enables the Vault web UI to login via the OIDC method.
http://localhost:8200/ui/vault/auth/oidc/oidc/callback,
http://127.0.0.1:8200/ui/vault/auth/oidc/oidc/callback
```

- Execute vault-policies.sh:
```shell
$ chmod +x vault-policies.sh
$ ./vault-policies.sh
```

### Enable oidc auth method

- Enable the oidc auth method at the default path.
```shell
$ vault auth enable oidc
```

- Configure the oidc auth method.
```shell
$ vault write auth/oidc/config \
         oidc_discovery_url="https://$AUTH0_DOMAIN/" \
         oidc_client_id="$AUTH0_CLIENT_ID" \
         oidc_client_secret="$AUTH0_CLIENT_SECRET" \
         default_role="reader"
```

- Create the reader role.
```shell
$ vault write auth/oidc/role/reader \
      bound_audiences="$AUTH0_CLIENT_ID" \
      allowed_redirect_uris="http://localhost:8200/ui/vault/auth/oidc/oidc/callback" \
      allowed_redirect_uris="http://localhost:8250/oidc/callback" \
      user_claim="sub" \
      policies="reader"
```

- Login with OIDC
```shell
$ vault login -method=oidc role="reader"
```

**NOTE**: When prompted, accept and authorize the Vault access to your Default App.

- Access Vault UI by opening your browser and type the following URL:
```
localhost:8200/ui
```

### Create an Auth0 group

- In the Auth0 dashboard, select Users & Roles > Users.

- Click on your user name.

- Enter the following metatada in the app_metadata.
```
{
  "roles": ["kv-mgr"]
}
```

When this user authenticates, this metadata is provided to Vault in the callback. Vault requests a token from the Vault group named kv-mgr.

- Click SAVE.

### Config OIDC

- From the side navigation, select Rules.

- Click CREATE RULE.

- Select empty rule.

- Enter Set user role in the Name field.

- Enter the following script in the Script field.
```shell
function (user, context, callback) {
  user.app_metadata = user.app_metadata || {};
  context.idToken["https://example.com/roles"] = user.app_metadata.roles || [];
  callback(null, user, context);
}
```

### Create an external Vault group

- Login as the root user.
```shell
$ vault login root
```

- Create a role named kv-mgr.
```shell
$ vault write auth/oidc/role/kv-mgr \
         bound_audiences="$AUTH0_CLIENT_ID" \
         allowed_redirect_uris="http://localhost:8200/ui/vault/auth/oidc/oidc/callback" \
         allowed_redirect_uris="http://localhost:8250/oidc/callback" \
         user_claim="sub" \
         policies="reader" \
         groups_claim="https://example.com/roles"
```

- Create an external group, named manager with the manager policy.
```shell
$ vault write identity/group name="manager" type="external" \
         policies="manager" \
         metadata=responsibility="Manage K/V Secrets"
```

Example output:
```
Key     Value
---     -----
id      f5307018-a573-c8be-cfde-a183ac408513
name    manager
```

- Create a variable named GROUP_ID to store the id of the manager group.
```shell
$ GROUP_ID=$(vault write -field=id identity/group name="manager" type="external" \
         policies="manager" \
         metadata=responsibility="Manage K/V Secrets")
```

- Create a variable named OIDC_AUTH_ACCESSOR to store the accessor of the oidc authentication method.
```shell
$ OIDC_AUTH_ACCESSOR=$(vault auth list -format=json  | jq -r '."oidc/".accessor')
```

- Create a group alias named kv-mgr.
```shell
$ vault write identity/group-alias name="kv-mgr" \
         mount_accessor="$OIDC_AUTH_ACCESSOR" \
         canonical_id="$GROUP_ID"
```

- Log in with the oidc method as role of a kv-mgr.
```shell
$ vault login -method=oidc role="kv-mgr"
```