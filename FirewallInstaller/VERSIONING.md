# Versioning

This project uses git tags for released versions.

## Tag format

Recommended format:
- `vMAJOR.MINOR` or `vMAJOR.MINOR.PATCH`
  - Examples: `v1.0`, `v1.1`, `v1.0.1`

## Meaning

- **MAJOR**: breaking changes (installer layout changes, schema changes, behavior changes that require manual migration)
- **MINOR**: backward-compatible features (new alerts, new tests, new modules that dont break existing flows)
- **PATCH**: backward-compatible fixes (bug fixes, notifier fixes, reliability improvements)

## Release workflow

1. Ensure working tree is clean:
   - `git status`
2. Commit all intended changes.
3. Create an annotated tag:
   - `git tag -a v1.1 -m "HIPS v1.1"`
4. Push commits and tags:
   - `git push`
   - `git push --tags`

## Updating a tag

Tags should be treated as immutable release markers. If you must move a tag (avoid if possible):

- `git tag -f -a v1.0 -m "HIPS v1.0 (moved)"`
- `git push -f origin v1.0`

## Planning

- Current baseline: `v1.0`
- Next major: `v2.0` (created when breaking changes are introduced)
