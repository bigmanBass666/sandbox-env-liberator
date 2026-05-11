# Night Evolution Worker Prompt Update - The Implementation Plan (Decomposed and Prioritized Task List)

## [x] Task 1: Replace prompts/worker.md with the new prompt provided by user
- **Priority**: P0
- **Depends On**: None
- **Description**: 
  - Overwrite the existing /workspace/prompts/worker.md with the full prompt content provided in the user input
- **Acceptance Criteria Addressed**: AC-1, AC-2, AC-3, AC-4
- **Test Requirements**:
  - `programmatic` TR-1.1: Step 0 environment preparation uses /workspace/sandbox-env-setup
  - `programmatic` TR-1.2: "绝对禁止" section is not present
  - `human-judgement` TR-1.3: Step 4 allows both returning to Step 3 and manual improvements
  - `human-judgement` TR-1.4: Step 5 includes updating Polaris scores, handoff.md, and evolution-log.md
- **Notes**: Use the exact prompt content provided by the user

## [x] Task 2: Verify all changes are correct
- **Priority**: P0
- **Depends On**: Task 1
- **Description**: Verify that the updated worker prompt matches the user's specification
- **Acceptance Criteria Addressed**: AC-1, AC-2, AC-3, AC-4
- **Test Requirements**:
  - `programmatic` TR-2.1: All required sections are present
  - `human-judgement` TR-2.2: The prompt is correctly formatted
- **Notes**: Check that log archive specification is preserved
