# Verification Checklist - Update Worker Prompt

## Implementation Verification

- [x] prompts/worker.md file exists and is readable
- [x] Step 0: Environment Preparation section is present with all 5 sub-steps:
  - [x] Clone repository if /workspace/.git does not exist
  - [x] Switch to worker branch with git fetch/checkout
  - [x] Install gh CLI if not available
  - [x] Configure gh CLI auth from git remote URL
  - [x] Run bootstrap script
- [x] Permission boundaries are clearly stated with "禁止" rules
- [x] evolve.sh is explicitly stated as the sole legal execution path
- [x] Anti-stagnation rules include exact thresholds:
  - [x] 3 consecutive rounds without progress = mandatory dimension switch
  - [x] 2 consecutive rounds without Polaris growth = deep exploration mode
- [x] GitHub Source of Truth section present with fetch-before-work pattern
- [x] Git commit safety rules include:
  - [x] No `git add -A` or `git add .`
  - [x] No test files (*-test-*), temporary files (/tmp/), *.log files, crash dumps
  - [x] Use targeted `git add <specific files>` instead
- [x] Scoring principles clarify:
  - [x] Measurement Correction (score update but no positive Delta)
  - [x] Discovery Bonus (max +5%)
  - [x] New Capability (normal scoring)
- [x] Emergency handling section covers:
  - [x] evolve.sh timeout (>30 minutes)
  - [x] Severe environment damage
  - [x] 3 consecutive improvement failures
  - [x] Polaris score regression
- [x] Document uses clear visual separators (═) and section headers

## Quality Checks

- [x] All code blocks are properly formatted
- [x] No placeholder text (TODO, TBD, etc.)
- [x] All bash commands are syntactically correct
- [x] File path references are accurate
