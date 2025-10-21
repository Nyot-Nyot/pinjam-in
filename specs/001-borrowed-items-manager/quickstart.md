# Quickstart: Borrowed Items Manager

**Date**: 2025-10-21
**Feature**: Borrowed Items Manager

This guide provides the essential steps to get the application running for development.

## 1. Prerequisites

-   Flutter SDK (^3.8.1) installed.
-   A Supabase project created.
-   Android Studio or VS Code with the Flutter plugin.
-   An Android emulator or physical device.

## 2. Supabase Setup

1.  **Create a new Supabase project**.
2.  **Run the SQL schema**: Navigate to the "SQL Editor" in your Supabase project dashboard and execute the SQL from `specs/001-borrowed-items-manager/contracts/supabase_schema.md` to create the `items` table and its policies.
3.  **Create Storage Bucket**: Execute the SQL from the same file to create the `item_photos` bucket and its policies.
4.  **Get API Credentials**: In your Supabase project, go to "Project Settings" > "API" and find your **Project URL** and **anon key**.

## 3. Flutter Project Setup

1.  **Add Dependencies**: Open `pubspec.yaml` and add the following dependencies:

    ```yaml
    dependencies:
        flutter:
            sdk: flutter
        supabase_flutter: ^2.0.0 # Check for the latest version
        flutter_riverpod: ^2.0.0 # Check for the latest version
        image_picker: ^1.0.0 # Check for the latest version
        flutter_contacts: ^1.1.7 # Check for the latest version
    ```

2.  **Install Dependencies**: Run `flutter pub get` in your terminal.

3.  **Initialize Supabase**: In your `lib/main.dart` file, initialize the Supabase client before running the app.

    ```dart
    import 'package:flutter/material.dart';
    import 'package:supabase_flutter/supabase_flutter.dart';

    void main() async {
      WidgetsFlutterBinding.ensureInitialized();

      await Supabase.initialize(
        url: 'YOUR_SUPABASE_URL',
        anonKey: 'YOUR_SUPABASE_ANON_KEY',
      );

      runApp(const MyApp());
    }
    ```

    Replace `YOUR_SUPABASE_URL` and `YOUR_SUPABASE_ANON_KEY` with your actual credentials. It is highly recommended to store these in environment variables rather than hardcoding them.

## 4. Running the App

1.  Connect a device or start an emulator.
2.  Run the app from your IDE or using the command line:
    ```bash
    flutter run
    ```

This will launch the app on your selected device. You can now start developing the features outlined in the `plan.md`.
