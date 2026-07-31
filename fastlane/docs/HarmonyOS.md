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
`submit_to_appgallery` is the preferred explicit release step. Use
`get_appgallery_version` to retrieve package information into
`APPGALLERY_FILE_INFO` before submitting.

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
