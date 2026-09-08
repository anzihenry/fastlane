# HarmonyOS support design

## Scope

The first implementation targets HarmonyOS NEXT / API 12+ projects built with
DevEco Studio's Hvigor wrapper (`hvigorw`). It deliberately does not attempt to
support legacy HarmonyOS projects that use the Android-compatible Gradle tool
chain. Those projects can continue to use the Android actions.

The supported platform name is `harmonyos`, so lanes use:

```ruby
platform :harmonyos do
  lane :beta do
    build_harmonyos_app
  end
end
```

## Action model

HarmonyOS actions follow the Android action layout, but never treat an HAP or
APP as an APK/AAB:

| Android action | HarmonyOS action | Responsibility |
| --- | --- | --- |
| `gradle` | `hvigor` | Run the native build tool and discover artifacts. |
| `build_android_app` | `build_harmonyos_app` | Friendly build alias. |
| `adb` / `adb_devices` | `hdc` / `hdc_devices` | Run commands and enumerate devices. |
| `capture_android_screenshots` | `capture_harmonyos_screenshots` | Run a caller-supplied screenshot workflow. |
| `upload_to_play_store` | `upload_to_appgallery` | Upload an artifact and optionally submit it for release. |

`hvigor` exposes the following lane-context values:

- `HARMONYOS_HAP_OUTPUT_PATH` and `HARMONYOS_ALL_HAP_OUTPUT_PATHS`
- `HARMONYOS_APP_OUTPUT_PATH` and `HARMONYOS_ALL_APP_OUTPUT_PATHS`
- `HARMONYOS_HAR_OUTPUT_PATH` and `HARMONYOS_ALL_HAR_OUTPUT_PATHS`
- `HARMONYOS_PRODUCT` and `HARMONYOS_BUILD_MODE`

Actions should accept explicit artifact paths first, and only use these values
as a convenience fallback. This makes custom Hvigor layouts and CI artifact
collection deterministic.

## Build contract

`hvigor` invokes a project-local `hvigorw` by default. It accepts `task`,
`tasks`, `product`, `build_mode`, `project_dir`, `hvigor_path`, `properties`,
and `flags`. `product` and `build_mode` are passed as Hvigor project
properties. `build_harmonyos_app` defaults to `assembleApp` unless a task is
specified.

Artifact discovery is configurable with `artifact_glob`. The default only
searches inside `build/` directories and classifies `.hap`, `.app`, and `.har`
files. The action must fail with a useful error when the requested build task
finishes successfully but no application artifact is found.

## AppGallery Connect contract

AppGallery Connect publication contains multiple state-changing operations:
obtaining an upload URL, uploading a package, updating version/file
information, and submitting a release. `upload_to_appgallery` receives the
pre-signed upload URL and defaults to uploading only. A caller must explicitly
set `submit_for_review: true` to submit a release that has already had its
file information configured.

The actions use a small HTTP client with an injectable endpoint. Credentials
are read from parameters or environment variables and are never logged. API
endpoint versions, package formats, and asynchronous processing states vary by
AppGallery Connect product and region, so retrieval of pre-signed URLs and
updates to file information remain explicit CI responsibilities in this first
release.

The default API root is `https://connect-api.cloud.huawei.com/api`. A Service
Account is the recommended authentication mode. Download its JSON credential
file from `Users and permissions > API key > Connect API > Service Account`,
store it outside the repository, and configure:

```sh
export FL_APPGALLERY_SERVICE_ACCOUNT_KEY_PATH='/secure/path/service-account.json'
export FL_APPGALLERY_APP_ID='...'
```

The credential file contains `key_id`, `private_key`, `sub_account`, and
`token_uri`. The client generates a one-hour PS256 JWT locally and sends it as
the bearer token. The private key is never sent separately and the Service
Account flow does not send a client ID header.

The legacy API Client mode remains supported with these variables:

```sh
export FL_APPGALLERY_CLIENT_ID='...'
export FL_APPGALLERY_CLIENT_SECRET='...'
export FL_APPGALLERY_APP_ID='...'
```

In API Client mode, the client exchanges the ID and secret at
`/oauth2/v1/token`, caches the returned token for the current action, and sends
both the bearer token and client ID on publishing API requests. As an
alternative, provide a short-lived token with
`FL_APPGALLERY_ACCESS_TOKEN`. For a regional AppGallery endpoint, set
`FL_APPGALLERY_API_BASE`; API Client token and publishing requests must use the
same region.

A minimal read-only connectivity check is:

```ruby
get_appgallery_app_info(
  app_id: ENV['FL_APPGALLERY_APP_ID']
)
```

Run this check before enabling package upload or release submission. A
successful response confirms credentials, role permissions, region, and app
visibility without changing the application.

The upload and release steps are deliberately separate:

```ruby
upload_to_appgallery(
  app_id: ENV['APPGALLERY_APP_ID'],
  file_info: { 'fileType' => 5, 'files' => [{ 'fileName' => 'entry.hap' }] }
)
submit_to_appgallery(app_id: ENV['APPGALLERY_APP_ID'])
```

When `upload_url` is omitted, `upload_to_appgallery` obtains a temporary URL
from AppGallery Connect. It can then upload the HAP/APP found in lane context
and update the caller-supplied `file_info`. Keep `submit_for_review` disabled;
`submit_to_appgallery` is the preferred explicit release step.

## Release management

Use `get_appgallery_versions` to retrieve commercial and test versions. The
action supports optional package-name and state filters and stores the full
response in `APPGALLERY_VERSIONS`. Each result contains the version ID and,
when a package is attached, package IDs needed by the processing-status API.

After updating package information, wait for asynchronous package parsing
before submitting:

```ruby
wait_for_appgallery_package_processing(
  app_id: ENV['FL_APPGALLERY_APP_ID'],
  package_ids: [package_id],
  interval: 10,
  timeout: 300
)
```

Status `0` means ready, `1` means processing, and `2` means failed. The action
returns only when every package is ready and fails immediately for failed or
unknown statuses.

`submit_to_appgallery` uses the HarmonyOS v3 Publishing API. It supports an
optional `release_time` and `remark`. For a seven-day phased release, use:

```ruby
submit_to_appgallery(
  app_id: ENV['FL_APPGALLERY_APP_ID'],
  release_phase: 3,
  phased_release_description: 'Monitor stability during gradual rollout'
)
```

After approval, `update_appgallery_phased_release` can pause with
`state: 'SUSPEND'`, resume with `state: 'RELEASE'`, accelerate with a
`phase_day` from 2 through 7, or switch to full release with
`release_phase: 4`. Query `get_appgallery_versions` first to obtain the exact
version ID.

`cancel_appgallery_review` withdraws an eligible version from review. This is
a state-changing operation and is never invoked implicitly by upload or query
actions.

## App and package management

Use `get_appgallery_app_ids` to map one or more HarmonyOS package names to
AppGallery Connect app IDs. It defaults to AppGallery package type `7`, the
HarmonyOS APP type. `get_appgallery_app_info` and
`update_appgallery_app_info` respectively retrieve and update only the
caller-supplied application fields. Neither action creates an application or
submits a release.

`download_from_appgallery` downloads a package from an explicit,
AppGallery-provided URL and exposes `APPGALLERY_DOWNLOADED_PACKAGE_PATH`. It
does not enumerate private download URLs or persist credentials.

Creating applications is intentionally not automated yet. The required
HarmonyOS creation API differs across AppGallery Connect product generations;
it should be added only after a real test application confirms the endpoint,
required fields, and role permissions.

## Screenshot contract

`capture_harmonyos_screenshots` accepts a project-specific HDC capture command
and runs it for one or more device serials. The command can contain
`{{serial}}` and `{{output_directory}}` placeholders. It exposes both
`HARMONYOS_SCREENSHOTS_PATH` and `HARMONYOS_SCREENSHOT_PATHS`, so later lanes
can frame, archive, or upload the resulting images.

## Non-goals for the first release

- Generating or managing HarmonyOS signing certificates and profiles.
- Creating AppGallery applications or uploading localized store assets.
- Automatically installing DevEco Studio, SDKs, or HDC.
- Guessing a device screenshot test framework.

These remain planned extensions after the build, publication, and device
contracts are stable.
