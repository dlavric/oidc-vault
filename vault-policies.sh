# manager.hcl policy
tee manager.hcl <<EOF
# Manage k/v secrets
path "/secret/*" {
    capabilities = ["create", "read", "update", "delete", "list"]
}
EOF

# reader.hcl policy
tee reader.hcl <<EOF
# Read permission on the k/v secrets
path "/secret/*" {
    capabilities = ["read", "list"]
}
EOF

# create a policy named manager with the policy defined in manager.hcl.
vault policy write manager manager.hcl

# create a policy named reader with the policy defined in reader.hcl.
vault policy write reader reader.hcl

# list all the policies.
vault policy list
