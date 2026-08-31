<div align="center">

# diva-android-builder

**One script. No Android Studio. Fresh APK in minutes.**

[![Platform](https://img.shields.io/badge/platform-Kali%20%7C%20Ubuntu%20%7C%20WSL-blue?style=flat-square)](https://github.com/HamzaYaqoob1025/diva-android-builder-no-android-Studio)
[![Java](https://img.shields.io/badge/Java-11-orange?style=flat-square)](https://openjdk.org/projects/jdk/11/)
[![Gradle](https://img.shields.io/badge/Gradle-6.7.1-02303A?style=flat-square&logo=gradle)](https://gradle.org/)
[![AGP](https://img.shields.io/badge/AGP-3.6.4-3DDC84?style=flat-square&logo=android)](https://developer.android.com/studio/releases/gradle-plugin)
[![NDK](https://img.shields.io/badge/NDK-21.4-green?style=flat-square)](https://developer.android.com/ndk)
[![License](https://img.shields.io/badge/license-MIT-purple?style=flat-square)](LICENSE)

Builds [DIVA Android](https://github.com/payatu/diva-android) from source — fully automated, idempotent, works on a fresh Kali / Ubuntu / WSL box.

</div>

---

## The Problem

DIVA (Damn Insecure and Vulnerable App) was written in **2015**. Building it in 2025+ fails immediately because:

| Issue | Root Cause |
|-------|-----------|
| Build crash | Gradle 2.4 cannot parse Java version strings like `25.0.3` |
| All dependencies fail | **jcenter shut down in 2022** — nothing downloads |
| Toolchain mismatch | AGP 1.x is incompatible with any modern Android SDK |

This script silently fixes all three and hands you a working `DivaApp.apk`.

---

## Architecture & Build Pipeline

```
+-----------------------------------------------------------------+
|                    diva-android-builder                         |
|                 build_diva.sh  (single script)                  |
+-------------------------------+---------------------------------+
                                |
               +----------------v----------------+
               |  [1/7]  Java 11 Check           |
               |  /usr/lib/jvm/java-11-openjdk   |
               |  -> sets JAVA_HOME + PATH       |
               |  -> does NOT touch system Java  |
               +----------------+----------------+
                                |
               +----------------v----------------+
               |  [2/7]  System Packages         |
               |  wget  unzip  git  make         |
               |  -> installs only what missing  |
               +----------------+----------------+
                                |
               +----------------v----------------+
               |  [3/7]  Android SDK             |
               |  cmdline-tools 9477386          |
               |  -> downloads to ~/android-sdk  |
               |  -> persists PATH in ~/.bashrc  |
               +----------------+----------------+
                                |
               +----------------v----------------+
               |  [4/7]  SDK Components          |
               |  platforms;android-23           |
               |  build-tools;23.0.2             |
               |  platform-tools                 |
               |  ndk;21.4.7075529               |
               |  -> skips if already installed  |
               +----------------+----------------+
                                |
               +----------------v----------------+
               |  [5/7]  DIVA Source             |
               |  git clone payatu/diva-android  |
               |  -> OR git pull if exists       |
               +----------------+----------------+
                                |
               +----------------v----------------+
               |  [6/7]  Patch + JNI Compile     |
               |                                 |
               |  gradle-wrapper.properties      |
               |    2.4  ---------->  6.7.1      |
               |                                 |
               |  build.gradle                   |
               |    jcenter()  ----> google()    |
               |                  + mavenCentral |
               |    AGP 1.x  ------> 3.6.4       |
               |                                 |
               |  ndk-build  (JNI native .so)    |
               +----------------+----------------+
                                |
               +----------------v----------------+
               |  [7/7]  Build + Deploy          |
               |  ./gradlew clean assembleDebug  |
               |  -> copies DivaApp.apk          |
               |  -> adb connect 127.0.0.1:21503 |
               |  -> adb install  (MEmu/WSL)     |
               +---------------------------------+
```

---

## Quick Start

```bash
# 1. Clone this repo
git clone https://github.com/HamzaYaqoob1025/diva-android-builder-no-android-Studio
cd diva-android-builder

# 2. Fix Windows line endings if you edited on Windows
sed -i 's/\r//' build_diva.sh

# 3. Run it
bash build_diva.sh
```

> That is it. No Android Studio. No manual SDK downloads. No version juggling.

---

## What Gets Patched & Why

### gradle/wrapper/gradle-wrapper.properties

```diff
- distributionUrl=https\://services.gradle.org/distributions/gradle-2.4-all.zip
+ distributionUrl=https\://services.gradle.org/distributions/gradle-6.7.1-all.zip
```

**Why:** Gradle 2.4 crashes on Java 17+ with `NumberFormatException` when parsing the JVM version string.

---

### build.gradle

```diff
  buildscript {
      repositories {
-         jcenter()
+         google()
+         mavenCentral()
      }
      dependencies {
-         classpath 'com.android.tools.build:gradle:1.2.3'
+         classpath 'com.android.tools.build:gradle:3.6.4'
      }
  }

  allprojects {
      repositories {
-         jcenter()
+         google()
+         mavenCentral()
      }
  }
```

**Why:** jcenter shut down in February 2022. Every dependency resolution fails with a 404. AGP 1.x is also binary-incompatible with Gradle 6+.

---

## Output

| File | Location |
|------|----------|
| `DivaApp.apk` | Same folder as `build_diva.sh` |
| Build logs | Printed to stdout |
| Android SDK | `~/android-sdk/` |
| DIVA source | `./diva-android/` |

---

## Auto-Install to MEmu (WSL / Windows)

If `adb` is on your PATH and a device is connected, the script will automatically:

```
adb connect 127.0.0.1:21503   <- MEmu default ADB port
adb install -r DivaApp.apk
```

If no device is found, it prints the manual commands instead — the build still succeeds.

---

## Requirements

| Requirement | Detail |
|-------------|--------|
| OS | Kali Linux, Ubuntu, Debian, WSL2 |
| Privileges | `sudo` access for `apt install` |
| Disk space | ~1 GB (SDK + NDK + build cache) |
| Network | Internet connection (first run only) |
| Idempotent | Safe to re-run; skips already-done steps |

---

## Repository Structure

```
diva-android-builder/
+-- build_diva.sh       <- the only file you need
+-- README.md
+-- LICENSE
+-- assets/
    +-- banner.png
```

---

## About DIVA

**DIVA (Damn Insecure and Vulnerable App)** is a deliberately insecure Android application designed for:

- Learning Android security testing
- Practicing reverse engineering
- OWASP Mobile Top 10 training
- Security awareness and CTF prep

Original project: [payatu/diva-android](https://github.com/payatu/diva-android)

---

## License

MIT — do whatever you want, just do not blame us when you find vulnerabilities in DIVA. That is the point.

---

<div align="center">
Made for security researchers who just want a working APK, not a build environment battle.
</div>


