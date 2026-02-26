# Jira Ticket Lookup

The user wants you to load context about their current work from Jira.

1. Determine the ticket key from $ARGUMENTS, or extract it from the current git branch name (e.g., `KVMS-465-some-description` -> `KVMS-465`)
2. Get the cloud ID by calling `getAccessibleAtlassianResources` first - you need the UUID format (e.g., `504b9f9f-5e9d-4c2b-a5c9-e15fea004284`), not the site URL
3. Use the Atlassian MCP to fetch the ticket details with that cloud ID
4. Briefly summarize what you learned (key, summary, status, relevant description/comments)
5. Wait for the user's next instruction

This is context-loading, not a task. Do not take action on the ticket or suggest next steps - just absorb the information and wait for the user to tell you what they want to do.
