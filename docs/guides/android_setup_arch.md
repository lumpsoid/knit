# Android SDK on Arch Linux (terminal only)

How to install the Android toolchain Knit needs without Android Studio, and
how to keep it up to date. The project's requirements are in
`android/app/build.gradle.kts` and `android/settings.gradle.kts`:

| What | Version |
| --- | --- |
| JDK | 17 (`jvmTarget` / `sourceCompatibility`) |
| compileSdk / targetSdk | 37 |
| minSdk | `max(flutter.minSdkVersion, 23)` |
| NDK | `flutter.ndkVersion` (Gradle installs it on the first build) |
| Android Gradle Plugin | 8.11.1 |
| Gradle | 9.4.1 (wrapper, downloaded on the first build) |

> Google ships the Android SDK for **x86_64 Linux only**. On an ARM machine
> (for example a Raspberry Pi) these tools won't run.

## 1. Install

### JDK and helper tools

```bash
sudo pacman -Syu --needed jdk17-openjdk unzip wget git
sudo archlinux-java set java-17-openjdk
```

### Command-line tools

Check https://developer.android.com/studio#command-line-tools-only for the
current zip name. The number below may be out of date.

```bash
mkdir -p ~/Android/Sdk/cmdline-tools
cd ~/Android/Sdk/cmdline-tools
wget https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip
unzip commandlinetools-linux-*_latest.zip
mv cmdline-tools latest
rm commandlinetools-linux-*_latest.zip
```

The layout must end up as `~/Android/Sdk/cmdline-tools/latest/bin/sdkmanager`.

### Environment

Add this to `~/.bashrc` (or `~/.zshrc`), then open a new terminal:

```bash
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk
export ANDROID_HOME=$HOME/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator
```

### SDK packages

`sdkmanager` aborts the **whole** install when one package name is wrong, so
install `platform-tools` (which provides `adb`) on its own first:

```bash
sdkmanager --install "platform-tools"
ls ~/Android/Sdk/platform-tools/adb
```

Look up the exact names of the platform and build-tools. Recent platforms
carry a minor version (for example `platforms;android-37.0`, not
`platforms;android-37`):

```bash
sdkmanager --list | grep -E "platforms;android-3[6-9]|build-tools;3[6-9]"
```

Install the names the list shows:

```bash
sdkmanager --install "platforms;android-37.0" "build-tools;37.0.0"
```

If no API 37 platform is listed, it may only be on the preview channel:

```bash
sdkmanager --channel=3 --list | grep "platforms;android-37"
sdkmanager --channel=3 --install "platforms;android-37.0"
```

### Licenses and Flutter

```bash
yes | sdkmanager --licenses
flutter config --android-sdk ~/Android/Sdk
flutter doctor --android-licenses
flutter doctor -v
```

The first `flutter build apk` downloads Gradle and the NDK, so it takes a while.

## 2. Optional: emulator or a USB device

Emulator (needs x86_64 with KVM):

```bash
sudo pacman -S --needed qemu-base
sudo gpasswd -a $USER kvm        # log out and back in afterwards
sdkmanager --install "emulator" "system-images;android-37.0;google_apis;x86_64"
avdmanager create avd -n pixel -k "system-images;android-37.0;google_apis;x86_64" -d pixel_7
emulator -avd pixel
```

A real phone over USB (turn on USB debugging on the phone):

```bash
sudo pacman -S --needed android-udev
sudo gpasswd -a $USER adbusers   # log out and back in afterwards
adb devices                      # accept the prompt on the phone
```

## 3. Update afterwards

### Installed SDK packages

Updates everything already installed, including `cmdline-tools;latest`,
`platform-tools`, the emulator and system images:

```bash
sdkmanager --list_installed      # what's there now
sdkmanager --update
yes | sdkmanager --licenses      # new versions can bring new licenses
```

### A new platform or build-tools

`--update` never adds a new API level or a new build-tools line. When the
project raises `compileSdk` / `targetSdk`, install the matching packages:

```bash
sdkmanager --list | grep -E "platforms;android-|build-tools;"
sdkmanager --install "platforms;android-38.0" "build-tools;38.0.0"   # example names
```

Remove versions nothing uses any more:

```bash
sdkmanager --uninstall "platforms;android-36" "build-tools;36.0.0"   # example names
```

### Flutter, the JDK and Gradle

```bash
flutter upgrade                  # Flutter itself (may raise flutter.ndkVersion)
sudo pacman -Syu                 # keeps jdk17-openjdk patched
flutter clean && flutter pub get # after a Flutter or SDK change
flutter doctor -v
```

- Gradle and the Android Gradle Plugin are pinned by the project
  (`android/gradle/wrapper/gradle-wrapper.properties`,
  `android/settings.gradle.kts`). Raise them there, not on the machine.
- A new NDK is downloaded by Gradle on the next build; delete old ones from
  `~/Android/Sdk/ndk/` to free space.
- If a newer AGP or Gradle requires a newer JDK, install it (for example
  `jdk21-openjdk`), switch with `sudo archlinux-java set java-21-openjdk`, and
  update `JAVA_HOME`.

## 4. Troubleshooting

| Symptom | Fix |
| --- | --- |
| `flutter doctor`: "Android SDK file not found: adb" | `platform-tools` isn't installed. Run `sdkmanager --install "platform-tools"` on its own. |
| `Warning: Failed to find package '…'`, nothing installed | One wrong name aborts the install. Get the exact names from `sdkmanager --list` and retry. |
| `sdkmanager: No such file or directory` | The tools sit in the wrong folder. Run `mv ~/Android/Sdk/cmdline-tools/cmdline-tools ~/Android/Sdk/cmdline-tools/latest`. |
| `UnsupportedClassVersionError` or "JAVA_HOME is not set" | Run `archlinux-java status`, then `sudo archlinux-java set java-17-openjdk`, and check `JAVA_HOME`. Open a new terminal. |
| `sdkmanager` ignores `ANDROID_HOME` | Pass the root explicitly: `sdkmanager --sdk_root=$HOME/Android/Sdk …`. |
| "Emulator version unknown" | Only a warning: the emulator isn't installed. Safe to ignore when you use a phone. |
| `adb devices` shows `unauthorized` / `no permissions` | Accept the prompt on the phone; check you're in the `adbusers` group (`groups`). |
