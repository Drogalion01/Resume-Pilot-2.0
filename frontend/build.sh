#!/bin/bash

echo "Downloading Flutter stable channel..."
git clone https://github.com/flutter/flutter.git -b stable --depth 1
export PATH="$PATH:`pwd`/flutter/bin"

echo "Running flutter pub get..."
flutter pub get

echo "Building Flutter Web release..."
flutter build web --release
