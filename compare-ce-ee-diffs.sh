#!/usr/bin/env bash

set -Eeuo pipefail

# Color configuration - detect if terminal supports colors
if [[ -t 1 ]] || [[ "$FORCE_COLOR" == true ]]; then
    # Terminal supports colors or color is forced
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    NC='\033[0m' # No Color
else
    # No color support
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    NC=''
fi

# Script configuration
SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)"

# Default values
DEFAULT_BASE_BRANCH="develop"
TEMP_DIR="/tmp/portainer-diff-compare-$$"

# Help function
show_help() {
    cat << EOF
$SCRIPT_NAME - Compare server-ce and server-ee diffs against a base branch

USAGE:
    $SCRIPT_NAME [OPTIONS] [BASE_BRANCH]

ARGUMENTS:
    BASE_BRANCH    Branch to compare against (default: $DEFAULT_BASE_BRANCH)

OPTIONS:
    -h, --help         Show this help message
    -v, --verbose      Show verbose output
    -s, --stats        Show only file change statistics
    -d, --detail       Show detailed diff when files differ
    -c, --color        Force colored output (auto-detected by default)
    --committed-only   Only compare committed changes (exclude staged/unstaged)

EXAMPLES:
    $SCRIPT_NAME                    # Compare all changes (committed + staged + unstaged)
    $SCRIPT_NAME main              # Compare against main branch
    $SCRIPT_NAME -v develop        # Verbose output against develop
    $SCRIPT_NAME --detail feature-branch  # Show detailed diff if different
    $SCRIPT_NAME --committed-only  # Only compare committed changes
    $SCRIPT_NAME -dc develop       # Show colored detailed diff

DESCRIPTION:
    This script compares the changes made to server-ce and server-ee packages
    against a specified base branch. It normalizes the package names and checks
    if the content changes are identical between the two editions.

    By default, includes committed, staged, and unstaged changes.
    Use --committed-only to exclude uncommitted changes.

    The script will exit with:
    - 0 if diffs are identical
    - 1 if diffs are different
    - 2 if there's an error

EOF
}

# Cleanup function
cleanup() {
    rm -rf "$TEMP_DIR" 2>/dev/null || true
}

# Set up cleanup trap
trap cleanup EXIT

# Parse command line arguments
VERBOSE=false
STATS_ONLY=false
SHOW_DETAIL=false
FORCE_COLOR=false
COMMITTED_ONLY=false
BASE_BRANCH=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -s|--stats)
            STATS_ONLY=true
            shift
            ;;
        -d|--detail)
            SHOW_DETAIL=true
            shift
            ;;
        -c|--color)
            FORCE_COLOR=true
            shift
            ;;
        --committed-only)
            COMMITTED_ONLY=true
            shift
            ;;
        -*)
            echo -e "${RED}Error: Unknown option $1${NC}" >&2
            show_help >&2
            exit 2
            ;;
        *)
            if [[ -z "$BASE_BRANCH" ]]; then
                BASE_BRANCH="$1"
            else
                echo -e "${RED}Error: Too many arguments${NC}" >&2
                show_help >&2
                exit 2
            fi
            shift
            ;;
    esac
done

# Set default base branch if not provided
BASE_BRANCH="${BASE_BRANCH:-$DEFAULT_BASE_BRANCH}"

# Logging functions
log_info() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${BLUE}[INFO]${NC} $1"
    fi
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if we're in a git repository
check_git_repo() {
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        log_error "Not in a git repository"
        exit 2
    fi
}

# Check if base branch exists
check_base_branch() {
    if ! git show-ref --verify --quiet "refs/heads/$BASE_BRANCH" && \
       ! git show-ref --verify --quiet "refs/remotes/origin/$BASE_BRANCH"; then
        log_error "Base branch '$BASE_BRANCH' does not exist"
        exit 2
    fi
}

# Check if packages exist
check_packages() {
    if [[ ! -d "package/server-ce" ]]; then
        log_error "package/server-ce directory not found"
        exit 2
    fi
    
    if [[ ! -d "package/server-ee" ]]; then
        log_error "package/server-ee directory not found"
        exit 2
    fi
}

# Get file change statistics
get_stats() {
    local ce_files ee_files diff_target

    # Set diff target based on whether we want committed only
    if [[ "$COMMITTED_ONLY" == true ]]; then
        diff_target="$BASE_BRANCH...HEAD"
    else
        diff_target="$BASE_BRANCH"
    fi

    ce_files=$(git diff "$diff_target" --name-only -- package/server-ce/ | wc -l)
    ee_files=$(git diff "$diff_target" --name-only -- package/server-ee/ | wc -l)

    echo -e "${BLUE}=== Change Statistics ===${NC}"
    echo "Base branch: $BASE_BRANCH"
    if [[ "$COMMITTED_ONLY" == true ]]; then
        echo "Mode: Committed changes only"
    else
        echo "Mode: All changes (committed + staged + unstaged)"
    fi
    echo "Files changed in CE: $ce_files"
    echo "Files changed in EE: $ee_files"

    if [[ "$STATS_ONLY" == true ]]; then
        return
    fi

    echo ""
}

# Get unique files in each package
get_unique_files() {
    local ce_only ee_only diff_target

    mkdir -p "$TEMP_DIR"

    # Set diff target based on whether we want committed only
    if [[ "$COMMITTED_ONLY" == true ]]; then
        diff_target="$BASE_BRANCH...HEAD"
    else
        diff_target="$BASE_BRANCH"
    fi

    # Get normalized file lists
    git diff "$diff_target" --name-only -- package/server-ce/ | \
        sed 's|package/server-ce/||' | sort > "$TEMP_DIR/ce_files.txt"

    git diff "$diff_target" --name-only -- package/server-ee/ | \
        sed 's|package/server-ee/||' | sort > "$TEMP_DIR/ee_files.txt"

    # Find unique files
    ce_only=$(comm -23 "$TEMP_DIR/ce_files.txt" "$TEMP_DIR/ee_files.txt")
    ee_only=$(comm -13 "$TEMP_DIR/ce_files.txt" "$TEMP_DIR/ee_files.txt")

    if [[ -n "$ce_only" ]]; then
        echo -e "${YELLOW}Files only in CE:${NC}"
        echo "$ce_only" | sed 's/^/  - /'
        echo ""
    fi

    if [[ -n "$ee_only" ]]; then
        echo -e "${YELLOW}Files only in EE:${NC}"
        echo "$ee_only" | sed 's/^/  - /'
        echo ""
    fi

    # Find files present in both but with different content
    local differing_files=()
    local common_files
    common_files=$(comm -12 "$TEMP_DIR/ce_files.txt" "$TEMP_DIR/ee_files.txt")

    if [[ -n "$common_files" ]]; then
        while IFS= read -r file; do
            git diff "$diff_target" -- "package/server-ce/$file" | \
                sed 's|package/server-ce|package/server-XX|g' > "$TEMP_DIR/ce_file_diff.txt"
            git diff "$diff_target" -- "package/server-ee/$file" | \
                sed 's|package/server-ee|package/server-XX|g' > "$TEMP_DIR/ee_file_diff.txt"

            if ! cmp -s "$TEMP_DIR/ce_file_diff.txt" "$TEMP_DIR/ee_file_diff.txt"; then
                differing_files+=("$file")
            fi
        done <<< "$common_files"
    fi

    if [[ ${#differing_files[@]} -gt 0 ]]; then
        echo -e "${YELLOW}Files in both but with different changes:${NC}"
        for f in "${differing_files[@]}"; do
            echo "  - $f"
        done
        echo ""
    fi
}

# Compare the actual diffs
compare_diffs() {
    local diff_target

    log_info "Generating diffs for comparison..."

    # Create temp directory
    mkdir -p "$TEMP_DIR"

    # Set diff target based on whether we want committed only
    if [[ "$COMMITTED_ONLY" == true ]]; then
        diff_target="$BASE_BRANCH...HEAD"
    else
        diff_target="$BASE_BRANCH"
    fi

    # Generate normalized diffs
    git diff "$diff_target" -- package/server-ce/ | \
        sed 's|package/server-ce|package/server-XX|g' > "$TEMP_DIR/ce_diff.txt"

    git diff "$diff_target" -- package/server-ee/ | \
        sed 's|package/server-ee|package/server-XX|g' > "$TEMP_DIR/ee_diff.txt"

    log_info "Comparing normalized diffs..."

    # Compare the diffs
    if cmp -s "$TEMP_DIR/ce_diff.txt" "$TEMP_DIR/ee_diff.txt"; then
        log_success "The diffs are IDENTICAL!"
        if [[ "$COMMITTED_ONLY" == true ]]; then
            echo "Both server-ce and server-ee have exactly the same committed changes relative to '$BASE_BRANCH'"
        else
            echo "Both server-ce and server-ee have exactly the same changes (committed + staged + unstaged) relative to '$BASE_BRANCH'"
        fi
        return 0
    else
        log_error "The diffs are DIFFERENT!"

        if [[ "$SHOW_DETAIL" == true ]]; then
            echo ""
            echo -e "${BLUE}=== Detailed Differences ===${NC}"

            # Use git diff for colored output (git is always available in this context)
            if [[ "$FORCE_COLOR" == true ]] || [[ -t 1 ]]; then
                git diff --no-index --color=always --no-prefix \
                    --word-diff=color \
                    "$TEMP_DIR/ce_diff.txt" "$TEMP_DIR/ee_diff.txt" | head -50 || true
            else
                git diff --no-index --no-prefix \
                    "$TEMP_DIR/ce_diff.txt" "$TEMP_DIR/ee_diff.txt" | head -50 || true
            fi

            echo ""
            echo -e "${YELLOW}(Showing first 50 lines of differences...)${NC}"
        else
            echo "Use --detail flag to see the specific differences"
        fi

        return 1
    fi
}

# Main execution
main() {
    echo -e "${BLUE}=== Portainer CE/EE Diff Comparison ===${NC}"
    echo ""
    
    # Checks
    check_git_repo
    check_base_branch
    check_packages
    
    # Show statistics
    get_stats
    
    # Exit early if stats only
    if [[ "$STATS_ONLY" == true ]]; then
        exit 0
    fi
    
    # Show unique files
    get_unique_files
    
    # Compare diffs
    if compare_diffs; then
        log_info "Diff comparison completed successfully"
        exit 0
    else
        log_info "Diff comparison found differences"
        exit 1
    fi
}

# Run main function
main "$@"