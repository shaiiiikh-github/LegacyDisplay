# Development & Contribution Workflow

This document outlines the workflow and policies for contributing to **LegacyDisplay**.

---

## 1. Branching Policy

- **Protected Main Branch**: Direct commits and direct pushes to `main` are strictly prohibited during normal development.
- **Ruleset**: GitHub repository rules enforce pull request verification and status check passing before any merge into `main`.
- **Local Guardrails**: Pre-commit and pre-push Git hooks are located in `.githooks/` and will block unintentional commits or pushes directly on `main`.

---

## 2. Feature Branch Lifecycle

All feature development and bug fixes must follow the standard Git branch → PR lifecycle:

### Step 1: Create a Feature Branch
Ensure your local `main` is up to date, then branch off:
```bash
git checkout main
git pull origin main
git checkout -b feature/<descriptive-name>
```

### Step 2: Implement and Test
- Write clean Swift code adhering to UIKit best practices.
- Add corresponding unit tests in `LegacyDisplayTests/`.
- Verify your changes locally if running on a macOS environment.

### Step 3: Commit Changes
Commit with descriptive, conventional messages:
```bash
git add .
git commit -m "feat(display): add screen configuration preview controller"
```

### Step 4: Push to Remote
Push your branch to GitHub:
```bash
git push -u origin feature/<descriptive-name>
```

### Step 5: Open a Pull Request
Use the GitHub CLI (`gh`) or GitHub web interface:
```bash
gh pr create --base main --head feature/<descriptive-name> --title "Feature: <Title>" --body "<Summary>"
```

### Step 6: Automated CI Verification
- GitHub Actions triggers automatically on your PR using the `macos-14` runner.
- The pipeline executes:
  - Xcode selection (`Xcode 15.4` / `16.0`)
  - Target build (`xcodebuild clean build`)
  - Full unit test suite (`xcodebuild test`)
- All checks must pass before the PR can be merged.

### Step 7: Review & Merge
- Once CI has completed successfully, the PR can be reviewed and merged.
- PRs must **not** be merged automatically without human review/confirmation.

---

## 3. Git Hooks Configuration

To enable the included Git guardrails for local development:
```bash
git config core.hooksPath .githooks
```
This protects developers against accidental modifications to `main`.
