# Product model contract

`product/PRODUCT.yaml` is the machine-readable source of truth. Keep prose explanations in `UX_DECISIONS.md`; do not duplicate the same state in multiple files.

Required top-level keys:

```yaml
schema_version: "1.0"
product:
  name: ""
  goal: ""
  platform: web
evidence:
  - id: evidence-001
    source: sketches/example.png
    confidence: confirmed # confirmed | inferred | proposed
    statement: ""
roles: []
entities: []
screens:
  - screen_id: screen-home
    name: Home
    purpose: ""
    states:
      - state_id: state-home-ready
        type: ready # loading | empty | ready | error | success
    actions:
      - action_id: action-open-item
        label: Open item
        from_state_id: state-home-ready
        to_screen_id: screen-detail
flows:
  - flow_id: flow-primary
    actor: user
    goal: ""
    steps:
      - screen_id: screen-home
        action_id: action-open-item
acceptance_criteria: []
open_questions: []
```

Rules:

- IDs are lowercase kebab-case and remain stable across revisions.
- Every interactive prototype screen maps to one `screen_id`.
- Every primary control maps to one `action_id`; every transition names its target screen/state.
- `confirmed` comes directly from supplied evidence, `inferred` is a conservative interpretation, and `proposed` is a design decision.
- Unresolved questions that materially alter the primary flow block handoff; cosmetic questions do not.
