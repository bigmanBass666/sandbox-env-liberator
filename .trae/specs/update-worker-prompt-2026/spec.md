# Night Evolution Worker Prompt Update - Product Requirement Document

## Overview
- **Summary**: Update the Night Evolution Worker prompt to match the new specification provided, which modifies the Step 0 environment preparation path, removes the strict "no manual improvements" restriction, and updates the Step 5 recording flow.
- **Purpose**: Align the worker prompt with the latest operational requirements from CSO.
- **Target Users**: Night Evolution Worker

## Goals
- Update Step 0 to clone the repository to `/workspace/sandbox-env-setup` instead of `/workspace`
- Remove the "绝对禁止" (strictly forbidden) section that prevented manual improvements
- Update Step 4 to allow both returning to Step 3 or manual improvements
- Update Step 5 to include updating Polaris scores, handoff.md, and evolution-log.md
- Ensure the log archive specification is preserved

## Non-Goals (Out of Scope)
- Modifying the evolve.sh script itself
- Changing the CSO or Reviewer roles
- Modifying the .agents/ directory

## Background & Context
The existing worker prompt (`prompts/worker.md`) has a strict "no manual improvements" restriction. The new prompt from CSO relaxes this, allowing manual improvements, and updates the repository path to `/workspace/sandbox-env-setup`.

## Functional Requirements
- **FR-1**: Step 0 environment preparation must clone the repository to `/workspace/sandbox-env-setup`
- **FR-2**: Remove the "绝对禁止" (strictly forbidden) section
- **FR-3**: Step 4 must allow both returning to Step 3 and manual improvements
- **FR-4**: Step 5 must include updating Polaris scores, handoff.md, and evolution-log.md

## Non-Functional Requirements
- **NFR-1**: All existing rules (anti-stagnation, GitHub Source of Truth, Git commit safety) must be preserved
- **NFR-2**: The log archive specification must be preserved

## Constraints
- **Technical**: Only modifying `prompts/worker.md`
- **Business**: This is a CSO-initiated update to the worker prompt

## Assumptions
- The new prompt structure provided by the user is correct and complete

## Acceptance Criteria

### AC-1: Step 0 Environment Preparation
- **Given**: The worker prompt
- **When**: Step 0 is executed
- **Then**: The repository is cloned to `/workspace/sandbox-env-setup` if it doesn't exist, and `cd` is to `/workspace/sandbox-env-setup`
- **Verification**: `programmatic`

### AC-2: Strict Forbidden Section Removed
- **Given**: The worker prompt
- **When**: Reading the prompt
- **Then**: The "绝对禁止" (strictly forbidden) section is not present
- **Verification**: `programmatic`

### AC-3: Step 4 Allows Manual Improvements
- **Given**: The worker prompt
- **When**: Step 4 is executed
- **Then**: It allows both returning to Step 3 and manual improvements
- **Verification**: `human-judgment`

### AC-4: Step 5 Includes Score Updates
- **Given**: The worker prompt
- **When**: Step 5 is executed
- **Then**: It includes steps to update Polaris scores, handoff.md, and evolution-log.md
- **Verification**: `human-judgment`

## Open Questions
- None
