# Contributing

## Ground rules
- Work from repo state, not remembered chat context.
- Prefer small, direct changes over parallel feature paths.
- Keep the demo bounded, local-first, and honest.
- Do not add placeholder security claims or fake integrations.

## Code change discipline
1. Check the current task list.
2. Change the smallest correct layer.
3. Reuse existing demo runners, tasks, and views when they already exist.
4. Run the narrowest meaningful verification after each change.
5. Update docs when behavior or operator expectations change.

## Verification discipline
- Format before reporting completion.
- Run focused tests first.
- For integration-tagged tests, include the tag explicitly when needed.
- Report exact commands run and any exclusions/limitations.

## Demo discipline
- Preserve bounded terminal output.
- Keep demo language explicit about simulation and local-only scope.
- Do not imply production readiness.
