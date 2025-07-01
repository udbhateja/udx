# Swipe Gesture Update for Logged Sets

## Changes Made

### 1. Removed Buttons from LoggedSetRowView
- Removed the edit (pencil) and delete (trash) button icons
- Removed tap gesture handling that was opening the edit screen
- Simplified the row to just display set information

### 2. Added Swipe Actions
- **Swipe left** on any logged set to reveal actions:
  - **Edit** (blue) - Opens the edit sheet
  - **Delete** (red) - Deletes the set immediately
- Set `allowsFullSwipe: false` to prevent accidental deletions

### 3. Improved User Experience
- Added helper text: "Swipe left on any set to edit or delete"
- Cleaner interface without cluttered buttons
- Standard iOS swipe pattern that users are familiar with

### 4. Functionality Preserved
- Edit functionality opens the same EditSetView sheet
- Delete functionality:
  - Removes the set
  - Renumbers remaining sets
  - Updates exercise history
  - Updates the current set counter

## How It Works Now

1. Log sets as normal using the "Log Set" button
2. View completed sets in the list below
3. To edit a set: Swipe left → Tap "Edit" (blue)
4. To delete a set: Swipe left → Tap "Delete" (red)

## Benefits
- Prevents accidental taps that were opening the edit screen
- Cleaner, less cluttered interface
- Standard iOS gesture pattern
- More deliberate action required to edit/delete
- No confirmation dialog needed for delete (can add if desired)

## Technical Details
- Moved edit/delete logic from LoggedSetRowView to LogExerciseView
- Simplified LoggedSetRowView to be a pure display component
- Used SwiftUI's `.swipeActions` modifier
- Maintained all existing functionality for updating exercise history
