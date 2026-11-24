# Glowpath leaderboard prototype

Review builds can enable **explicit local mocks**. **Apple Game Center is the planned iOS service for leaderboards and achievements; its client integration and App Store Connect configuration are not implemented yet.** The current league does not authenticate with or submit scores to Game Center, and local achievements are not synced to Apple.

This AWS/Lambda + Neon backend is an **undeployed prototype** available for local evaluation. It is not required by the web preview and does not implement the planned Game Center integration. The repository contains infrastructure definitions; it does not provide a hosted API or database.

## Preview without any service account

Run these commands from the repository root:

```sh
flutter build web --release --no-web-resources-cdn --dart-define=MOCK_SERVICES=true
flutter build ios --release --dart-define=MOCK_SERVICES=true
```

The iOS command still requires local signing configuration to install on a device. These are build instructions, not an installation record.

No `LEADERBOARD_URL`, AWS, Neon, AdMob or store configuration is needed. The preview league has four explicitly fictional pilots and the player's actual locally replayed challenge score. Joining, scores, rewards and the demo ad-free unlock persist on the device; leaving deletes the preview league identity and scores. Demo reward buttons show no ad, and demo purchases charge nothing. Mock data has separate preference keys and never becomes a live purchase entitlement or live league session.

`MOCK_SERVICES`, `ENABLE_ADS` and `ENABLE_PURCHASES` default to false. With all flags false, hints/skips remain free for review and the unconfigured live league explains that it is not open. Live ad units currently default to Google's test IDs. The App Store product `app.glowpath.remove_ads` and production AdMob configuration still need setup on the appropriate accounts before activation.

## Optional local API

Requires Node.js 24+, Dart 3.14 and the repository's installed Flutter dependencies. From the repository root:

```sh
mkdir -p backend/build
dart compile exe backend/validate_replay.dart -o backend/build/replay-validator
npm ci --prefix backend
npm test --prefix backend
cd backend
REPLAY_VALIDATOR="$PWD/build/replay-validator" node local.mjs
```

The server binds to `127.0.0.1:8787` and writes `backend/league.sqlite`. Override `HOST`, `PORT` or `LEAGUE_DB` deliberately. Browser development origins default to `http://127.0.0.1:8765` and `http://localhost:8765`; set `ALLOWED_ORIGINS` to change them. An optional localhost client build uses `--dart-define=LEADERBOARD_URL=http://127.0.0.1:8787` with mocks disabled. A physical phone's localhost points to the phone, so this is not a phone-server configuration.

| Route | Purpose |
| --- | --- |
| `GET /health` | Public readiness/rule version |
| `POST /v1/pilots` | Create an anonymous callsign and bearer token |
| `GET /v1/leaderboard/daily` or `/weekly` | Authenticated current-period standings |
| `POST /v1/results` | Authenticate and replay a completed challenge |
| `DELETE /v1/pilots/me` | Delete the pilot and all associated scores |

Days use UTC; weeks start Monday. The best score for each route is retained, with moves breaking ties. The top 50 pilots are returned. Tokens contain 256 random bits; only SHA-256 token hashes are stored. There is no email/contact collection. The client saves its bearer token on the device, so device compromise is outside this prototype's protection.

## Validation and limits

The server reconstructs the versioned `planet-v4` or `planet-v5` puzzle using the same Dart engine as the game. It rejects incomplete, illegal, post-win, stale-period and unsupported-layout action histories, and computes the score itself. The client-supplied score is ignored. Assisted routes do not qualify. This verifies puzzle consistency, **not human play**: an automated solver or modified client can generate a valid replay or falsely claim no assistance. Public competition requires a further abuse/attestation review.

Requests are limited to 16 KB and replays to 500 actions, with a three-second rule-process timeout. The local server limits each IP to 60 requests/minute. The prepared AWS template uses an API throttle of two requests/second, burst four, and Lambda reserved concurrency two, 512 MB memory and an eight-second timeout. These limits are not a spending cap. Seven-day diagnostic logs omit names, tokens, IP addresses and request bodies; signup abuse and operational budget monitoring still need review before public promotion.

The app's **Leave league** action deletes the remote identity and cascades to its scores. The schema includes this 90-day retention operation, but no production scheduler has been deployed:

```sql
DELETE FROM results WHERE period < CURRENT_DATE - 90;
```

Run it manually or configure a maintenance job when deploying. Local mock scores also prune old results on submission.

## Prototype container and deployment reference

Build from the repository root so Docker can compile a Linux validator from the shared rules:

```sh
docker build --platform linux/amd64 -f backend/Dockerfile -t glowpath-league:0.6.0 .
docker run --rm -i --platform linux/amd64 --entrypoint /var/task/rules glowpath-league:0.6.0 < backend/test/valid-replay.json
cfn-lint backend/cloudformation.json
```

The following is reference documentation for an optional future backend deployment. It is separate from the Game Center integration and static web hosting. Use a dedicated development environment and configure your own cloud accounts:

1. Create/configure Neon Postgres and apply `backend/schema.sql`; keep its URL out of client builds.
2. Store the database URL as the `DATABASE_URL` field in a Secrets Manager JSON secret, and push the tested `linux/amd64` image to ECR.
3. Validate `backend/cloudformation.json` with lint, security rules and account-aware predeployment checks. Deploy only against the intended Glowpath account, supplying its `ImageUri` and `DatabaseSecretArn` parameters.
4. Smoke-test registration, replay rejection, rankings and deletion; set retention maintenance and budget monitoring. Set the resulting HTTPS `LEADERBOARD_URL` in a build with mocks disabled.
5. Separately configure and sandbox-test the App Store product and production AdMob/consent setup before enabling their respective flags. Android purchase validation is not enabled.

There are no Neon credentials in this project. The local Docker image build and both Mac/Linux validator smoke replays passed. All eight backend tests passed, including four tests invoking the actual Dart executable. `cfn-lint` 1.61.0 passed; `cfn-guard` was not installed, and account-aware predeployment validation was not run. No deployment or native device installation is implied by these checks.
