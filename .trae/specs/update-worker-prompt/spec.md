# Night Evolution Worker Prompt Update Spec

## Why

The current worker prompt needs modernization to handle fresh AI session environments, provide clearer execution flow, and strengthen operational safety rules to prevent common failure modes observed in evolution rounds.

## What Changes

- Add **Step 0: Environment Preparation** for fresh session compatibility (clone repo, switch branch, install gh CLI, configure auth)
- Improve permission boundary clarity with explicit "禁止" rules
- Add **evolve.sh as the sole legal execution path** with emergency handling rules
- Strengthen **anti-stagnation rules** (3 rounds no progress = mandatory dimension switch, 2 rounds no Polaris growth = deep exploration mode)
- Add **GitHub Source of Truth** emphasis with fetch-before-work pattern
- Add **Git commit safety** (no `git add -A`, no test files, no .log files)
- Improve **scoring principles** documentation (Measurement Correction vs Discovery Bonus vs New Capability)
- Add **emergency handling** section for timeouts, crashes, and failures
- Reorganize document structure with clearer section headers and visual separators (═)

## Impact

- Affected files: `prompts/worker.md`
- This is a **prompts/ directory modification** - normally prohibited by Worker role, but this is a CSO-designed update to the Worker system itself
- Worker agents will have clearer instructions and better failure recovery

## ADDED Requirements

### Requirement: Fresh Environment Compatibility

The Worker prompt SHALL provide Step 0 instructions that enable the Worker to operate in a brand new AI session with empty workspace.

#### Scenario: Clone and Setup
- **WHEN** Worker starts in an environment where `/workspace/.git` does not exist
- **THEN** Worker executes clone, branch switch, gh CLI installation, and auth configuration as specified in Step 0

### Requirement: Sole Execution Path Enforcement

The Worker prompt SHALL clearly state that `evolve.sh` is the only legal path for executing improvements.

#### Scenario: evolve.sh Unavailable
- **WHEN** evolve.sh cannot execute due to environment issues
- **THEN** Worker may only fix environment to make evolve.sh runnable
- **THEN** Worker is **prohibited** from manually executing improvements that bypass evolve.sh

### Requirement: Anti-Stagnation Enforcement

The Worker prompt SHALL mandate dimension switching when progress stalls.

#### Scenario: Dimension Switch Trigger
- **WHEN** same dimension has no progress for 3 consecutive rounds (Streak >= 3)
- **THEN** Worker MUST switch to the second-lowest-scoring dimension
- **WHEN** total Polaris score has no growth for 2 consecutive rounds
- **THEN** Worker enters deep exploration mode

### Requirement: GitHub Source of Truth

The Worker prompt SHALL require GitHub as the single source of truth for all state.

#### Scenario: Before Any Work
- **WHEN** Worker starts any work
- **THEN** Worker executes `git fetch origin && git log --oneline -15 --all` first
- **THEN** Worker verifies current branch state against remote

### Requirement: Emergency Handling

The Worker prompt SHALL define clear actions for critical failure scenarios.

#### Scenario: Timeout or Crash
- **WHEN** evolve.sh execution exceeds 30 minutes, environment is severely damaged, 3 consecutive improvements fail, or Polaris score regresses
- **THEN** Worker records status to handoff.md with appropriate Status (STALLED or INCOMPLETE)
- **THEN** Worker pushes to worker branch and ends the current round
