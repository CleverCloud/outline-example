![Clever Cloud logo](/github-assets/clever-cloud-logo.png)

# Outline on Clever Cloud

[![Outline – Team knowledge base & wiki](https://img.shields.io/badge/Outline-Team%20knowledge%20base%20%26%20wiki-blue)](https://www.getoutline.com/)
[![Clever Cloud - PaaS](https://img.shields.io/badge/Clever%20Cloud-PaaS-orange)](https://clever-cloud.com)

## Overview

This repository provides a complete guide for deploying [Outline](https://www.getoutline.com/) - a modern team knowledge base and wiki - on [Clever Cloud](https://clever-cloud.com), a European PaaS provider.

Outline is an open-source knowledge base that helps teams organize and share information with a beautiful, intuitive interface. By deploying on Clever Cloud, you get a reliable, scalable hosting solution with minimal maintenance overhead.

## Prerequisites

- A [Clever Cloud](https://www.clever-cloud.com/) account
- [Clever Tools CLI](https://github.com/CleverCloud/clever-tools) installed and configured
- Basic familiarity with command line operations
- A domain name (optional, but recommended for production use)
- Authentication provider setup (Slack, Google, etc.) - see [Authentication Setup](#authentication-setup)

## Architecture

This deployment consists of the following components:

- **Outline application**: Node.js application running the wiki application
- **PostgreSQL database**: Stores all wiki content, users, and metadata
- **Redis cache**: Handles sessions, caching, and background job queues
- **File storage**: Clever Cloud S3-compatible bucket for document attachments and images
- **OAuth provider**: External authentication service (Slack, Google, etc.)

## Deployment Guide

### Before You Begin

Before starting the deployment process, you'll need to define the following values:

- `<ORGANISATION>` with the name of your organisation where the Outline instance will be deployed
- `<APP_NAME>` with your chosen application name
- `<YOUR_DOMAIN_NAME>` with your domain name (if applicable)
- `<SECRET_KEY>` with your chosen secret key for Outline
- `<UTILS_SECRET>` with your chosen utils secret for Outline

You will also need to choose an **Authentication Method**: Outline requires an OAuth provider (Slack, Google, Microsoft, etc.)

### Authentication Setup

Outline requires an OAuth authentication provider. You'll need to set up one of the following:

#### Slack Authentication (Recommended for teams)
1. Go to [Slack API](https://api.slack.com/apps)
2. Create a new app for your workspace
3. Note down the `Client ID` and `Client Secret`
4. Set redirect URL to: `https://<YOUR_DOMAIN_NAME>/auth/slack.callback`

#### Google Authentication
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable Google+ API
4. Create OAuth 2.0 credentials
5. Set redirect URL to: `https://<YOUR_DOMAIN_NAME>/auth/google.callback`

### Important Notes

#### Versions

In the example we are setting-up the latest version of Outline, currently the v0.86.1. Outline's default branch, `main`, is considered in development and may be broken at any time, so always use a [release tag](https://github.com/outline/outline/releases) to deploy a stable version. 


### Using Clever Tools CLI

Follow these steps to deploy Outline on Clever Cloud using the command line:

```bash
# Step 0: Prepare the environment

export APP_NAME=<APP_NAME>
export ORGANISATION=<ORGANISATION>

# Optional: Define your domain
export CC_DOMAIN=<YOUR_DOMAIN_NAME>

# Get the latest release of Outline
wget https://github.com/outline/outline/archive/refs/tags/v1.5.0.tar.gz

# Extract the release in the current folder
tar -xvzf v1.5.0.tar.gz --strip-components=1

# Re-initialize the git repository
git init
git add .
git commit -m "Initial commit"

# Step 1: Create a Node application
clever create --type node $APP_NAME --org $ORGANISATION
clever scale --app $APP_NAME --flavor S

# Add your domain
if [ -n "$CC_DOMAIN" ]; then
clever domain add $CC_DOMAIN
fi

# Step 2: Create required add-ons
# - PostgreSQL database for data storage (minimum XXS plan recommended)
clever addon create postgresql-addon --plan xxs_sml $APP_NAME-pg --org $ORGANISATION
# - Redis for session storage and caching
clever addon create redis-addon --plan s_mono $APP_NAME-redis --org $ORGANISATION
# - S3 bucket for file uploads
clever addon create cellar-addon $APP_NAME-s3 --org $ORGANISATION 

# Step 3: Link add-ons to your application
clever service link-addon $APP_NAME-pg
clever service link-addon $APP_NAME-redis
clever service link-addon $APP_NAME-s3

# Step 4: Configure environment variables
eval "$(clever env -F shell --alias $APP_NAME)"
export APP_ID=`clever applications -j | jq -r ".[0].app_id"`
: "${CC_DOMAIN=`clever curl -s https://api.clever-cloud.com/v2/self/applications/$APP_ID | jq -r ".vhosts[0].fqdn"`}"

clever env set URL https://$CC_DOMAIN
echo "Domain $CC_DOMAIN"

# Common environment variables
clever env set NODE_ENV production
clever env set PORT 8080
clever env set CC_NODE_DEV_DEPENDENCIES install
clever env set CC_POST_BUILD_HOOK "NODE_ENV=production && yarn build"
clever env set WEB_CONCURRENCY 2
clever env set SECRET_KEY $( openssl rand -hex 32 )
clever env set UTILS_SECRET $( openssl rand -hex 32 )
clever env set DEFAULT_LANGUAGE en_US

# Database configuration
clever env set DATABASE_URL $POSTGRESQL_ADDON_URI

# Redis configuration (automatically set from Redis add-on)
clever env set REDIS_URL $REDIS_URL

# File storage configuration
export BUCKET_NAME=$(clever applications -j | jq -r '.[0].app_id' | tr '_' '-')-outline
clever env set FILE_STORAGE s3
clever env set AWS_S3_UPLOAD_BUCKET_URL https://${CELLAR_ADDON_HOST}
clever env set AWS_S3_UPLOAD_BUCKET_NAME $BUCKET_NAME
clever env set AWS_ACCESS_KEY_ID $CELLAR_ADDON_KEY_ID
clever env set AWS_SECRET_ACCESS_KEY $CELLAR_ADDON_KEY_SECRET
clever env set AWS_S3_FORCE_PATH_STYLE true
clever env set AWS_S3_ACL private
clever env set AWS_REGION us-east-1

# S3 initialisation
./configure-cellar.sh

# Authentication configuration (choose one)
# For Slack authentication:
clever env set SLACK_CLIENT_ID '<YOUR_SLACK_CLIENT_ID>'
clever env set SLACK_CLIENT_SECRET '<YOUR_SLACK_CLIENT_SECRET>'

# For Google authentication:
# clever env set GOOGLE_CLIENT_ID '<YOUR_GOOGLE_CLIENT_ID>'
# clever env set GOOGLE_CLIENT_SECRET '<YOUR_GOOGLE_CLIENT_SECRET>'

# Optional: Email configuration for notifications
# clever env set SMTP_HOST '<YOUR_SMTP_HOST>'
# clever env set SMTP_PORT '<YOUR_SMTP_PORT>'
# clever env set SMTP_USERNAME '<YOUR_SMTP_USERNAME>'
# clever env set SMTP_PASSWORD '<YOUR_SMTP_PASSWORD>'
# clever env set SMTP_FROM_EMAIL '<YOUR_FROM_EMAIL>'
# clever env set SMTP_REPLY_EMAIL '<YOUR_REPLY_EMAIL>'
```

## Deployment

After configuring all the environment variables, deploy your application:

```bash
# Push your code to Clever Cloud
clever deploy
```

## Post-Deployment

1. Once deployed, access your Outline instance at `https://<YOUR_DOMAIN_NAME>/`
2. Sign in using your configured OAuth provider (Slack, Google, etc.)
3. The first user to sign in will automatically become the admin
4. Start creating your team's knowledge base!

## Contributing

Contributions to improve this deployment example are welcome! Please feel free to submit pull requests or open issues for any enhancements or bug fixes.

## License

This example is provided under the terms of the MIT license.
