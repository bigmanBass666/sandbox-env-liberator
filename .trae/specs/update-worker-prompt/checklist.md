# Verification Checklist - Update Worker Prompt

## Implementation Verification

- [ ] prompts/worker.md file exists and is readable
- [ ] Step 0: Environment Preparation section is present with all 5 sub-steps:
  - [ ] Clone repository if /workspace/.git does not exist
  - [ ] Switch to worker branch with git fetch/checkout
  - [ ] Install gh CLI if not available
  - [ ] Configure gh CLI auth from git remote URL
  - [ ] Run bootstrap script
- [ ] Permission boundaries are clearly stated with "禁止" rules
- [ ] evolve.sh is explicitly stated as the sole legal execution path
- [ ] Anti-stagnation rules include exact thresholds:
  - [ ] 3 consecutive rounds without progress = mandatory dimension switch
  - [ ] 2 consecutive rounds without Polaris growth = deep exploration mode
- [ ] GitHub Source of Truth section present with fetch-before-work pattern
- [ ] Git commit safety rules include:
  - [ ] No `git add -A` or `git add .`
  - [ ] No test files (*-test-*), temporary files (/tmp/), *.log files, crash dumps
  - [ ] Use targeted `git add <specific files>` instead
- [ ] Scoring principles clarify:
  - [ ] Measurement Correction (score update but no positive Delta)
  - [ ] Discovery Bonus (max +5%)
  - [ ] New Capability (normal scoring)
- [ ] Emergency handling section covers:
  - [ ] evolve.sh timeout (>30 minutes)
  - [ ] Severe environment damage
  - [ ] 3 consecutive improvement failures
  - [ ] Polaris score regression
- [ ] Document uses clear visual separators (═) and section headers

## Quality Checks

- [ ] All code blocks are properly formatted
- [ ] No placeholder text (TODO, TBD, etc.)
- [ ] All bash commands are syntactically correct
- [ ] File path references are accurate
