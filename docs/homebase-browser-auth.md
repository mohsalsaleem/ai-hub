# Optional Homebase browser authentication

Implemented on 2026-09-09. Production Homebase credentials have not been provisioned. Integration remains off until explicitly configured.

## Audit and scope

AI Hub has three independent authentication boundaries:

- Tenant users sign in with a password and a signed cookie referencing a database session. Organization memberships determine owner/member permissions. Homebase links to this existing user, keeping all memberships and permissions.
- Platform operators have separate records, credentials and session cookies. A Homebase tenant identity does not grant platform access. Platform sign-in remains independent.
- Applications, workers and enrollment flows use their own credentials. Application credentials belong to an organization, not directly to an individual user. Homebase users manage them through the same owner checks as password users. Existing bearer authentication, enrollment, token rotation, long polling and OpenAI-compatible endpoints are unchanged.

AI Hub serves other users as well as the Homebase owner. Public registration and local password sign-in remain available, including during Homebase outages. No enforced mode is implemented. Revoking a Homebase grant stops that identity's Homebase sessions; it does not disable the independent AI Hub account, password, organization tokens or workers.

## User journey

1. Sign in with the existing AI Hub password.
2. Open **Account security**, available in the sidebar and Settings navigation.
3. Enter the current AI Hub password and choose **Link Homebase**.
4. Complete fresh Homebase authentication. The callback must return to the same user and browser session that initiated linking.
5. Future browser sign-ins can use **Continue with Homebase**, or the original password.

Identity is the verified issuer plus subject. Email is never used to merge accounts. An unknown Homebase subject must first link to an existing account. Linking creates no user, organization, membership, token or platform role. Personal linking remains available even without an organization.

## Security behavior

Authorization code flow uses S256 PKCE, nonce, state and single-use database transactions expiring after ten minutes. Linking requires Rails CSRF protection, local password proof and fresh provider `auth_time`. ID tokens require an RS256 signature and valid issuer, audience, authorized party, nonce and expiry. Provider metadata endpoints must remain on the issuer origin.

Provider tokens stay in the server-side session record, encrypted with AES-256-GCM and a purpose-specific key derived from the existing Rails secret. Keep `SECRET_KEY_BASE` stable. Cookies contain only a signed session ID and expire after eight hours for Homebase sessions. Authentication resets Rails session state and retains only an organization selection belonging to the authenticated user.

Homebase sessions check their identity mapping, lifetime, app grant and provider token status on resumption. Refresh rotation is persisted encrypted. Invalid refresh grants invalidate the browser session; outages preserve the session and render a recovery page with a working password-login path. Logout removes the local session even if provider logout is unavailable. Homebase recovery pages do not recursively resume the failing session.

Refresh coordination currently uses a process-local mutex. Run one Puma process; introduce cross-process coordination before scaling the browser application. Browser auth responses are not cached. Callback parameters and provider credentials are filtered from Rails parameter logs.

## Future production configuration

Provision a dedicated confidential Keycloak client and a dedicated Homebase integration credential for the existing Homebase catalog ID **`aihub`**. Do not reuse another app's key.

```dotenv
HOMEBASE_AUTH_MODE=linking
PUBLIC_URL=https://aihub.mohsal.dev
OIDC_ISSUER=https://auth.mohsal.dev/realms/homebase
OIDC_CLIENT_ID=aihub
OIDC_CLIENT_SECRET=<dedicated Keycloak secret>
HOMEBASE_URL=https://homebase.mohsal.dev
HOMEBASE_APP_KEY=<dedicated Homebase access-check credential>
```

Keycloak: standard code flow only, client authentication enabled, S256 PKCE, default basic/profile/email scopes, access-token audience `aihub`. Callback is exactly `https://aihub.mohsal.dev/auth/homebase/callback`; post-logout URI is `https://aihub.mohsal.dev/session/new`. Direct/password grants and implicit flow should remain disabled for this client.

The additive migration `20260909120000_add_homebase_browser_identity` adds identity and login-transaction tables plus nullable encrypted-provider-session fields. It does not modify tenant, application or worker records. Back up and rehearse the migration before production release. Update `.coolify/deploy.yaml` when provisioning is authorized. No proxy changes are required.

To disable the optional integration, set `HOMEBASE_AUTH_MODE=off` and redeploy. Homebase sessions then stop resuming; password sign-in remains available. Keep the additive schema and Rails secret.

After an authorized deployment, verify the public login page and live provider redirect, then have the owner link their account and check login/logout, organization selection, application token issuance, worker operation and the separate platform sign-in. Local testing does not establish that the production provider/client is configured.

## Validation

- Full Rails suite: **151 tests, 780 assertions, zero failures or errors**.
- Rails `zeitwerk:check` passed.
- New Ruby files and focused auth tests pass the repository RuboCop rules.
- Tests cover real JWT signatures and claims, fresh authentication, PKCE, state/expiry/replay, CSRF, password proof, changed browser identities, no email merging, unique mappings, encrypted sessions, invalid/expired/revoked sessions and refresh-outage behavior.
- Integration tests verify unchanged registration and password login, organization-scoped application creation/token rotation, member restrictions, platform isolation, and automation credentials surviving browser logout. Existing worker, enrollment and OpenAI compatibility tests pass.
- Local Chromium with a separate synthetic SQLite database verified desktop/mobile login and linking forms, real password sign-in, incorrect-password feedback, and provider-outage recovery. Screenshots are in ignored `tmp/homebase/`.
- Fixed an existing date-dependent worker-schedule test fixture by setting its job availability to the same historical clock used by the test. Worker runtime behavior was not changed.

Concurrent branding/icon changes were preserved. They are separate from this auth implementation.
