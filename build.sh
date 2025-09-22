#!/bin/bash
set -e

echo "🔧 Installing Flutter..."

# Download and extract Flutter
curl -fsSL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.5-stable.tar.xz | tar -xJ

# Add Flutter to PATH
export PATH="$PWD/flutter/bin:$PATH"

echo "✅ Flutter installed. Version:"
flutter --version

echo "📦 Getting dependencies..."
flutter pub get

echo "🚀 Building web app..."
flutter build web --release --base-href /

echo "✅ Build complete!"
