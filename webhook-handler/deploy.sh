#!/bin/bash

# Quick deployment script for Cloudflare Workers webhook handler

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Deploying GitHub Webhook Handler"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if wrangler is installed
if ! command -v wrangler &> /dev/null; then
    echo "❌ Wrangler CLI not found"
    echo ""
    echo "Install it with:"
    echo "  npm install -g wrangler"
    echo ""
    exit 1
fi

echo "✓ Wrangler CLI found"
echo ""

# Check if logged in
if ! wrangler whoami &> /dev/null; then
    echo "❌ Not logged in to Cloudflare"
    echo ""
    echo "Login with:"
    echo "  wrangler login"
    echo ""
    exit 1
fi

echo "✓ Logged in to Cloudflare"
echo ""

# Deploy
echo "Deploying webhook handler..."
wrangler deploy

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Deployment Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Get the deployed URL
WORKER_URL=$(wrangler deployments list --name wrapmate-github-webhook 2>/dev/null | grep -oE 'https://[^[:space:]]+' | head -1 || echo "")

if [ -n "$WORKER_URL" ]; then
    echo "Webhook URL: $WORKER_URL"
    echo ""
fi

echo "Next steps:"
echo ""
echo "1. Add GitHub token secret:"
echo "   wrangler secret put GITHUB_TOKEN"
echo "   (Use the same GH_PAT token from organization secrets)"
echo ""
echo "2. Configure GitHub organization webhook:"
echo "   https://github.com/organizations/wrapmate/settings/hooks"
echo "   - Payload URL: $WORKER_URL"
echo "   - Content type: application/json"
echo "   - Events: Repositories only"
echo ""
echo "3. Test with manual dispatch:"
echo "   gh api repos/wrapmate/.github/dispatches \\"
echo "     -X POST \\"
echo "     -f event_type=repository_created \\"
echo "     -f client_payload[repository]=test-repo \\"
echo "     -f client_payload[creator]=j-bob-wm"
echo ""
echo "See README.md for complete instructions"
echo ""
