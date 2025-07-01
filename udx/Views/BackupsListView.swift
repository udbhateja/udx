import SwiftUI
import SwiftData

struct BackupsListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var exportImportService = ExportImportService.shared
    @State private var backups: [BackupInfo] = []
    @State private var showDeleteConfirmation = false
    @State private var backupToDelete: BackupInfo?
    @State private var showShareSheet = false
    @State private var shareURL: URL?
    @State private var showImportConfirmation = false
    @State private var importBackup: BackupInfo?
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationStack {
            List {
                if backups.isEmpty {
                    ContentUnavailableView(
                        "No Backups",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Your backups will appear here")
                    )
                } else {
                    ForEach(backups) { backup in
                        BackupRowView(
                            backup: backup,
                            onShare: { shareBackup(backup) },
                            onRestore: { confirmRestore(backup) },
                            onDelete: { confirmDelete(backup) }
                        )
                    }
                }
            }
            .navigationTitle("Backups")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadBackups()
            }
            .confirmationDialog(
                "Delete Backup",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let backup = backupToDelete {
                        deleteBackup(backup)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete this backup? This action cannot be undone.")
            }
            .confirmationDialog(
                "Restore Backup",
                isPresented: $showImportConfirmation,
                titleVisibility: .visible
            ) {
                Button("Restore", role: .destructive) {
                    if let backup = importBackup {
                        Task { await restoreBackup(backup) }
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will replace all existing data with the backup. Are you sure you want to continue?")
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = shareURL {
                    ShareSheet(url: url)
                }
            }
            .alert(alertTitle, isPresented: $showAlert) {
                if alertTitle == "Restore Successful" {
                    Button("OK") { exit(0) }
                } else {
                    Button("OK") { }
                }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func loadBackups() {
        backups = exportImportService.getBackupsList()
    }
    
    private func shareBackup(_ backup: BackupInfo) {
        shareURL = backup.url
        showShareSheet = true
    }
    
    private func confirmRestore(_ backup: BackupInfo) {
        importBackup = backup
        showImportConfirmation = true
    }
    
    private func confirmDelete(_ backup: BackupInfo) {
        backupToDelete = backup
        showDeleteConfirmation = true
    }
    
    private func deleteBackup(_ backup: BackupInfo) {
        do {
            try exportImportService.deleteBackup(backup)
            loadBackups()
        } catch {
            alertTitle = "Delete Failed"
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }
    
    private func restoreBackup(_ backup: BackupInfo) async {
        do {
            guard let container = try? modelContext.container else {
                throw ImportError.storeNotFound
            }
            
            try await exportImportService.importData(from: backup.url, modelContainer: container)
            
            alertTitle = "Restore Successful"
            alertMessage = "Data restored successfully. The app needs to restart to load the restored data."
            showAlert = true
        } catch {
            alertTitle = "Restore Failed"
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }
}

struct BackupRowView: View {
    let backup: BackupInfo
    let onShare: () -> Void
    let onRestore: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(backup.formattedDate)
                        .font(.headline)
                    
                    HStack {
                        if backup.isManual {
                            Label("Manual", systemImage: "hand.tap")
                                .font(.caption)
                                .foregroundColor(.blue)
                        } else {
                            Label("Automatic", systemImage: "arrow.clockwise")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text(backup.formattedSize)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Menu {
                    Button {
                        onShare()
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    
                    Button {
                        onRestore()
                    } label: {
                        Label("Restore", systemImage: "arrow.down.circle")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
