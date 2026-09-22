![Clever Cloud logo](/github-assets/clever-cloud-logo.png)

# Outline on Clever Cloud

[![Outline – Team knowledge base & wiki](https://img.shields.io/badge/Outline-Team%20knowledge%20base%20%26%20wiki-blue)](https://www.getoutline.com/)
[![Clever Cloud - PaaS](https://img.shields.io/badge/Clever%20Cloud-PaaS-orange)](https://clever-cloud.com)

Deploy [Outline](https://www.getoutline.com/), a collaborative knowledge base and wiki, on Clever Cloud with the Linux runtime, [Mise](https://mise.jdx.dev/), PostgreSQL, Redis, and Cellar S3-compatible object storage.

This example was tested with Outline `v1.9.2`. Mise downloads the selected release during the build phase, so the repository only contains the deployment configuration. Outline recommends Docker for self-hosted installations, but it also [documents installation from source](https://docs.getoutline.com/s/hosting/doc/from-source-BlBxrNzMIP).

## Prerequisites

- A [Clever Cloud account](https://console.clever-cloud.com/)
- [Clever Tools](https://www.clever.cloud/developers/doc/cli/) configured for that account
- [curl](https://curl.se/)
- [Git](https://git-scm.com/downloads)
- [OpenSSL](https://openssl-library.org/)
- [s3cmd](https://s3tools.org/s3cmd)
- An [authentication provider supported by Outline](#configure-authentication)

## Prepare the repository

Clone this repository:

```bash
git clone https://github.com/CleverCloud/outline-example.git
cd outline-example
```

The `mise.toml` file downloads Outline, installs its dependencies, builds it, maps linked add-on variables to the names expected by Outline, and defines the `build` and `run` tasks automatically used by the Clever Cloud Linux runtime.

## Create the application and add-ons

Create a Linux application with an alias, then create and link PostgreSQL, Redis, and Cellar add-ons:

```bash
clever create -t linux -a myOutline

clever addon create postgresql-addon myOutlinePostgreSQL -p xxs_sml --link myOutline
clever addon create redis-addon myOutlineRedis -p s_mono --link myOutline
clever addon create cellar-addon myOutlineCellar --link myOutline
```

Clever Tools targets your personal organisation by default. To use another organisation, add `--org ORGANISATION` or `-o ORGANISATION` to commands that support it.

Display the application URL. You can also add a [custom domain](https://www.clever.cloud/developers/doc/administrate/domain-names/), which requires DNS configuration:

```bash
clever domain
clever domain add your.website.tld
```

## Configure Cellar

Set the exact HTTPS origin returned by `clever domain`, without a trailing slash, and choose a globally unique bucket name containing only lowercase letters, numbers, dots, and hyphens:

```bash
export OUTLINE_URL="https://your-outline-domain.example.com"
export OUTLINE_BUCKET="your-unique-outline-bucket"
```

Load the Cellar credentials injected by the linked add-on and run the configuration script:

```bash
source <(clever env -F shell | grep '^export CELLAR_ADDON_')
./configure-cellar.sh
unset CELLAR_ADDON_KEY_ID CELLAR_ADDON_KEY_SECRET CELLAR_ADDON_HOST
```

The script creates a private bucket and applies the CORS policy required for direct browser uploads from your Outline origin. Downloads remain private and use temporary URLs signed by Outline.

## Configure Outline

Set the tested Outline and Node.js versions. For another Outline release, select a Node.js version accepted by `engines.node` in that release's `package.json`; for example, see the [requirements for v1.9.2](https://github.com/outline/outline/blob/v1.9.2/package.json#L44-L46).

```bash
clever env set OUTLINE_VERSION v1.9.2
clever env set CC_NODE_VERSION 26.3.0
clever env set CC_NODE_BUILD_TOOL yarn-berry

clever env set SECRET_KEY "$(openssl rand -hex 32)"
clever env set UTILS_SECRET "$(openssl rand -base64 32)"
clever env set NODE_ENV production
clever env set WEB_CONCURRENCY 1
clever env set DEFAULT_LANGUAGE en_US
clever env set URL "$OUTLINE_URL"
clever env set FILE_STORAGE s3
clever env set FILE_STORAGE_UPLOAD_MAX_SIZE 262144000
clever env set AWS_REGION default
clever env set AWS_S3_UPLOAD_BUCKET_NAME "$OUTLINE_BUCKET"
```

`WEB_CONCURRENCY` controls the number of Outline processes started inside each application instance. Outline recommends roughly one process per 512 MB of available memory, so this example keeps the value at `1` for the default `XS` run instance. Increase it only on a larger instance and after monitoring the application's memory and CPU usage. The Mise environment also sets `REDIS_COLLABORATION_URL` from the linked Redis add-on, as required by Outline's [horizontal scaling documentation](https://docs.getoutline.com/s/hosting/doc/horizontal-scaling-hkfU5Stao7), so collaborative editing remains synchronized if you later run several processes or application instances.

`DEFAULT_LANGUAGE` controls the default interface language; replace `en_US` with another [Outline language code](https://translate.getoutline.com/) if needed. `FILE_STORAGE_UPLOAD_MAX_SIZE` is expressed in bytes: `262144000` sets a 250 MiB attachment limit and matches Outline's [versioned environment sample](https://github.com/outline/outline/blob/v1.9.2/.env.sample). You can configure a larger value, but Outline applies it to the [`content-length-range` condition of each presigned S3 upload](https://github.com/outline/outline/blob/v1.9.2/server/storage/files/S3Storage.ts#L44-L67), so test the intended size with your network and storage service before increasing it. Document and workspace imports can use separate limits; see Outline's [file storage documentation](https://docs.getoutline.com/s/hosting/doc/file-storage-N4M0T6Ypu7).

Outline's build needs more memory than the default build instance provides. Use an `M` build instance; the application keeps the default `XS` run instance:

```bash
clever scale --build-flavor M
```

### Configure authentication

Outline needs at least one authentication method before users can sign in:

| Authentication method | Required variables | Callback URL |
| --- | --- | --- |
| Discord | `DISCORD_CLIENT_ID`, `DISCORD_CLIENT_SECRET` | `$URL/auth/discord.callback` |
| Email magic links | `SMTP_HOST` or `SMTP_SERVICE`, `SMTP_FROM_EMAIL` | — |
| Google | `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` | `$URL/auth/google.callback` |
| Microsoft Entra ID | `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET` | `$URL/auth/azure.callback` |
| OpenID Connect | `OIDC_CLIENT_ID`, `OIDC_CLIENT_SECRET`, `OIDC_ISSUER_URL` | `$URL/auth/oidc.callback` |
| Slack | `SLACK_CLIENT_ID`, `SLACK_CLIENT_SECRET` | `$URL/auth/slack.callback` |

Email magic links require a complete [SMTP configuration](https://docs.getoutline.com/s/hosting/doc/smtp-cqCJyZGMIB), including the credentials and connection settings required by your email provider.

Configure the matching callback URL in your provider, then set its variables. For OpenID Connect, also allow the application URL (`$URL`) as a post-logout redirect URI if the provider exposes a logout endpoint. For example:

```bash
clever env set OIDC_CLIENT_ID "YOUR_CLIENT_ID"
clever env set OIDC_CLIENT_SECRET "A_STRONG_CLIENT_SECRET"
clever env set OIDC_ISSUER_URL "https://your-provider.example.com"
clever env set OIDC_DISPLAY_NAME "Company SSO"
```

The first user to create an Outline workspace becomes its administrator. Once signed in, users can register passkeys for subsequent authentication. SAML authentication is only available in licensed editions.

## Deploy Outline

Deploy the application:

```bash
clever deploy
```

Check that Outline can reach PostgreSQL and Redis:

```bash
curl "$OUTLINE_URL/_health"
```

It returns `OK` when both dependencies are available. Open the application and sign in with the authentication provider you configured:

```bash
clever open
```

## Update Outline

Create a recent [PostgreSQL backup](https://www.clever.cloud/developers/doc/addons/postgresql/#database-daily-backup-and-retention) before updating. Check the target release's `engines.node` requirement, update both version variables when necessary, then rebuild without the deployment cache. For example:

```bash
clever env set OUTLINE_VERSION v1.9.2
clever env set CC_NODE_VERSION 26.3.0
clever restart --without-cache
```

Outline applies pending database migrations when the new version starts.

## Contributing

Contributions that improve this deployment example are welcome. Open an issue or submit a pull request with your proposed changes.

## License

This example is provided under the terms of the MIT license.
