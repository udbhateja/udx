# Backup Frequency Settings - Implementation Summary

## Features Implemented

### 1. Backup Frequency Options
Users can now choose between four backup frequencies in Settings:
- **Daily**: Automatic backup every day
- **Weekly**: Automatic backup every week  
- **Monthly**: Automatic backup every month
- **Manual**: No automatic backups, user must backup manually

### 2. Backup Management Interface
- **Backup Settings Section** in Settings view shows:
  - Frequency picker with descriptive icons and text
  - Current backup status with last backup date
  - "Backup Now" button when Manual mode is selected
  - Link to view all backups with count

### 3. Backups List View
- Shows all backups with:
  - Date and time of backup
  - Manual vs Automatic indicator
  - File size
- Actions available for each backup:
  - Share backup file
  - Restore from backup
  - Delete backup
- Confirmation dialogs for destructive actions

### 4. Automatic Backup System
- Checks and performs backups based on selected frequency
- Runs on app launch and when viewing Settings
- Different retention policies:
  - Daily: Keeps 7 days of backups
  - Weekly: Keeps 4 weeks of backups
  - Monthly: Keeps 12 months of backups
  - Manual: Keeps backups for 30 days

### 5. Manual Backup
- Available when "Manual" frequency is selected
- Creates backup with "manual_" prefix for easy identification
- Shows success/failure alerts

## Technical Implementation

### New Files Created:
1. `BackupSettings.swift` - Enum and UserDefaults extensions
2. `BackupsListView.swift` - UI for viewing and managing backups

### Modified Files:
1. `ExportImportService.swift` - Added frequency-based backup logic
2. `SettingsView.swift` - Added backup frequency settings UI
3. `udxApp.swift` - Triggers automatic backup on launch

### Key Features:
- Backups stored in app's Documents directory under "UDX_Backups" folder
- Automatic cleanup of old backups based on retention policy
- Seamless switching between backup frequencies
- Backup files use custom `.udxbackup` extension
- All backup operations are async and show progress indicators

## Usage Instructions

### Setting Backup Frequency:
1. Go to Settings
2. In "Backup Settings" section, tap "Backup Frequency"
3. Choose desired frequency from the menu
4. Automatic backups will follow the new schedule

### Manual Backup:
1. Set frequency to "Manual"
2. Tap "Backup Now" button when needed
3. Backup is created immediately

### Managing Backups:
1. Tap "View Backups" in Settings
2. See all backups sorted by date
3. Use the menu (⋯) for each backup to:
   - Share the backup file
   - Restore from that backup
   - Delete the backup

### Restoring from Backup:
1. Select a backup and choose "Restore"
2. Confirm the action (will replace all current data)
3. App will restart automatically after successful restore

## Data Safety
- All backups include metadata (version, date, app version)
- Automatic version compatibility checking
- Current data is backed up before any restore operation
- Failed operations show descriptive error messages
