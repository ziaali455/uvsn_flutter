#!/bin/bash

echo "🚀 Building Flutter web app..."
flutter build web --release --base-href /

echo "📋 Copying Vercel configuration..."
cp vercel.json build/web/vercel.json

echo "📦 Deploying to Vercel..."
npx vercel --prod --yes --cwd build/web

echo "✅ Deployment complete!"
