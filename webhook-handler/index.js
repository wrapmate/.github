// Webhook handler for GitHub org repository.created events
// Deploy this to Cloudflare Workers, Vercel, AWS Lambda, etc.

export default {
  async fetch(request, env) {
    // Only accept POST requests
    if (request.method !== 'POST') {
      return new Response('Method not allowed', { status: 405 });
    }

    // Verify GitHub webhook signature (recommended for production)
    const signature = request.headers.get('X-Hub-Signature-256');
    // TODO: Verify signature using env.WEBHOOK_SECRET

    // Parse webhook payload
    const payload = await request.json();

    // Only process repository.created events
    if (payload.action !== 'created') {
      return new Response('Event ignored (not a creation)', { status: 200 });
    }

    // Extract repository and creator info
    const repoName = payload.repository.name;
    const creator = payload.sender.login;
    const orgName = payload.organization.login;

    console.log(`Repository created: ${repoName} by ${creator}`);

    // Trigger GitHub Actions workflow via repository_dispatch
    const dispatchUrl = `https://api.github.com/repos/${orgName}/.github/dispatches`;

    const dispatchPayload = {
      event_type: 'repository_created',
      client_payload: {
        repository: repoName,
        creator: creator,
        created_at: payload.repository.created_at,
        full_name: payload.repository.full_name
      }
    };

    const response = await fetch(dispatchUrl, {
      method: 'POST',
      headers: {
        'Accept': 'application/vnd.github+json',
        'Authorization': `Bearer ${env.GITHUB_TOKEN}`,
        'X-GitHub-Api-Version': '2022-11-28',
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(dispatchPayload)
    });

    if (response.ok) {
      console.log(`✓ Workflow triggered for ${repoName}`);
      return new Response(JSON.stringify({
        success: true,
        repository: repoName,
        creator: creator
      }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' }
      });
    } else {
      const error = await response.text();
      console.error(`✗ Failed to trigger workflow: ${error}`);
      return new Response(JSON.stringify({
        success: false,
        error: error
      }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' }
      });
    }
  }
};
