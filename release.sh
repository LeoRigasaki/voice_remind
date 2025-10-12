#!/bin/bash

# VoiceRemind Release Script - Improved Version for macOS
VERSION="v1.1.8"

echo "🚀 Building VoiceRemind $VERSION..."

# Clean and prepare
echo "📦 Cleaning and getting dependencies..."
flutter clean && flutter pub get

# Build split APKs for different architectures
echo "🏗️ Building split APKs..."
flutter build apk --release --split-per-abi

# Create release directory
mkdir -p releases/$VERSION

# Copy and rename APKs with clear names
echo "📋 Copying APKs with clear names..."
cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk ./releases/$VERSION/VoiceRemind-$VERSION-arm64-v8a.apk
cp build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk ./releases/$VERSION/VoiceRemind-$VERSION-armeabi-v7a.apk  
cp build/app/outputs/flutter-apk/app-x86_64-release.apk ./releases/$VERSION/VoiceRemind-$VERSION-x86_64.apk

# Optional: Create a universal APK too (for easy testing)
echo "🔄 Building universal APK..."
flutter build apk --release
cp build/app/outputs/flutter-apk/app-release.apk ./releases/$VERSION/VoiceRemind-$VERSION-universal.apk

# Show file sizes
echo "📊 APK Sizes:"
ls -lh releases/$VERSION/

echo "✅ Build complete! Files ready in releases/$VERSION/"
echo ""
echo "📱 Architecture Guide:"
echo "  • arm64-v8a: Most modern Android phones (recommended for most users)"
echo "  • armeabi-v7a: Older Android devices" 
echo "  • x86_64: Android emulators"
echo "  • universal: Works on all devices (larger size)"
echo ""
echo "🔗 Upload to GitHub: https://github.com/LeoRigasaki/voice_remind/releases"