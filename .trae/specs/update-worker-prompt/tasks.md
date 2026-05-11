# Tasks - Update Worker Prompt

## Task Dependencies
- All tasks depend on Task 1 (reading current prompt)
- Task 3 requires spec.md to be completed first

---

- [ ] Task 1: Read current worker prompt at `prompts/worker.md` and understand existing structure
  - [ ] SubTask 1.1: Read the full file content
  - [ ] SubTask 1.2: Identify all major sections and their boundaries
  - [ ] SubTask 1.3: Note existing permission boundaries and rules

- [ ] Task 2: Write `spec.md` documenting the required changes (see `/workspace/.trae/specs/update-worker-prompt/spec.md`)
  - [ ] SubTask 2.1: Document new Step 0 requirements
  - [ ] SubTask 2.2: Document evolve.sh sole execution path rule
  - [ ] SubTask 2.3: Document anti-stagnation rules
  - [ ] SubTask 2.4: Document GitHub Source of Truth rules
  - [ ] SubTask 2.5: Document emergency handling requirements

- [ ] Task 3: Rewrite `prompts/worker.md` with all specified changes
  - [ ] SubTask 3.1: Add Step 0: Environment Preparation with clone, branch switch, gh CLI install, auth config
  - [ ] SubTask 3.2: Improve permission boundary clarity with clearer "禁止" rules
  - [ ] SubTask 3.3: Add evolve.sh as sole legal execution path with emergency handling
  - [ ] SubTask 3.4: Strengthen anti-stagnation rules (3-round dimension switch, 2-round deep exploration)
  - [ ] SubTask 3.5: Add GitHub Source of Truth section with fetch-before-work pattern
  - [ ] SubTask 3.6: Add Git commit safety rules (no git add -A, no test files, no .log files)
  - [ ] SubTask 3.7: Improve scoring principles (Measurement Correction vs Discovery Bonus vs New Capability)
  - [ ] SubTask 3.8: Add emergency handling section
  - [ ] SubTask 3.9: Reorganize with clear visual separators (═) and section headers

- [ ] Task 4: Verify the updated prompt against spec requirements
  - [ ] SubTask 4.1: Check all requirements from spec.md are implemented
  - [ ] SubTask 4.2: Verify Step 0 has all 5 sub-steps (clone, branch, gh install, auth, bootstrap)
  - [ ] SubTask 4.3: Verify evolve.sh is the sole execution path is explicitly stated
  - [ ] SubTask 4.4: Verify anti-stagnation rules have exact thresholds (3 rounds, 2 rounds)
  - [ ] SubTask 4.5: Verify emergency handling covers all 4 scenarios
