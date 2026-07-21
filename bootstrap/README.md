# Bootstrap (one-time, operator-run)

Applied once from an operator machine with human AWS credentials. Creates the
Terraform state bucket, the GitHub OIDC provider, and the `acme-ci-deploy` role.
After this, **no human laptop ever applies the main stack again** — CI does.

```sh
cd bootstrap
terraform init
terraform plan    # review
terraform apply   # operator approves
```

State for this stack is local and gitignored. The main stack backend
(`terraform/backend.tf`) points at the `acme-tfstate-<account>` bucket this
creates.
