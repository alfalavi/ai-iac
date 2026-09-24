> [!WARNING]
> **WORK IN PROGRESS — Not ready for participants.**
>
> Pending before publishing:
>
> - [x] ~~Review with Matt/Kelli to confirm scope~~
> - [ ] Define if we will use the Slalom Org or AI-Accelerated-Engineering-Bootcamp
> - [ ] Get feedback from Claudia / SE labs creators
> - [ ] ~~Decide if we want to use the Innovation Labs to allow actual infra deployment (cleanup is fast via `terraform destroy` or a teardown script)~~ : MVP - Terrafom plan, next phase use Innovation Labs
> - [ ] If Innovation Labs: decide AWS credentials strategy:
>       ~~- **Option 1 — Org-level secrets:** set secrets once at the GitHub org level; all participant repos inherit them automatically~~
>   - **Option 2 — OIDC (recommended):** configure a single IAM role that trusts the GitHub org; no credentials to copy or rotate, short-lived tokens only, will limit to repos with the appropiate naming convention, resources will be automatically destroyed after lab completion.
