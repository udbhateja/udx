# UDX Export/Import System

## Overview
The UDX app now includes a robust export/import system that uses SwiftData's native SQLite database format. This ensures complete data integrity and preserves all relationships between exercises, muscles, and workout plans.

## Features

### Manual Export/Import
- **Export**: Creates a .udxbackup file containing the complete SQLite database
- **Import**: Restores data from a previously exported .udxbackup file
- **Format**: Custom archive format containing SQLite database files and metadata

### Automatic Daily Backup
- Runs automatically when the app launches
- Saves to `Documents/UDX_Backups/` folder
- Maintains rolling 7-day backup retention
- Non-intrusive background operation

### Data Integrity
- All relationships between entities are preserved
- No data transformation needed - uses native SwiftData format
- Includes metadata for version compatibility checking

## Implementation Details

### Files Modified
1. **ExportImportService.swift** - Core export/import functionality (iOS-compatible)
2. **SettingsView.swift** - UI for export/import operations
3. **udxApp.swift** - Automatic export on app launch
4. **udx.entitlements** - File system permissions

### How It Works
1. **Export Process**:
   - Locates the SwiftData SQLite database (`UdxModels.sqlite`)
   - Copies all related files (including WAL and SHM files)
   - Creates metadata with version info
   - Packages everything into a custom .udxbackup file

2. **Import Process**:
   - Extracts the .udxbackup file
   - Validates metadata and version compatibility
   - Backs up current data
   - Replaces database files
   - Requires app restart to load new data

### Custom Archive Format
The .udxbackup file uses a simple custom format:
- Header: "UDXBACKUP1.0" (12 bytes)
- File count (4 bytes)
- For each file:
  - Filename length (4 bytes)
  - Filename (UTF-8 string)
  - File size (8 bytes)
  - File data

### Security
- Uses iOS file sandboxing
- Requires explicit user permission for file access
- Automatic backups stored in app's Documents folder

## Usage

### To Export Data:
1. Open Settings
2. Tap "Export Data"
3. Choose where to save/share the .udxbackup file

### To Import Data:
1. Open Settings
2. Tap "Import Data"
3. Select a previously exported .udxbackup file
4. Confirm replacement of existing data
5. App will prompt for restart

### Accessing Automatic Backups:
- iOS Files app → On My iPhone/iPad → UDX → UDX_Backups
- Backups are named: `udx_backup_YYYY-MM-DD_HHmmss.udxbackup`

## Important Notes
- Import operation replaces ALL existing data
- Always export current data before importing
- The app must restart after import to load new data
- Automatic backups occur once per day maximum
- The custom .udxbackup format is specific to this app

## Technical Details
- No external dependencies (Process class not available on iOS)
- Uses FileManager and Data APIs for archiving
- Thread-safe operations with NSFileCoordinator
- Supports SQLite WAL mode (Write-Ahead Logging)
