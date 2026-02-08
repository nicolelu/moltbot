# Local Changes (nicolelu fork)

Changes made to this fork on 2026-02-08. This document exists to help
troubleshoot if anything breaks after these changes.

---

## 1. Block email sending via gog (commit: 4d3e0f659^)

**What changed:**
- `skills/gog/SKILL.md` — Removed all `gog gmail send` and `gog gmail drafts send`
  references. Replaced with `gog gmail drafts create` equivalents.
- `scripts/gog-wrapper.sh` — New file. Wrapper script that intercepts gog calls and
  blocks `gmail send` and `drafts send` commands.
- `Dockerfile` — After installing gog, renames it to `gog-real` and installs the
  wrapper as `gog`.

**What still works:** Gmail search, Gmail drafts create, Calendar (all commands),
Drive, Contacts, Sheets, Docs.

**What is blocked:** `gog gmail send *`, `gog gmail drafts send *`.

**If email sending needs to be re-enabled:**
- Quick: `docker exec moltbot-gateway bash -c 'cp /usr/local/bin/gog-real /usr/local/bin/gog'`
  (temporary, lost on container restart)
- Permanent: Revert the Dockerfile changes and rebuild.

**If gog commands fail unexpectedly:**
- Check if the wrapper is interfering: `docker exec moltbot-gateway cat /usr/local/bin/gog`
  — if it shows the wrapper script, the real binary is at `/usr/local/bin/gog-real`.
- Test the real binary directly: `docker exec moltbot-gateway gog-real <command>`

---

## 2. docker-compose.yml customization (commit: 2aa0ffee5)

**What changed:** Replaced upstream `openclaw-*` service/env var naming with local
`moltbot-gateway` / `CLAWDBOT_*` naming. Single gateway service, loopback-only port
binding, local image build.

**If container fails to start after upstream pull:**
- Likely a merge conflict in docker-compose.yml. Resolve by keeping our service name
  (`moltbot-gateway`) and env var naming (`CLAWDBOT_*`), but accepting any new
  upstream config options.
- The `.env` file uses `CLAWDBOT_*` vars — if upstream renames these, update `.env`
  to match.

---

## 3. GOG_KEYRING_PASSWORD changed from default (not in git)

**What changed:** `GOG_KEYRING_PASSWORD` in `.env` was `change-me-now` (default).
Changed to a randomly generated 32-byte base64 password.

**The new password is in:** `/home/nicolelu/moltbot/.env` (line 9).

**If gog auth fails after restart:**
- The keyring tokens in `~/.moltbot/gogcli/keyring/` are encrypted with this password.
  If the password in `.env` doesn't match what was used to encrypt the tokens, gog
  will fail to decrypt them.
- To fix: re-authenticate with `docker exec -it moltbot-gateway gog auth add nicole@usesieve.com --services gmail,calendar,drive,contacts,docs,sheets`
- This will open a browser OAuth flow (may need to use `--no-browser` and copy the URL).

---

## 4. .env file permissions (not in git)

**What changed:** `/home/nicolelu/moltbot/.env` permissions changed from `644` to
`600` (owner read/write only).

**If other processes can't read .env:** This is intentional. Only the `nicolelu` user
(and root/docker) should read it. If a different user needs access, adjust with
`chmod 640` and add them to the appropriate group.

---

## 5. Git remotes and fork setup (not in git)

**What changed:**
- Forked `moltbot/moltbot` to `nicolelu/moltbot`.
- `origin` remote → `git@github.com:nicolelu/moltbot.git` (your fork, push here)
- `upstream` remote → `https://github.com/moltbot/moltbot.git` (pull updates from here)
- SSH key at `~/.ssh/id_ed25519` authenticates as `nicolelu` on GitHub.
- Git identity: `Nicole Lu <nicolelu@users.noreply.github.com>`

**To sync with upstream:**
```bash
cd ~/moltbot
git fetch upstream
git rebase upstream/main
git push origin main
```

**If rebase conflicts occur:** Resolve manually, keeping our local customizations
(gog wrapper, docker-compose.yml naming). Then `git rebase --continue && git push`.

**If SSH auth fails:**
- Test: `ssh -T git@github.com`
- Key location: `~/.ssh/id_ed25519`
- Key must be added at: https://github.com/settings/keys
- Start agent if needed: `eval "$(ssh-agent -s)" && ssh-add ~/.ssh/id_ed25519`
