# grants/ — earned, temporary access (access-as-code)

This directory is where Pumpkin's authored Terraform grant files land, one file
per approved task. Pumpkin opens the PR; a human reviews and merges; CI applies.
Pumpkin **never** merges, never applies, never mutates IAM directly.

## House rules — a grant PR is rejected unless ALL hold

1. **Tight resource ARNs.** Exact function/bucket/object ARNs. No `*` anywhere —
   not in actions, not in resources, not in principals.
2. **Trust exactly one principal:** the runtime identity
   `arn:aws:iam::488179516291:role/acme-pumpkin-runtime`, with an `sts:ExternalId`
   condition.
3. **Self-expiring, ≤ 24 h.** The trust policy MUST carry an
   `aws:CurrentTime` `DateLessThan` upper bound no more than 24 hours out.
   Expired grants are dead code; a cleanup PR removes them.
4. **No `iam:*`.** A grant may never contain IAM actions of any kind.
5. **Dev resources only.** Anything named `*-prod-*` or tagged `env=prod` is
   out of bounds. The prod decoys exist to catch exactly this.
6. **One task, one file, one role.** Name the file and role after the ticket:
   `grant-<ticket>-<verb>.tf` / `acme-grant-<ticket>`.

See `examples/lambda-invoke-grant.tf.example` for the canonical shape (the
`.example` suffix keeps it inert — rename inside a PR to activate a real one).

## Lifecycle

open PR → human review (CODEOWNERS) → merge → CI `terraform apply` → Pumpkin
assumes the role for the approved run → expiry passes → revocation/cleanup PR
deletes the file → CI apply removes the role.
