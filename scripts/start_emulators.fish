#!/usr/bin/env fish
# Convenience script to start Firebase emulators (firestore + storage + ui)
set -l CMD firebase emulators:start --only firestore,storage --import=./emulator_data
echo "Starting Firebase emulators (firestore, storage)..."
exec $CMD
