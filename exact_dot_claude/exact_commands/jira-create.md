# Create or Fill Jira Ticket

Determine the ticket key from:
1. $ARGUMENTS if provided (e.g., "KVMS-465" or "KVMS-465 with description about feature X")
2. Otherwise, extract from the current git branch name (e.g., `KVMS-465-some-description` -> `KVMS-465`)

If no ticket key can be determined, ask the user.

## Workflow

1. Get the cloud ID by calling `getAccessibleAtlassianResources` first - you need the UUID format (e.g., `504b9f9f-5e9d-4c2b-a5c9-e15fea004284`), not the site URL
2. Try to fetch the ticket using the Atlassian MCP with that cloud ID
3. If the ticket exists and has an empty or minimal description:
   - Analyze the current branch's commits and code changes to understand what this ticket is about
   - Propose a description based on the work done
   - Ask the user to confirm before updating
4. If the ticket doesn't exist:
   - Ask the user for the project key and summary
   - Create a new ticket with a description based on the current work context
   - Get the current user's account ID using `atlassianUserInfo`
   - Assign the newly created ticket to the current user
   - Get available transitions using `getTransitionsForJiraIssue` and transition the ticket to "In Progress"
   - Add the ticket to the current active sprint:
     1. Search for an issue in the same project with an active sprint: `project = {PROJECT} AND sprint in openSprints() ORDER BY created DESC` with `maxResults=1` and `fields=["customfield_10020"]`
     2. Extract the sprint ID from the `customfield_10020` field (the sprint array)
     3. Update the new ticket with `editJiraIssue` using `{"customfield_10020": <sprint_id>}` (pass the ID as a number, not an array)
5. If the ticket already has a substantial description:
   - Show the current description and ask if the user wants to update it

Always confirm with the user before making any changes.

## API Notes

When using `editJiraIssue` to update the description field:
- Pass the description as a **markdown string**, NOT as an ADF (Atlassian Document Format) object
- The MCP tool automatically converts markdown to ADF
- Example: `{"description": "**Bold text**\n- List item"}` (correct)
- NOT: `{"description": {"type": "doc", "version": 1, ...}}` (will fail)
