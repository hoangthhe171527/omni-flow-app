# Repository Instructions

## Shipping

- `main` is the single integration and primary branch.
- Create a short-lived branch from `origin/main`, open a pull request into `main`, merge with a merge commit, then delete the short-lived branch.
- Do not use a separate `develop` branch for this repository.
- Pull request titles and descriptions may be written in Vietnamese.

## Production Deploy

- Merging source code does not publish a mobile build to either store.
- Build and store-release steps are documented in `docs/PHAT_HANH.md` and `.github/workflows/release.yml`.
- Store uploads and review submissions are deliberate release actions and must use a new build number.
