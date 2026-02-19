#!/usr/bin/env bash

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"

usage() {
	cat <<EOF
Usage:
	$SCRIPT_NAME pull github --repo <owner/repo> [--data <snapshot_dir>]
	$SCRIPT_NAME list [--data <issues_dir>]

Implements:
	pull all issues from github repository
	list all issues stored locally

Examples:
	$SCRIPT_NAME pull github --repo octocat/Hello-World
	$SCRIPT_NAME pull github --repo octocat/Hello-World --data ./snapshots/hello-world-001
	$SCRIPT_NAME list
	$SCRIPT_NAME list --data ./snapshots/hello-world-001
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

extract_issue_files() {
	local issues_file="$1"
	local out_dir="$2"

	mkdir -p "$out_dir"

	jq -c '{
		number,
		title,
		state,
		labels: ((.labels // []) | map(.name)),
		assignees: ((.assignees // []) | map(.login)),
		created_at,
		updated_at,
		closed_at,
		html_url,
		body
	}' "$issues_file" | while IFS= read -r compact_issue; do
		issue_number="$(jq -r '.number // empty' <<< "$compact_issue")"
		[[ -n "$issue_number" ]] || continue
		jq '.' <<< "$compact_issue" > "$out_dir/issue-$issue_number.json"
	done
}

pull_github_all_issues() {
	local repo="$1"
	local out_dir="$2"
	local issues_file="$out_dir/issues.ndjson"
	local issue_files_dir="$out_dir/by-id"
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

	extract_issue_files "$issues_file" "$issue_files_dir"

	cat > "$manifest_file" <<EOF
{
	"version": "1",
	"kind": "github",
	"repo": "$repo",
	"pulledAt": "$pulled_at",
	"issueCount": $issue_count,
	"files": {
		"issues": "issues.ndjson",
		"byId": "by-id"
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
	echo "Per-issue files written to $issue_files_dir"
}

list_issues() {
	local issues_dir="$1"
	local by_id_dir="$issues_dir/by-id"

	[[ -d "$by_id_dir" ]] || error "issues directory not found: $by_id_dir"

	for file in $(ls -v "$by_id_dir"/issue-*.json 2>/dev/null); do
		[[ -f "$file" ]] || continue
		local basename
		basename="$(basename "$file" .json)"
		local id="${basename#issue-}"
		local title
		title="$(jq -r '.title // "(no title)"' "$file")"
		printf '%s\t%s\n' "$id" "$title"
	done
}

main() {
	if [[ $# -lt 1 ]]; then
		usage
		exit 1
	fi

	local command="$1"
	shift

	case "$command" in
		list)
			local out_dir="./issues"
			while [[ $# -gt 0 ]]; do
				case "$1" in
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
			list_issues "$out_dir"
			;;
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
						out_dir="./issues/"
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
