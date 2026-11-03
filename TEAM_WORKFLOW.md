# ZEGA-ALERT — Team Collaboration Workflow (5-person team)

This guide defines how our team works together on this repo and how changes
reach the live deployment.

## 1. Branch model

| Branch | Purpose | Rules |
| --- | --- | --- |
| `master` | Always-deployable code. Every push auto-deploys to Render (`autoDeploy: true`). | Protect it. Never push broken code. |
| `feature/<name>` | One feature or fix per branch, e.g. `feature/sos-dispatch-fix` | Branch from latest `master` |
| `fix/<name>` | Bug fixes, e.g. `fix/login-otp-403` | Branch from latest `master` |

```bash
# start new work — always branch from the latest master
git checkout master
git pull origin master
git checkout -b feature/my-feature

# save your work often
git add <files>
git commit -m "feat: short description of what changed"

# share your branch
git push origin feature/my-feature
```

## 2. Commit message convention

Format: `type: what changed` (lowercase, imperative)

- `feat:` new feature — `feat: add sightings map to admin portal`
- `fix:` bug fix — `fix: mount /api/staff roster for dispatcher role`
- `docs:` documentation — `docs: update DEPLOY.md env table`
- `refactor:` code cleanup without behaviour change
- `chore:` config, deps, CI — `chore: bump socket.io version`

## 3. Merging to master

1. Push your feature branch and open a **Pull Request** on GitHub
   (`Compare & pull request` button).
2. Ask **one teammate** to review before merging — two eyes catch most bugs.
3. Merge with **"Create a merge commit"** or **"Squash and merge"** (squash
   keeps the master history clean for small features).
4. Delete the feature branch after merging.
5. Watch the Render dashboard — the auto-deploy starts on merge.

> Hotfix exception: for a critical production bug you may push directly to
> `master`, but announce it in the team group chat first.

## 4. Before you push — checklist

- [ ] `git pull origin master` first, resolve conflicts locally if any
- [ ] Backend: `npm start` runs and `GET /health` returns OK
- [ ] Admin-web: `npm run build` succeeds with no errors
- [ ] No `.env`, Firebase service-account JSON, or `google-services.json`
      staged (they are git-ignored — keep it that way)
- [ ] No `console.log` debug spam left in the code

## 5. Deployment flow (Render)

`git push origin master` → Render detects the push → rebuilds
`zega-alert-api` (Docker) + `zega-alert-admin` (static site) → health check
`GET /health` must pass, otherwise Render keeps the previous release.

Rollback: Render dashboard → `zega-alert-api` → **Events** → redeploy an
earlier deploy.

## 6. Suggested role split (5 people)

| Role | Owner | Scope |
| --- | --- | --- |
| Backend / API & DB | — | `backend/`, schema, dispatch engine |
| Admin portal | — | `admin-web/` dashboards |
| Mobile app | — | `mobile/` Flutter screens |
| Deployment & DevOps | — | `render.yaml`, secrets, Render dashboard |
| QA / docs | — | `postman/` collections, README/DEPLOY accuracy |

Fill in the names of who owns what and keep this table updated.

## 7. Token & secret safety

- Never commit `.env` or any service-account JSON.
- Never share a GitHub Personal Access Token in chat groups — share it
  through a password manager, and **rotate it if it was ever exposed**.
- Prefer fine-grained tokens (Settings → Developer settings → Fine-grained
  tokens) limited to this repo only.
