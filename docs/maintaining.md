# Maintaining Knit

The jobs, in the order you meet them.

## Fresh checkout

```sh
git clone git@github.com:lumpsoid/knit_mobile.git && cd knit_mobile
flutter pub get          # Flutter at the version in .fvmrc
scripts/check.sh
```

For a signed release build on this machine, also put back
`android/key.properties` (see [Signing key](#signing-key)).

## Everyday

- `scripts/check.sh` before every push. It runs CI's gates in CI's order:
  version check, `dart format`, `flutter analyze lib test packages`, and
  every test (the app's and `packages/*`).
- `flutter run --flavor dev -t lib/main_dev.dart` for in-memory experiments,
  `--flavor prod -t lib/main_prod.dart` for the real database.
- Every user-visible change adds a line under `## [Unreleased]` in
  `CHANGELOG.md`.

## Version

The version lives in one place, `pubspec.yaml` (`version: X.Y.Z+N`). `N` is
the Android `versionCode`, and it must grow with every release, or phones
refuse the update.

```sh
scripts/version.sh show            # 0.1.0+8
scripts/version.sh check           # well-formed, CHANGELOG has a section
scripts/version.sh bump 0.2.0      # 0.2.0+9, dates [Unreleased] as [0.2.0]
```

The app shows `0.1.0 (2391c1d)` in Settings → About. The hash comes from
`--dart-define=GIT_COMMIT=…`, which `scripts/release_apk.sh` passes; a plain
`flutter run` shows the bare version.

## Release

1. On `master`, with a clean tree:
   `scripts/version.sh bump X.Y.Z`, review the CHANGELOG section, then
   `git commit -am 'chore(release): X.Y.Z'`.
2. `scripts/release.sh` runs every gate, then makes the annotated tag `vX.Y.Z`
   with the CHANGELOG section as its message. It never pushes.
3. `git push origin master vX.Y.Z`.
4. The **Release** workflow checks the tag against `pubspec.yaml`, builds the
   signed APK, refuses a debug signature, and publishes
   `knit-X.Y.Z.apk` + `.sha256` with the tag notes.

To build an APK locally: `scripts/release_apk.sh` (prod) or
`scripts/release_apk.sh dev`. It lands in `dist/` with its checksum.

## Signing key

One key signs every release. **Lose it and no installed copy can update
again**, so keep the keystore and both passwords in a password manager.

Create it once, outside the repo:

```sh
keytool -genkeypair -v -keystore ~/keys/knit-release.jks -alias knit \
  -keyalg RSA -keysize 4096 -validity 36500
chmod 600 ~/keys/knit-release.jks
```

`android/key.properties` (gitignored) points the build at it:

```properties
storeFile=/home/you/keys/knit-release.jks
storePassword=…
keyAlias=knit
keyPassword=…
```

Without the file, release builds fall back to the debug key. Check a build with
`$ANDROID_HOME/build-tools/<version>/apksigner verify --print-certs <apk>`:
the DN must be yours, not `CN=Android Debug`.

CI signs from four repository secrets:

```sh
base64 -w0 ~/keys/knit-release.jks | gh secret set ANDROID_KEYSTORE_BASE64 -R lumpsoid/knit_mobile
gh secret set ANDROID_KEYSTORE_PASSWORD -R lumpsoid/knit_mobile
gh secret set ANDROID_KEY_ALIAS -R lumpsoid/knit_mobile
gh secret set ANDROID_KEY_PASSWORD -R lumpsoid/knit_mobile
```

## Dependency updates

Dependabot opens weekly PRs for pub (the app and `packages/*`), Gradle
(`android/`) and GitHub Actions, with minor and patch updates grouped. Merge
when CI is green; read the changelog of anything major first.

Move together, by hand:

- **Flutter**: bump `.fvmrc`. CI and the release workflow read it. Then run
  `scripts/check.sh`; new SDKs often bring new analyzer lints.
- **Android build**: the Gradle wrapper
  (`android/gradle/wrapper/gradle-wrapper.properties`), the Android Gradle
  plugin and Kotlin in `android/settings.gradle.kts`, and `compileSdk` /
  `targetSdk` in `android/app/build.gradle.kts`.
- **Git dependencies** (`fcis_core`, `result_dart`, `external_signal`,
  `selector_flutter`, `fetch_dart` in `pubspec.yaml`): Dependabot doesn't
  follow them. Run `flutter pub upgrade <name>` to move `pubspec.lock` to
  their latest commit.

## One-time GitHub settings

- Description and topics (`flutter`, `local-first`, `notes`, `android`).
- Settings → Code security: turn on Dependabot alerts and security updates.
- Settings → Actions → General: workflow permissions "Read repository
  contents" (the release workflow asks for `contents: write` itself).
- Optional: protect `master` and require the **CI / check** job.
