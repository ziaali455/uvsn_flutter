#!/bin/bash
set -e
curl -fsSL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.27.1-stable.tar.xz | tar -xJ
export PATH="$PWD/flutter/bin:$PATH"
flutter --version
flutter pub get
flutter build web --release --base-href /
