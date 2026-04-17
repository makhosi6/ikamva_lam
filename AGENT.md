- With every task completion, the agent should update the task completion status in `./TASKS.md`.
- With every task completion, make a **git commit** with:
  - **Short message** (first line): imperative, scoped when helpful, e.g. `feat(learner): …` or `fix(db): …`.
  - **Longer description** (commit body): what changed, why it matters, and notable files or risks. Prefer multiple `-m` flags so the body is separate from the subject.
- When necessary, increment the version of the project in `./learner_app/pubspec.yaml` and `./learner_app/lib/version.dart` and create a new tag with the version number (as per semantic versioning rules)


Example:

```bash
git commit -m "feat(learner): add cloze JSON validation" -m "Introduce ClozePayload and validators for TASKS 3.1 and 3.5." -m "Reject empty options and enforce per-level word-count caps."
```
