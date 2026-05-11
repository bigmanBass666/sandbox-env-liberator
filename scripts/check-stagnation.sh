#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(dirname "$SCRIPT_DIR")"

EVOLUTION_LOG="${WORKSPACE_DIR}/references/evolution-log.md"
POLARIS_SCORE="${WORKSPACE_DIR}/references/polaris-score.md"
HANDOFF="${WORKSPACE_DIR}/references/handoff.md"

declare -A DIM_STREAKS=(
    ["D1"]=0
    ["D2"]=0
    ["D3"]=0
    ["D4"]=0
    ["D5"]=0
    ["D6"]=0
)

TOTAL_STREAK=0
DEEP_EXPLORATION_MODE=false
RECOMMENDED_DIM=""
MIN_IMPROVEMENT_FLAG=false
RECOMMENDED_SCORE=""

echo "=========================================="
echo "Anti-Stagnation Detection"
echo "=========================================="
echo ""

parse_table_fields() {
    local line="$1"
    local IFS='|'
    local -a fields=()
    for field in $line; do
        field=$(echo "$field" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d '%')
        if [[ -n "$field" ]]; then
            fields+=("$field")
        fi
    done
    echo "${fields[@]}"
}

analyze_dimension_stagnation() {
    echo ""
    echo "=== Dimension Stagnation Analysis ==="

    if [[ ! -f "$POLARIS_SCORE" ]]; then
        echo "ERROR: polaris-score.md not found"
        return 1
    fi

    local in_history=false
    local -a history_lines=()

    while IFS= read -r line; do
        if [[ "$line" =~ ^\|[[:space:]]*Round ]]; then
            in_history=true
            continue
        fi

        if [[ "$in_history" == true && "$line" =~ ^\|[[:space:]]*R([0-9]+) ]]; then
            history_lines+=("$line")
        fi
    done < "$POLARIS_SCORE"

    if [[ ${#history_lines[@]} -lt 2 ]]; then
        echo "  INFO: Not enough history data (${#history_lines[@]} rounds)"
        return
    fi

    local -A dim_counts=(
        ["D1"]=0
        ["D2"]=0
        ["D3"]=0
        ["D4"]=0
        ["D5"]=0
        ["D6"]=0
    )

    local prev_d1="" prev_d2="" prev_d3="" prev_d4="" prev_d5="" prev_d6=""

    for line in "${history_lines[@]}"; do
        local IFS='|'
        local -a fields=()
        for field in $line; do
            field=$(echo "$field" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d '%')
            if [[ -n "$field" ]]; then
                fields+=("$field")
            fi
        done

        if [[ ${#fields[@]} -ge 8 ]]; then
            local d1="${fields[2]}"
            local d2="${fields[3]}"
            local d3="${fields[4]}"
            local d4="${fields[5]}"
            local d5="${fields[6]}"
            local d6="${fields[7]}"

            for dim in D1 D2 D3 D4 D5 D6; do
                local curr_score=""
                local prev_score=""
                case "$dim" in
                    D1) curr_score="$d1"; prev_score="$prev_d1" ;;
                    D2) curr_score="$d2"; prev_score="$prev_d2" ;;
                    D3) curr_score="$d3"; prev_score="$prev_d3" ;;
                    D4) curr_score="$d4"; prev_score="$prev_d4" ;;
                    D5) curr_score="$d5"; prev_score="$prev_d5" ;;
                    D6) curr_score="$d6"; prev_score="$prev_d6" ;;
                esac

                if [[ -n "$prev_score" && "$curr_score" == "$prev_score" ]]; then
                    dim_counts["$dim"]=$((dim_counts["$dim"] + 1))
                else
                    dim_counts["$dim"]=1
                fi
            done

            prev_d1="$d1"
            prev_d2="$d2"
            prev_d3="$d3"
            prev_d4="$d4"
            prev_d5="$d5"
            prev_d6="$d6"
        fi
    done

    local stagnant_dims=()
    for dim in D1 D2 D3 D4 D5 D6; do
        echo "  $dim consecutive rounds without progress: ${dim_counts[$dim]}"
        if [[ "${dim_counts[$dim]}" -ge 3 ]]; then
            stagnant_dims+=("$dim")
        fi
    done

    if [[ ${#stagnant_dims[@]} -gt 0 ]]; then
        echo ""
        echo "ALERT: Dimension stagnation detected for: ${stagnant_dims[*]}"
        find_lowest_scoring_dimension
    else
        echo ""
        echo "OK: No dimension has stagnated for 3+ consecutive rounds"
    fi

    for dim in D1 D2 D3 D4 D5 D6; do
        DIM_STREAKS["$dim"]="${dim_counts[$dim]}"
    done
}

analyze_total_score_stagnation() {
    echo ""
    echo "=== Total Score Stagnation Analysis ==="

    if [[ ! -f "$POLARIS_SCORE" ]]; then
        echo "ERROR: polaris-score.md not found"
        return 1
    fi

    local in_history=false
    local -a totals=()

    while IFS= read -r line; do
        if [[ "$line" =~ ^\|[[:space:]]*Round ]]; then
            in_history=true
            continue
        fi

        if [[ "$in_history" == true && "$line" =~ ^\|[[:space:]]*R([0-9]+) ]]; then
            local IFS='|'
            local -a fields=()
            for field in $line; do
                field=$(echo "$field" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d '%')
                if [[ -n "$field" ]]; then
                    fields+=("$field")
                fi
            done

            if [[ ${#fields[@]} -ge 3 ]]; then
                totals+=("${fields[2]}")
            fi
        fi
    done < "$POLARIS_SCORE"

    if [[ ${#totals[@]} -lt 2 ]]; then
        echo "  INFO: Not enough data for total score analysis"
        return
    fi

    local prev_total=""
    local consecutive_no_change=0

    for ((i=${#totals[@]}-1; i>=0; i--)); do
        local current="${totals[$i]}"
        if [[ -n "$prev_total" ]]; then
            if [[ "$current" == "$prev_total" ]]; then
                consecutive_no_change=$((consecutive_no_change + 1))
            else
                break
            fi
        fi
        prev_total="$current"
    done

    TOTAL_STREAK="$consecutive_no_change"
    echo "  Total score consecutive rounds without increase: $consecutive_no_change"

    if [[ "$consecutive_no_change" -ge 2 ]]; then
        echo ""
        echo "ALERT: Total score stagnated for 2+ consecutive rounds"
        DEEP_EXPLORATION_MODE=true
        echo "ACTION: Deep exploration mode activated"
    else
        echo ""
        echo "OK: Total score is progressing"
    fi
}

check_minimum_improvement() {
    echo ""
    echo "=== +5% Minimum Improvement Check ==="

    if [[ ! -f "$POLARIS_SCORE" ]]; then
        echo "  ERROR: polaris-score.md not found"
        return
    fi

    local in_history=false
    local -a scores_with_rounds=()

    while IFS= read -r line; do
        if [[ "$line" =~ ^\|[[:space:]]*Round ]]; then
            in_history=true
            continue
        fi

        if [[ "$in_history" == true && "$line" =~ ^\|[[:space:]]*R([0-9]+) ]]; then
            local IFS='|'
            local -a fields=()
            for field in $line; do
                field=$(echo "$field" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d '%')
                if [[ -n "$field" ]]; then
                    fields+=("$field")
                fi
            done

            if [[ ${#fields[@]} -ge 3 ]]; then
                local round="${fields[1]}"
                local score="${fields[2]}"
                scores_with_rounds+=("$round:$score")
            fi
        fi
    done < "$POLARIS_SCORE"

    if [[ ${#scores_with_rounds[@]} -lt 2 ]]; then
        echo "  INFO: Not enough data for improvement check"
        return
    fi

    local current="${scores_with_rounds[-1]}"
    local previous="${scores_with_rounds[-2]}"

    local current_round="${current%%:*}"
    local current_score="${current#*:}"
    local previous_round="${previous%%:*}"
    local previous_score="${previous#*:}"

    if [[ "$previous_score" =~ ^[0-9]+$ ]] && [[ "$current_score" =~ ^[0-9]+$ ]]; then
        local expected_min=$((previous_score * 105 / 100))

        echo "  Current round: R${current_round}, Score: ${current_score}%"
        echo "  Previous round: R${previous_round}, Score: ${previous_score}%"
        echo "  Expected minimum improvement (5%): ${expected_min}%"

        if [[ "$current_score" -lt "$expected_min" ]]; then
            echo ""
            echo "FLAG: Improvement (${current_score}%) < 5% minimum (${expected_min}%)"
            MIN_IMPROVEMENT_FLAG=true
        else
            echo ""
            echo "OK: Improvement meets +5% minimum"
        fi
    else
        echo "  INFO: Cannot parse score values (current: $current_score, previous: $previous_score)"
    fi
}

find_lowest_scoring_dimension() {
    if [[ ! -f "$POLARIS_SCORE" ]]; then
        return
    fi

    local in_history=false
    local last_data_line=""

    while IFS= read -r line; do
        if [[ "$line" =~ ^\|[[:space:]]*Round ]]; then
            in_history=true
            continue
        fi

        if [[ "$in_history" == true && "$line" =~ ^\|[[:space:]]*R([0-9]+) ]]; then
            last_data_line="$line"
        fi
    done < "$POLARIS_SCORE"

    if [[ -z "$last_data_line" ]]; then
        return
    fi

    local IFS='|'
    local -a fields=()
    for field in $last_data_line; do
        field=$(echo "$field" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d '%')
        if [[ -n "$field" ]]; then
            fields+=("$field")
        fi
    done

    if [[ ${#fields[@]} -ge 8 ]]; then
        local d1="${fields[2]}"
        local d2="${fields[3]}"
        local d3="${fields[4]}"
        local d4="${fields[5]}"
        local d5="${fields[6]}"
        local d6="${fields[7]}"

        local lowest_dim=""
        local lowest_score=100

        for dim in D1 D2 D3 D4 D5 D6; do
            local score=""
            case "$dim" in
                D1) score="$d1" ;;
                D2) score="$d2" ;;
                D3) score="$d3" ;;
                D4) score="$d4" ;;
                D5) score="$d5" ;;
                D6) score="$d6" ;;
            esac

            if [[ -n "$score" && "$score" =~ ^[0-9]+$ ]] && [[ "$score" -lt "$lowest_score" ]]; then
                lowest_score="$score"
                lowest_dim="$dim"
            fi
        done

        if [[ -n "$lowest_dim" ]]; then
            echo "RECOMMENDATION: Switch to lowest-scoring dimension $lowest_dim (${lowest_score}%)"
            RECOMMENDED_DIM="$lowest_dim"
            RECOMMENDED_SCORE="$lowest_score"
        fi
    fi
}

output_recommendations() {
    echo ""
    echo "=========================================="
    echo "RECOMMENDATIONS"
    echo "=========================================="

    if [[ "$DEEP_EXPLORATION_MODE" == "true" ]]; then
        echo "ACTION: Activate DEEP EXPLORATION mode"
        echo "  Reason: Total score stagnated for $TOTAL_STREAK consecutive rounds"
        echo ""
    fi

    if [[ -n "$RECOMMENDED_DIM" ]]; then
        echo "FOCUS DIMENSION: $RECOMMENDED_DIM"
        echo "  Reason: Stagnated for 3+ consecutive rounds"
        echo "  Current Score: ${RECOMMENDED_SCORE}%"
    else
        echo "FOCUS DIMENSION: No switch needed (current dimension progressing)"
    fi

    if [[ "$MIN_IMPROVEMENT_FLAG" == "true" ]]; then
        echo ""
        echo "INFO: Round improvement < 5% minimum threshold"
        echo "  This is informational only, not a hard stop"
    fi

    echo ""
}

main() {
    if [[ ! -f "$POLARIS_SCORE" ]]; then
        echo "ERROR: Cannot find polaris-score.md at $POLARIS_SCORE"
        exit 1
    fi

    analyze_total_score_stagnation
    analyze_dimension_stagnation
    check_minimum_improvement
    output_recommendations

    if [[ "$DEEP_EXPLORATION_MODE" == "true" ]]; then
        exit 2
    elif [[ -n "$RECOMMENDED_DIM" ]]; then
        exit 1
    else
        exit 0
    fi
}

main "$@"
