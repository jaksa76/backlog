# Examples of how to use backlog

## Greenfield project:

Generate a backlog from requirements written in markdown:

```bash
backlog edit "Extract user stories from the REQUIREMENTS.md document. Make user stories small independent and negotiable. Use story slicing for any large stories. Standardize titles to verb-first. Add labels based on the content (e.g. 'bug', 'feature', 'tech-debt')." --out backlog.txt
```

backlog will determine the format based on the extension, or you can specify `--format` explicitly to override.

## Remove duplicates from existing backlog:

```bash
# Pull issues into a snapshot
backlog pull jira --jql "project = ABC AND statusCategory != Done ORDER BY updated DESC"

# Pack issues into one file for easier review/edit
backlog pack ./snapshots/abc-001 --format md --details medium > backlog.md

# Edit automatically detects the format
backlog edit "Merge obvious duplicates. Standardize titles to verb-first." < backlog.md > backlog-deduped.md

# Always stage changes for review before applying
backlog stage backlog-deduped.md > changes.json

# Push changes to the server
backlog push changes.json
```

## Add clarifying questions for sprint planning:

```bash
backlog pull github --repo org/repo --query "is:issue is:open iteration:7"

backlog pack ./snapshots/repo-001 --format json --details all > backlog.json

backlog edit "Add comments with clarifying questions for sprint planning. Focus on acceptance criteria. For each question suggest a possible answer." < backlog.json > backlog-with-questions.json

backlog stage backlog-with-questions.json

# Review changes, then push
backlog push changes.json
```

