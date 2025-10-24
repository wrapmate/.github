# Wrapmate Organization Settings

Organization-level configurations for Wrapmate.

## Lovable Constraint Seeding

**Current Approach:** Manual seeding script

After Product syncs a Lovable project to GitHub, run:

```bash
cd ~/lovable-prototype-template
./scripts/seed-lovable-constraints.sh proto-[project-name]
```

Takes ~10 seconds, adds all constraint files automatically.

**Configuration:**
- ✅ Template source: `wrapmate/lovable-prototype-template`
- ✅ Commits as: `devops-wm <devops@wrapmate.com>`
- ✅ Can be run by Product or Engineering

**Why Manual?** GitHub Actions cannot listen to `repository.created` events at the org level. Manual script is simple and reliable.

---

# Organization-Level GitHub Actions for Lovable Constraints

This repository contains GitHub Actions workflows that automatically seed engineering constraints into new Lovable repositories.

---

## How It Works

```
1. Product creates Lovable project
   ↓
2. Product syncs to GitHub (Lovable creates repo)
   ↓
3. GitHub webhook fires (repository.created event)
   ↓
4. GitHub Action automatically adds constraint files
   ↓
5. Lovable reads constraints on next prompt
   ↓
6. Product continues building with standards enforced ✅
```

**Result**: Zero manual work, constraints applied automatically in ~30 seconds!

---

## Setup Instructions

### Option 1: Organization-Level Workflow (Recommended)

This sets up automation for **all repos** in your organization.

#### Step 1: Create Organization Workflow

1. Go to your organization settings:
   ```
   https://github.com/organizations/wrapmate/settings/actions
   ```

2. Navigate to **"Actions"** → **"General"** → **"Workflow permissions"**
   - Ensure workflows can create/approve pull requests

3. Create organization workflow repository:
   ```bash
   # Create special repo for org-level workflows
   gh repo create wrapmate/.github --public

   # Clone it
   gh repo clone wrapmate/.github
   cd .github

   # Create workflows directory
   mkdir -p workflow-templates

   # Copy the workflow
   cp path/to/auto-seed-lovable-constraints.yml workflow-templates/
   ```

4. Push to GitHub:
   ```bash
   git add .
   git commit -m "Add auto-seed workflow for Lovable constraints"
   git push
   ```

#### Step 2: Create GitHub Personal Access Token (PAT)

The workflow needs a PAT with repo permissions:

1. Go to: https://github.com/settings/tokens/new
2. Name: `Lovable Constraints Bot`
3. Expiration: No expiration (or 1 year)
4. Select scopes:
   - ✅ `repo` (all)
   - ✅ `workflow`
5. Click **"Generate token"**
6. Copy the token (you won't see it again!)

#### Step 3: Add PAT to Organization Secrets

1. Go to: https://github.com/organizations/wrapmate/settings/secrets/actions
2. Click **"New organization secret"**
3. Name: `GH_PAT`
4. Value: [paste your PAT]
5. Repository access: **"All repositories"** or **"Selected repositories"**
6. Click **"Add secret"**

#### Step 4: Customize the Workflow

Edit `auto-seed-lovable-constraints.yml`:

**Filter by repo name:**
```yaml
if: |
  startsWith(github.event.repository.name, 'proto-') ||
  startsWith(github.event.repository.name, 'lovable-')
```

**Filter by creator (Product team only):**
```yaml
ALLOWED_CREATORS=("shawn-holmes" "product-user-1" "product-user-2")
```

**Or disable creator filtering** (run for all new repos):
```yaml
# Comment out the creator check, uncomment this:
echo "should_seed=true" >> $GITHUB_OUTPUT
```

---

### Option 2: Per-Repository Webhook (Alternative)

If you can't use org-level workflows, set up a webhook handler:

1. Deploy webhook handler (e.g., AWS Lambda, Cloudflare Worker)
2. Add webhook to GitHub org:
   ```
   Settings → Webhooks → Add webhook
   Payload URL: https://your-webhook-handler.com
   Events: "Repositories"
   ```
3. Webhook receives `repository.created` event
4. Webhook runs seeding script

---

## Manual Usage (Fallback)

If automation isn't set up yet, Product or Engineering can run manually:

```bash
# Clone template repo
gh repo clone wrapmate/lovable-prototype-template

# Run seeding script
cd lovable-prototype-template
./scripts/seed-lovable-constraints.sh proto-new-project

# Takes 10 seconds
```

---

## Testing the Automation

### Test 1: Create a Test Repo

```bash
# Create a test repo that matches the pattern
gh repo create wrapmate/proto-test-automation --private

# Wait 30-60 seconds

# Check if constraints were added
gh repo clone wrapmate/proto-test-automation
cd proto-test-automation
ls -la .lovable/

# Should see: constraints.md, README.md
```

### Test 2: Verify in Lovable

1. Create Lovable project
2. Sync to GitHub (name it `proto-something`)
3. Wait 30 seconds
4. Refresh GitHub repo - constraints should appear
5. Ask Lovable: "Can you see .lovable/constraints.md?"
6. Lovable should list the constraints ✅

---

## Troubleshooting

### Workflow doesn't run

**Check:**
1. Workflow is in the right place (`.github/workflows-templates/` in `.github` repo)
2. PAT secret is named exactly `GH_PAT`
3. PAT has `repo` and `workflow` permissions
4. Repository name matches the filter pattern

**Debug:**
- Check workflow runs: https://github.com/wrapmate/.github/actions
- View logs for errors

### Constraints not added

**Check:**
1. Workflow completed successfully
2. Constraints don't already exist in repo
3. Template repo URL is correct in workflow
4. Network access isn't blocked

**Manual fix:**
```bash
./scripts/seed-lovable-constraints.sh repo-name
```

### Lovable doesn't see constraints

**Check:**
1. Files are in `.lovable/` directory (not `lovable/`)
2. File is named exactly `constraints.md`
3. File is on the main branch
4. Lovable project is synced to correct repo

**Test:**
Ask Lovable: "List all files in the .lovable directory"

---

## Customization

### Change which repos trigger automation

Edit the `if` condition in the workflow:

```yaml
# Only repos starting with "proto-"
if: startsWith(github.event.repository.name, 'proto-')

# Only repos in specific org
if: github.event.repository.owner.login == 'wrapmate'

# Only repos by specific users
if: github.event.sender.login == 'product-user'

# Combine conditions
if: |
  startsWith(github.event.repository.name, 'proto-') &&
  github.event.sender.login == 'product-user'
```

### Change template source

Edit the workflow:

```yaml
TEMPLATE_REPO="your-org/your-template"
TEMPLATE_BRANCH="main"
```

### Add more files

Edit the workflow's fetch step to include additional files:

```yaml
curl -s "${BASE_URL}/your-custom-file.md" > your-custom-file.md
```

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│  1. Product creates Lovable project                         │
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────┐
│  2. Product syncs to GitHub                                 │
│     Lovable creates repo: wrapmate/proto-my-feature         │
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────┐
│  3. GitHub fires webhook: repository.created                │
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────┐
│  4. GitHub Action runs (org-level)                          │
│     - Checks repo name matches pattern                      │
│     - Checks creator is authorized (optional)               │
│     - Waits 30s for Lovable to finish                       │
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────┐
│  5. Action downloads constraints from template              │
│     - .lovable/constraints.md                               │
│     - .lovable/README.md                                    │
│     - docs/HANDOFF_CHECKLIST.md                             │
│     - .cursorrules                                          │
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────┐
│  6. Action commits and pushes to repo                       │
│     Commit message: "chore: Add Lovable constraints"        │
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────┐
│  7. Action creates issue notification                       │
│     Title: "✅ Engineering constraints added"               │
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────┐
│  8. Product continues in Lovable                            │
│     Lovable reads .lovable/constraints.md automatically     │
│     Code follows engineering standards ✅                    │
└─────────────────────────────────────────────────────────────┘
```

---

## Benefits

✅ **Zero Product effort** - Fully automated
✅ **Consistent standards** - Every Lovable project gets constraints
✅ **Fast** - Constraints added in ~30 seconds
✅ **Auditable** - GitHub issue tracks when constraints added
✅ **Flexible** - Easy to customize filters and conditions
✅ **Reliable** - Automated, no human error

---

## Next Steps

1. **Set up org-level workflow** (follow Option 1 above)
2. **Test with a new repo** (create `proto-test`)
3. **Verify Lovable sees constraints** (ask it!)
4. **Roll out to Product team** (it just works!)
5. **Monitor** (check GitHub Action runs occasionally)

---

## Support

**Issues with automation?**
- Check GitHub Action logs
- Verify PAT permissions
- Test manual seeding script first

**Questions?**
- Review this README
- Check template repo: https://github.com/wrapmate/lovable-prototype-template
- Contact engineering team

**Want to modify?**
- Edit workflow conditions
- Customize constraint files
- Add additional automation steps
