# Update Jira Ticket

Determine the ticket key from:
1. $ARGUMENTS if provided (e.g., "KVMS-465" or "KVMS-465 in progress" or just "in review")
2. Otherwise, extract from the current git branch name (e.g., `KVMS-465-some-description` -> `KVMS-465`)

If no ticket key can be determined, ask the user.

## Workflow

1. Get the cloud ID by calling `getAccessibleAtlassianResources` first - you need the UUID format (e.g., `504b9f9f-5e9d-4c2b-a5c9-e15fea004284`), not the site URL
2. Fetch the ticket details and available transitions using the Atlassian MCP with that cloud ID
3. Look at recent git commits on this branch (compared to master/main) and the work done in this conversation
4. Determine what updates are needed:

### Status Change
If $ARGUMENTS contains a status-like term (e.g., "in progress", "done", "review", "closed"):
- Match it to an available transition
- Prepare to transition the ticket

If no status is specified but the conversation shows the fix/feature has been completed and pushed:
- Suggest transitioning to "Done"
- Include this in the proposed changes for confirmation

### Content Update
- Prepare a comment summarizing the work done
- If $ARGUMENTS contains additional context beyond ticket key and status, include it

4. Present the proposed changes to the user:
   - Show the comment that will be added
   - Show the status transition if applicable
5. Ask for confirmation before making changes

Do not mention git pushes, branch status, or "ready for review" in comments - these are implicit.

## API Notes

When using `editJiraIssue` to update fields:
- Pass text fields (description, etc.) as **markdown strings**, NOT as ADF objects
- The MCP tool automatically converts markdown to ADF
- Example: `{"description": "**Bold text**\n- List item"}` (correct)
- NOT: `{"description": {"type": "doc", "version": 1, ...}}` (will fail)
