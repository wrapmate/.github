# GitHub Repository Creation Webhook Handler

**Purpose**: Triggers the auto-seed workflow when j-bob-wm creates a new repository (event-based, no polling!)

---

## How It Works

```
1. j-bob-wm creates repo in Lovable & syncs to GitHub
   ↓
2. GitHub fires organization webhook: repository.created
   ↓
3. Webhook handler receives the event
   ↓
4. Handler checks: creator == j-bob-wm?
   ↓
5. Handler triggers repository_dispatch on wrapmate/.github
   ↓
6. GitHub Actions workflow runs immediately
   ↓
7. Constraints seeded automatically ✅
```

**Result**: Instant, event-driven automation with zero polling costs!

---

## Deployment Options

### Option 1: Cloudflare Workers (Recommended - Free Tier Available)

**Setup:**

1. **Install Wrangler CLI:**
   ```bash
   npm install -g wrangler
   ```

2. **Login to Cloudflare:**
   ```bash
   wrangler login
   ```

3. **Create wrangler.toml:**
   ```toml
   name = "wrapmate-github-webhook"
   main = "index.js"
   compatibility_date = "2024-01-01"

   [vars]
   # Environment variables

   # Add secret via: wrangler secret put GITHUB_TOKEN
   # Use the same GH_PAT token from organization secrets
   ```

4. **Add GitHub token secret:**
   ```bash
   wrangler secret put GITHUB_TOKEN
   # Paste your GH_PAT token when prompted
   ```

5. **Deploy:**
   ```bash
   wrangler deploy
   ```

6. **Get webhook URL:**
   - After deployment, Wrangler shows the URL
   - Example: `https://wrapmate-github-webhook.your-subdomain.workers.dev`

---

### Option 2: Vercel Serverless Function

**Setup:**

1. **Create vercel.json:**
   ```json
   {
     "functions": {
       "api/webhook.js": {
         "memory": 128,
         "maxDuration": 10
       }
     }
   }
   ```

2. **Create api/webhook.js:**
   ```javascript
   export default async function handler(req, res) {
     if (req.method !== 'POST') {
       return res.status(405).json({ error: 'Method not allowed' });
     }

     const { action, repository, sender, organization } = req.body;

     if (action !== 'created') {
       return res.status(200).json({ message: 'Event ignored' });
     }

     const dispatchUrl = `https://api.github.com/repos/${organization.login}/.github/dispatches`;

     const response = await fetch(dispatchUrl, {
       method: 'POST',
       headers: {
         'Accept': 'application/vnd.github+json',
         'Authorization': `Bearer ${process.env.GITHUB_TOKEN}`,
         'X-GitHub-Api-Version': '2022-11-28',
         'Content-Type': 'application/json'
       },
       body: JSON.stringify({
         event_type: 'repository_created',
         client_payload: {
           repository: repository.name,
           creator: sender.login,
           created_at: repository.created_at,
           full_name: repository.full_name
         }
       })
     });

     if (response.ok) {
       return res.status(200).json({ success: true });
     } else {
       return res.status(500).json({ success: false });
     }
   }
   ```

3. **Deploy:**
   ```bash
   vercel --prod
   vercel env add GITHUB_TOKEN production
   # Paste your GH_PAT token
   ```

4. **Get webhook URL:**
   - Example: `https://your-project.vercel.app/api/webhook`

---

### Option 3: AWS Lambda (More Complex)

**Setup:**

1. Create Lambda function with Node.js runtime
2. Use API Gateway to expose HTTP endpoint
3. Add GITHUB_TOKEN as environment variable
4. Deploy code from `index.js`

---

## Configure GitHub Organization Webhook

Once your webhook handler is deployed:

1. **Go to organization settings:**
   ```
   https://github.com/organizations/wrapmate/settings/hooks
   ```

2. **Click "Add webhook"**

3. **Configure:**
   - **Payload URL**: Your deployed webhook URL
   - **Content type**: `application/json`
   - **Secret**: (Optional but recommended) Generate a random secret
     ```bash
     openssl rand -hex 32
     ```
   - **SSL verification**: Enable
   - **Which events**: Select "Let me select individual events"
     - ✅ Check **only** "Repositories"
   - **Active**: ✅ Checked

4. **Save**

---

## Testing

### Test 1: Manual Trigger

You can manually trigger the workflow to test:

```bash
gh api repos/wrapmate/.github/dispatches \
  -X POST \
  -f event_type=repository_created \
  -f client_payload[repository]=test-repo \
  -f client_payload[creator]=j-bob-wm
```

Check workflow runs:
```bash
gh run list --repo wrapmate/.github --limit 1
```

### Test 2: Create Test Repository

As j-bob-wm:
```bash
gh repo create wrapmate/test-lovable-webhook --private
```

Within seconds:
1. Webhook fires
2. Handler triggers workflow
3. Constraints are seeded
4. Check: `gh api /repos/wrapmate/test-lovable-webhook/contents/.lovable`

---

## Monitoring

### Check Webhook Deliveries

1. Go to: https://github.com/organizations/wrapmate/settings/hooks
2. Click on your webhook
3. Click "Recent Deliveries"
4. View request/response for each event

### Check Workflow Runs

```bash
gh run list --repo wrapmate/.github
```

### Check Handler Logs

**Cloudflare Workers:**
```bash
wrangler tail
```

**Vercel:**
```bash
vercel logs
```

---

## Troubleshooting

### Webhook not firing

**Check:**
1. Webhook is active in org settings
2. "Repositories" event is selected
3. Payload URL is correct
4. SSL verification passes

### Handler receives webhook but workflow doesn't run

**Check:**
1. GITHUB_TOKEN environment variable is set correctly
2. Token has `repo` and `workflow` permissions
3. Check handler logs for errors
4. Verify dispatch API call succeeds

### Workflow runs but constraints not seeded

**Check:**
1. Creator is j-bob-wm (check workflow logs)
2. GH_PAT secret is configured in org
3. Seeding script succeeds (check logs)

---

## Cost Comparison

| Method | Cost | Latency | Pros | Cons |
|--------|------|---------|------|------|
| **Polling (5 min)** | $0.008/run × 288/day = ~$70/year | Up to 5 min | Simple | Wastes GitHub Actions minutes |
| **Cloudflare Workers** | Free (100k requests/day) | <100ms | Instant, free | Requires deployment |
| **Vercel** | Free (100GB-hrs/mo) | <100ms | Instant, easy deploy | Rate limits |
| **AWS Lambda** | ~$0.20/million requests | <500ms | Scalable | More complex setup |

**Recommended**: Cloudflare Workers (free + instant + reliable)

---

## Security Best Practices

1. **Verify webhook signatures:**
   ```javascript
   const crypto = require('crypto');
   const signature = request.headers.get('X-Hub-Signature-256');
   const body = await request.text();
   const hash = 'sha256=' + crypto
     .createHmac('sha256', env.WEBHOOK_SECRET)
     .update(body)
     .digest('hex');

   if (signature !== hash) {
     return new Response('Invalid signature', { status: 401 });
   }
   ```

2. **Use environment variables** for secrets (never hardcode)

3. **Enable SSL verification** on GitHub webhook

4. **Rotate tokens** periodically

5. **Monitor webhook delivery** failures

---

## Maintenance

**To update:**
1. Modify `index.js`
2. Redeploy: `wrangler deploy` or `vercel --prod`
3. Test with manual dispatch

**To add more creators:**
```javascript
const ALLOWED_CREATORS = ['j-bob-wm', 'another-user'];
if (!ALLOWED_CREATORS.includes(creator)) {
  // Skip
}
```

---

## Next Steps

1. ✅ Deploy webhook handler to Cloudflare Workers
2. ✅ Configure organization webhook
3. ✅ Test with `gh api` manual dispatch
4. ✅ Test with real repo creation
5. ✅ Monitor first few runs
6. ✅ Document for team

**Result**: Instant, event-driven constraint seeding with zero polling costs! 🚀
