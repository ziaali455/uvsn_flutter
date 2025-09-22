#!/bin/bash

echo "🚀 Building Flutter web app..."
flutter build web --release --base-href /

echo "📦 Deploying to Vercel..."
npx vercel --prod --yes --cwd build/web

echo "✅ Deployment complete!"
