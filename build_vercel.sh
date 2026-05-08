#!/bin/bash

# Exit on error
set -e

echo "--- Installing Flutter ---"
# Check if flutter directory exists, if not clone it
if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi

# Add flutter to path
export PATH="$PATH:`pwd`/flutter/bin"

echo "--- Creating .env file ---"
touch .env
echo "SUPABASE_URL=$SUPABASE_URL" > .env
echo "SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY" >> .env
echo "MAILERSEND_API_KEY=$MAILERSEND_API_KEY" >> .env
echo "WESENDER_API_KEY=$WESENDER_API_KEY" >> .env

echo "--- Flutter Version ---"
flutter --version

echo "--- Pre-downloading development binaries ---"
flutter precache --web

echo "--- Building Web App ---"
flutter build web --release

echo "--- Build Complete ---"
