# Checkpoint

The user thinks you're drifting or overcomplicating. Stop and reset.

Output ONLY this format:

```
## Checkpoint

**Axioms:** (principles I'm treating as true)
- [how mechanism X works]
- [how mechanism Y works]
- ...

**Broken:** [one sentence - what's not working]

**Why:** [one sentence - must only reference axioms above]

**Fix:** [one sentence - what to change]
```

Rules:
- Every concept in "Broken", "Why", and "Fix" MUST be grounded in an axiom
- If you can't state it in one sentence, you don't understand it yet
- Wait for user to verify axioms before proceeding
- If user corrects an axiom: output a NEW checkpoint with corrected axioms (don't argue or elaborate)
- No implementation until checkpoint is approved
