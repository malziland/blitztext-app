# GitHub Settings Checklist

These settings are not stored in the repository. They are optional hygiene for running this fork on GitHub.

## Recommended For This Fork

- Enable Dependabot alerts.
- Enable secret scanning.
- Enable push protection for supported secret types.
- Keep GitHub Actions permissions read-only by default.
- Do not add repository secrets unless they are truly needed.

## If The Repository Becomes Public

- Make the fork relationship clear in the repository description.
- Keep Issues enabled only if you want to receive fork-specific bug reports.
- Direct general upstream issues to `cmagnussen/blitztext-app`.
- Enable private vulnerability reporting when available.
- Add topics only if they accurately describe the fork, such as `macos`, `swift`, `speech-to-text`, and `openai`.

## Optional Branch Protection

For a personal fork, strict branch protection is optional. If more people contribute, protect `main`:

- require pull request before merge
- require at least one approval
- dismiss stale approvals when new commits are pushed
- block force pushes
