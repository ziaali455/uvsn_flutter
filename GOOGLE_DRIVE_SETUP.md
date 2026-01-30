# Google Drive Integration Setup

This guide explains how to configure Google Drive integration for the "Add to Dataset" feature.

## Overview

The app can upload JSON analysis files directly to a Google Drive folder called **"UVSN Json Dataset"**. This folder is automatically created when you first upload a file.

## Setup Instructions

### 1. Create a Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Note your project name/ID

### 2. Enable Google Drive API

1. In your project, go to **APIs & Services > Library**
2. Search for "Google Drive API"
3. Click **Enable**

### 3. Configure OAuth Consent Screen

1. Go to **APIs & Services > OAuth consent screen**
2. Choose **External** user type (unless you have a Google Workspace organization)
3. Fill in the required fields:
   - App name: `UVSN Image Analyzer`
   - User support email: your email
   - Developer contact: your email
4. Add scopes:
   - `https://www.googleapis.com/auth/drive.file`
5. Add test users (your Google account email) while in testing mode
6. Save and continue

### 4. Create OAuth Credentials

#### For iOS:

1. Go to **APIs & Services > Credentials**
2. Click **Create Credentials > OAuth client ID**
3. Choose **iOS** application type
4. Enter your iOS Bundle ID (found in `ios/Runner.xcodeproj/project.pbxproj` or Xcode)
   - Default: `com.example.uvsnImageAnalyzer`
5. Click **Create**
6. Copy the **Client ID** (e.g., `123456789-abcdefg.apps.googleusercontent.com`)

#### For Android:

1. Go to **APIs & Services > Credentials**
2. Click **Create Credentials > OAuth client ID**
3. Choose **Android** application type
4. Enter your package name (from `android/app/build.gradle`)
5. Get your SHA-1 fingerprint:
   ```bash
   cd android
   ./gradlew signingReport
   ```
6. Click **Create**

#### For Web:

1. Go to **APIs & Services > Credentials**
2. Click **Create Credentials > OAuth client ID**
3. Choose **Web application**
4. Add authorized JavaScript origins (e.g., `http://localhost:5000`)
5. Click **Create**

### 5. Configure Your App

#### iOS Configuration

Edit `ios/Runner/Info.plist` and replace the placeholder values:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <!-- Replace with your REVERSED client ID -->
            <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
        </array>
    </dict>
</array>
<key>GIDClientID</key>
<!-- Replace with your iOS client ID -->
<string>YOUR_CLIENT_ID.apps.googleusercontent.com</string>
```

**Important**: The `CFBundleURLSchemes` needs the **reversed** client ID. 
- If your client ID is `123456789-abcdefg.apps.googleusercontent.com`
- The reversed client ID is `com.googleusercontent.apps.123456789-abcdefg`

#### Android Configuration (if needed)

The `google_sign_in` plugin handles most Android configuration automatically, but you may need to add your SHA-1 fingerprint to the Google Cloud Console.

#### Web Configuration

For web, add your client ID to `web/index.html`:

```html
<meta name="google-signin-client_id" content="YOUR_CLIENT_ID.apps.googleusercontent.com">
```

### 6. Test the Integration

1. Run your app
2. Analyze an image
3. Click the **"Add to Dataset"** button on any analysis card
4. Sign in with your Google account when prompted
5. The JSON file will be uploaded to "UVSN Json Dataset" folder in your Google Drive

## Troubleshooting

### "Sign-In Cancelled" or Authentication Errors

- Make sure your Google account is added as a test user in the OAuth consent screen
- Verify the Client ID is correctly configured in Info.plist
- Check that the Bundle ID matches what's registered in Google Cloud Console

### "API Not Enabled" Errors

- Make sure Google Drive API is enabled in your Google Cloud project

### Permission Errors

- The app requests `drive.file` scope, which only allows access to files created by the app
- This is the most restrictive scope and is recommended for security

## Notes

- The "UVSN Json Dataset" folder is created automatically in your Google Drive
- Each JSON file is named with the original image name plus a timestamp
- You can use "Add All to Dataset" from the menu to upload all analyses at once
