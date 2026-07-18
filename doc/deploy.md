# Deploying to app.spaceforedu.com

The app deploys with Kamal to a single VPS. SQLite databases and uploaded
documents both live on the `spaceforedu_storage` Docker volume.

## One-time setup

1. **DNS** — point `app.spaceforedu.com` (A record) at the VPS IP.
2. **config/deploy.yml** — replace `YOUR_VPS_IP` with the server's public IP.
3. **Registry** — create a GitHub personal access token with `write:packages`
   and export it: `export KAMAL_REGISTRY_PASSWORD=<token>`.
4. **Credentials** — `bin/rails credentials:edit` and fill in:

   ```yaml
   stripe:
     secret_key: sk_live_...
     webhook_secret: whsec_...   # from the Stripe webhook endpoint for https://app.spaceforedu.com/stripe/webhooks
   smtp:
     user_name: ...              # Brevo SMTP login (Settings → SMTP & API)
     password: ...
   google:                       # optional — the Google button hides itself when absent
     client_id: ...
     client_secret: ...          # Google Cloud Console → OAuth client, redirect URI: https://app.spaceforedu.com/auth/google_oauth2/callback
   vapid:
     public_key: ...
     private_key: ...
   brand:
     support_email: info@spaceforedu.com
   active_record_encryption:
     primary_key: ...
     deterministic_key: ...
     key_derivation_salt: ...    # bin/rails db:encryption:init
   ```

5. **First deploy** — `kamal setup`.
6. **Super admin** (required — payment confirmation depends on it):

   ```bash
   kamal app exec --reuse 'env ADMIN_EMAIL=info@spaceforedu.com ADMIN_PASSWORD=<strong password> bin/rails db:seed'
   ```

7. **Stripe webhook** — in the Stripe dashboard add an endpoint for
   `https://app.spaceforedu.com/stripe/webhooks` subscribed to
   `payment_intent.succeeded` and `payment_intent.payment_failed`.
8. **Brevo** — verify the sending domain (SPF + DKIM records) so notification
   emails don't land in spam.

9. **Two-factor authentication** — after the first sign-in, open Profile →
   "Two-factor authentication" and set it up with any TOTP app. The admin
   account can download every client's passport; protect it. (If you lose the
   authenticator: `kamal console`, then
   `User.super_admin.update!(otp_secret: nil, otp_enabled_at: nil)`.)

## Every deploy

```bash
kamal deploy
```

## Error reports

Unhandled web and job errors are emailed (deduplicated, max one per unique
error per hour) to `brand.support_email` from credentials. If an email about a
failing job arrives, `kamal console` → `SolidQueue::FailedExecution.count` and
`.last.error` show what broke; `.last.retry` re-runs it after a fix.

## Backups

`DatabaseBackupJob` snapshots every SQLite database daily at 02:00 UTC into
`storage/backups/<date>/` (7 days kept) via `VACUUM INTO`. That protects
against bad migrations and fat-fingered deletes — **not** against losing the
server. Ship the whole volume off the machine daily; uploaded documents are
included because they live under `storage/` too.

Recommended (EU, ~€4/month): a Hetzner Storage Box + rclone on the host:

```bash
# /etc/cron.d/spaceforedu-backup — daily at 03:00, after the in-app snapshot
0 3 * * * root rclone sync /var/lib/docker/volumes/spaceforedu_storage/_data storagebox:spaceforedu --backup-dir storagebox:spaceforedu-history/$(date +\%F)
```

Restore drill (do this once before launch): copy a snapshot back over
`storage/production.sqlite3`, restart, verify the app comes up with the data.

## Disk encryption

Uploaded documents are passport-grade PII stored as plain files. Either create
the VPS with full-disk encryption, or place the Docker volume on a LUKS-encrypted
device. Database columns holding identity data are already encrypted by
Active Record Encryption, the files are not.
