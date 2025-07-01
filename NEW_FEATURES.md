# Udx App - Recent Updates

## New Features Implemented

### 1. Edit/Delete Logged Sets
- **Edit Functionality**: Users can now edit any logged set by tapping the pencil icon
  - Modify reps, weight, duration, distance based on exercise type
  - Change warm-up status
  - Add or edit notes
  - Changes are automatically reflected in exercise history

- **Delete Functionality**: Users can delete logged sets with the trash icon
  - Confirmation dialog prevents accidental deletion
  - Remaining sets are automatically renumbered
  - Exercise history is updated to reflect the changes

- **Implementation Files**:
  - `LoggedSetRowView.swift` - Row component with edit/delete buttons
  - `EditSetView.swift` - Full-screen editor for modifying set details
  - Updated `LogExerciseView.swift` to use the new components

### 2. Clone Workouts & Template System

- **Template Feature**: Any workout can be saved as a template
  - Toggle template status from workout detail view or context menu
  - Templates are separated from regular workouts in the list view
  - Templates appear with a document icon for easy identification

- **Clone Functionality**: 
  - Clone from any previous workout or template
  - "Clone Yesterday's Workout" quick action
  - Customize name and date when cloning
  - All exercises, sets, reps, and targets are copied

- **Implementation Files**:
  - `CloneWorkoutView.swift` - Interface for cloning workouts
  - Updated `WorkoutPlan.swift` model with `isTemplate` property
  - Updated `PlansView.swift` with template filtering and clone options

## How to Use

### Editing/Deleting Sets
1. Open any workout and tap on an exercise to log sets
2. After logging sets, tap the pencil icon to edit
3. Tap the trash icon to delete (with confirmation)

### Creating Templates
1. From the workout list, long-press any workout
2. Select "Save as Template" from the context menu
3. Or open a workout and use the menu to toggle template status

### Cloning Workouts
1. Tap the + button in the workout list
2. Select "Clone Workout" from the menu
3. Choose a source workout or template
4. Customize the name and date
5. Optionally save the clone as a new template

### Viewing Templates
1. In the workout list view, tap "Show Templates" button
2. Templates are displayed separately from regular workouts
3. Switch back with "Show Plans" button

## Technical Details

- All changes are persisted to SwiftData immediately
- Exercise history is automatically updated when sets are modified
- Progressive overload calculations work with cloned workouts
- Templates don't affect completion statistics
