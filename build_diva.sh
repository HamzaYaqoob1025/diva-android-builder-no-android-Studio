#!/bin/bash
# sed -i 's/\r//' build_diva.sh && bash build_diva.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ANDROID_HOME="$HOME/android-sdk"
SDK_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-9477386_latest.zip"

echo "=============================="
echo "   DIVA Android Build Script  "
echo "=============================="

# ── 1. JAVA 11 ─────────────────────────────────────────────────
echo ""
echo "[1/7] Checking Java 11..."
if [ -d "/usr/lib/jvm/java-11-openjdk-amd64" ]; then
    echo "  Java 11 already installed."
else
    echo "  Installing Java 11..."
    sudo apt update -y
    sudo apt install openjdk-11-jdk -y
fi

export JAVA_HOME="/usr/lib/jvm/java-11-openjdk-amd64"
export PATH="$JAVA_HOME/bin:$PATH"
echo "  Using Java: $(java -version 2>&1 | head -1)"

# ── 2. REQUIRED PACKAGES ───────────────────────────────────────
echo ""
echo "[2/7] Checking required packages..."
PKGS=""
command -v wget  &>/dev/null || PKGS="$PKGS wget"
command -v unzip &>/dev/null || PKGS="$PKGS unzip"
command -v git   &>/dev/null || PKGS="$PKGS git"
command -v make  &>/dev/null || PKGS="$PKGS make"

if [ -n "$PKGS" ]; then
    echo "  Installing:$PKGS"
    sudo apt update -y
    sudo apt install -y $PKGS
else
    echo "  All packages present."
fi

# ── 3. ANDROID SDK ─────────────────────────────────────────────
echo ""
echo "[3/7] Checking Android SDK..."
if [ -f "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ]; then
    echo "  SDK already installed."
else
    echo "  Installing Android cmdline-tools..."
    mkdir -p "$ANDROID_HOME/cmdline-tools"
    cd /tmp
    wget -q --show-progress "$SDK_TOOLS_URL" -O cmdline-tools.zip
    unzip -q cmdline-tools.zip
    rm -rf "$ANDROID_HOME/cmdline-tools/latest"
    mv cmdline-tools "$ANDROID_HOME/cmdline-tools/latest"
    rm -f cmdline-tools.zip
fi

export ANDROID_HOME="$ANDROID_HOME"
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools"

grep -qxF "export ANDROID_HOME=$HOME/android-sdk" ~/.bashrc || \
    echo "export ANDROID_HOME=$HOME/android-sdk" >> ~/.bashrc
grep -qF "cmdline-tools/latest/bin" ~/.bashrc || \
    echo 'export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools' >> ~/.bashrc

# ── 4. SDK COMPONENTS ──────────────────────────────────────────
echo ""
echo "[4/7] Checking SDK components..."
SDKMGR="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
yes | "$SDKMGR" --sdk_root="$ANDROID_HOME" --licenses &>/dev/null || true

INSTALLED=$("$SDKMGR" --sdk_root="$ANDROID_HOME" --list_installed 2>/dev/null)

install_if_missing() {
    local pkg="$1"
    local label="$2"
    if echo "$INSTALLED" | grep -q "$label"; then
        echo "  Already installed: $pkg"
    else
        echo "  Installing: $pkg"
        yes | "$SDKMGR" --sdk_root="$ANDROID_HOME" "$pkg"
    fi
}

install_if_missing "platforms;android-23"  "android-23"
install_if_missing "build-tools;23.0.2"    "23.0.2"
install_if_missing "platform-tools"        "platform-tools"
install_if_missing "ndk;21.4.7075529"      "21.4"

export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/21.4.7075529"

# ── 5. CLONE DIVA ──────────────────────────────────────────────
echo ""
echo "[5/7] Cloning DIVA..."
cd "$SCRIPT_DIR"

if [ -d "diva-android" ]; then
    echo "  Already cloned, pulling latest..."
    cd diva-android
    git pull
else
    git clone https://github.com/payatu/diva-android
    cd diva-android
fi

# ── 6. PATCH GRADLE + REPOS + JNI ──────────────────────────────
echo ""
echo "[6/7] Patching Gradle, repositories and AGP..."

# Fix gradle wrapper to 6.7.1
cat > gradle/wrapper/gradle-wrapper.properties << 'EOF'
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-6.7.1-all.zip
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
EOF
echo "  Gradle wrapper -> 6.7.1"

# Fix build.gradle, replace jcenter with google + mavenCentral, AGP 3.6.4
cat > build.gradle << 'EOF'
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath 'com.android.tools.build:gradle:3.6.4'
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

task clean(type: Delete) {
    delete rootProject.buildDir
}
EOF
echo "  AGP -> 3.6.4, repos -> google() + mavenCentral()"

# Compile native JNI
echo "  Compiling native JNI library..."
cd app/src/main/jni

NDK_BUILD="$ANDROID_NDK_HOME/ndk-build"
if [ -f "$NDK_BUILD" ]; then
    "$NDK_BUILD" NDK_PROJECT_PATH=. APP_BUILD_SCRIPT=./Android.mk
    echo "  Native library compiled."
else
    echo "  ndk-build not found, skipping."
fi

cd "$SCRIPT_DIR/diva-android"

# ── 7. BUILD APK ───────────────────────────────────────────────
echo ""
echo "[7/7] Building APK..."
chmod +x gradlew
./gradlew clean assembleDebug

APK_SRC="app/build/outputs/apk/debug/app-debug.apk"

if [ -f "$APK_SRC" ]; then
    cp "$APK_SRC" "$SCRIPT_DIR/DivaApp.apk"
    echo ""
    echo "=============================="
    echo " BUILD SUCCESSFUL"
    echo " APK: $SCRIPT_DIR/DivaApp.apk"
    echo "=============================="

    if command -v adb &>/dev/null; then
        echo ""
        echo "Installing to MEmu..."
        adb connect 127.0.0.1:21503 2>/dev/null || true
        sleep 2
        if adb devices | grep -q "device$"; then
            adb install -r "$SCRIPT_DIR/DivaApp.apk" && \
                echo "Installed on MEmu successfully." || \
                echo "ADB install failed. Run manually: adb install $SCRIPT_DIR/DivaApp.apk"
        else
            echo "No ADB device found. Run manually:"
            echo "  adb connect 127.0.0.1:21503"
            echo "  adb install $SCRIPT_DIR/DivaApp.apk"
        fi
    fi
else
    echo "BUILD FAILED. APK not found."
    exit 1
fi