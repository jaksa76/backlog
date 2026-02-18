#!/usr/bin/env bash

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"

usage() {
	cat <<EOF
Usage:
	$SCRIPT_NAME pull github --repo <owner/repo> [--data <snapshot_dir>]

Implements:
	pull all issues from github repository

Examples:
	$SCRIPT_NAME pull github --repo octocat/Hello-World
	$SCRIPT_NAME pull github --repo octocat/Hello-World --data ./snapshots/hello-world-001
EOF
}

error() {
	echo "error: $*" >&2
	exit 1
}

require_command() {
	local command_name="$1"
	if ! command -v "$command_name" >/dev/null 2>&1; then
		error "required command not found: $command_name"
	fi
}

pull_github_all_issues() {
	local repo="$1"
	local out_dir="$2"
	local issues_file="$out_dir/issues.ndjson"
	local manifest_file="$out_dir/manifest.json"
	local sources_file="$out_dir/sources.json"
	local pulled_at
	local issue_count

	require_command gh

	mkdir -p "$out_dir"

	pulled_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

	gh api \
		--paginate \
		-H "Accept: application/vnd.github+json" \
		"/repos/$repo/issues?state=all&per_page=100&sort=updated&direction=desc" \
		--jq '.[] | select(has("pull_request") | not)' \
		> "$issues_file"

	issue_count="$(wc -l < "$issues_file" | tr -d ' ')"

	cat > "$manifest_file" <<EOF
{
	"version": "1",
	"kind": "github",
	"repo": "$repo",
	"pulledAt": "$pulled_at",
	"issueCount": $issue_count,
	"files": {
		"issues": "issues.ndjson"
	}
}
EOF

	cat > "$sources_file" <<EOF
{
	"kind": "github",
	"repo": "$repo",
	"api": "/repos/$repo/issues",
	"query": {
		"state": "all",
		"per_page": 100,
		"sort": "updated",
		"direction": "desc"
	}
}
EOF

	echo "Pulled $issue_count issues from $repo"
	echo "Snapshot written to $out_dir"
}

main() {
	if [[ $# -lt 1 ]]; then
		usage
		exit 1
	fi

	local command="$1"
	shift

	case "$command" in
		pull)
			local source="${1:-}"
			[[ -n "$source" ]] || error "missing source after 'pull'"
			shift

			case "$source" in
				github)
					local repo=""
					local out_dir=""
					local timestamp

					while [[ $# -gt 0 ]]; do
						case "$1" in
							--repo)
								repo="${2:-}"
								shift 2
								;;
							--data)
								out_dir="${2:-}"
								shift 2
								;;
							-h|--help)
								usage
								exit 0
								;;
							*)
								error "unknown argument: $1"
								;;
						esac
					done

					[[ -n "$repo" ]] || error "--repo is required (format: owner/repo)"
					if [[ -z "$out_dir" ]]; then
						timestamp="$(date -u +"%Y%m%dT%H%M%SZ")"
						out_dir="./snapshots/${repo//\//-}-$timestamp"
					fi

					pull_github_all_issues "$repo" "$out_dir"
					;;
				*)
					error "unsupported source for pull: $source"
					;;
			esac
			;;
		-h|--help|help)
			usage
			;;
		*)
			error "unsupported command: $command"
			;;
	esac
}

main "$@"
