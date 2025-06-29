import Foundation
import SwiftData
import SwiftUI

@MainActor
final class ExportImportService: ObservableObject {
    static let shared = ExportImportService()
    
    @Published var isExporting = false
    @Published var isImporting = false
    @Published var lastExportDate: Date? {
        didSet {
            UserDefaults.standard.set(lastExportDate, forKey: "LastExportDate")
        }
    }
    @Published var lastImportDate: Date? {
        didSet {
            UserDefaults.standard.set(lastImportDate, forKey: "LastImportDate")
        }
    }
    
    private let fileManager = FileManager.default
    
    private init() {
        lastExportDate = UserDefaults.standard.object(forKey: "LastExportDate") as? Date
        lastImportDate = UserDefaults.standard.object(forKey: "LastImportDate") as? Date
    }
    
    // MARK: - Export Methods
    
    func exportData() async throws -> URL {
        isExporting = true
        defer { isExporting = false }
        
        // Get the SwiftData store URL
        guard let storeURL = getStoreURL() else {
            throw ExportError.storeNotFound
        }
        
        // Create export directory
        let exportDir = fileManager.temporaryDirectory.appendingPathComponent("UDX_Export_\(Date().timeIntervalSince1970)")
        try fileManager.createDirectory(at: exportDir, withIntermediateDirectories: true)
        
        // Copy all SwiftData files (including WAL and SHM files for SQLite)
        let storeDirectory = storeURL.deletingLastPathComponent()
        let storeName = storeURL.lastPathComponent
        
        // Get all related files (main store, WAL, SHM)
        let filesToCopy = try fileManager.contentsOfDirectory(at: storeDirectory, includingPropertiesForKeys: nil)
            .filter { url in
                let fileName = url.lastPathComponent
                return fileName.hasPrefix(storeName.replacingOccurrences(of: ".sqlite", with: ""))
            }
        
        // Copy each file
        for file in filesToCopy {
            let destURL = exportDir.appendingPathComponent(file.lastPathComponent)
            try fileManager.copyItem(at: file, to: destURL)
        }
        
        // Create metadata file
        let metadata = ExportMetadata(
            version: "1.0",
            exportDate: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        )
        
        let metadataURL = exportDir.appendingPathComponent("metadata.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let metadataData = try encoder.encode(metadata)
        try metadataData.write(to: metadataURL)
        
        // Create archive using FileManager (iOS compatible approach)
        let archiveURL = fileManager.temporaryDirectory.appendingPathComponent("udx_backup_\(DateFormatter.backupDateFormatter.string(from: Date())).udxbackup")
        
        // Create the data package directly without NSFileCoordinator
        let packageData = try createDataPackage(from: exportDir)
        try packageData.write(to: archiveURL)
        
        // Clean up temporary directory
        try? fileManager.removeItem(at: exportDir)
        
        lastExportDate = Date()
        
        return archiveURL
    }
    
    // MARK: - Import Methods
    
    func importData(from url: URL, modelContainer: ModelContainer) async throws {
        isImporting = true
        defer { isImporting = false }
        
        // Start accessing the security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            throw ImportError.cannotAccessFile
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        // Create temporary directory for extraction
        let extractDir = fileManager.temporaryDirectory.appendingPathComponent("UDX_Import_\(Date().timeIntervalSince1970)")
        try fileManager.createDirectory(at: extractDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: extractDir) }
        
        // Extract package
        try extractDataPackage(from: url, to: extractDir)
        
        // Verify metadata
        let metadataURL = extractDir.appendingPathComponent("metadata.json")
        guard fileManager.fileExists(atPath: metadataURL.path) else {
            throw ImportError.invalidFormat
        }
        
        let metadataData = try Data(contentsOf: metadataURL)
        let metadata = try JSONDecoder().decode(ExportMetadata.self, from: metadataData)
        
        // Check version compatibility
        guard metadata.version == "1.0" else {
            throw ImportError.incompatibleVersion
        }
        
        // Get current store URL
        guard let storeURL = getStoreURL() else {
            throw ImportError.storeNotFound
        }
        
        let storeDirectory = storeURL.deletingLastPathComponent()
        let storeName = storeURL.lastPathComponent
        
        // Backup current data before replacing
        let backupDir = storeDirectory.appendingPathComponent("backup_\(Date().timeIntervalSince1970)")
        try fileManager.createDirectory(at: backupDir, withIntermediateDirectories: true)
        
        // Move current files to backup
        let currentFiles = try fileManager.contentsOfDirectory(at: storeDirectory, includingPropertiesForKeys: nil)
            .filter { url in
                let fileName = url.lastPathComponent
                return fileName.hasPrefix(storeName.replacingOccurrences(of: ".sqlite", with: ""))
            }
        
        for file in currentFiles {
            let backupURL = backupDir.appendingPathComponent(file.lastPathComponent)
            try fileManager.moveItem(at: file, to: backupURL)
        }
        
        // Copy imported files
        let importedFiles = try fileManager.contentsOfDirectory(at: extractDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "sqlite" || $0.lastPathComponent.contains(".sqlite") }
        
        for file in importedFiles {
            let destURL = storeDirectory.appendingPathComponent(file.lastPathComponent)
            try fileManager.copyItem(at: file, to: destURL)
        }
        
        lastImportDate = Date()
        
        // Note: You'll need to restart the app or recreate the model container
        // to load the new data. This typically requires app restart.
    }
    
    // MARK: - Automatic Export
    
    func performAutomaticExportIfNeeded() async {
        let calendar = Calendar.current
        let now = Date()
        
        // Check if we've exported today
        if let lastExport = lastExportDate,
           calendar.isDateInToday(lastExport) {
            return
        }
        
        // Perform automatic export
        do {
            let exportURL = try await exportData()
            
            // Move to documents directory for automatic backups
            let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let backupsFolder = documentsPath.appendingPathComponent("UDX_Backups")
            
            // Create backups folder if needed
            try? fileManager.createDirectory(at: backupsFolder, withIntermediateDirectories: true)
            
            // Clean up old backups (keep last 7 days)
            try await cleanupOldBackups(in: backupsFolder, keepDays: 7)
            
            // Move new backup
            let backupURL = backupsFolder.appendingPathComponent(exportURL.lastPathComponent)
            try? fileManager.moveItem(at: exportURL, to: backupURL)
            
        } catch {
            print("Automatic export failed: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func getStoreURL() -> URL? {
        // Get the SwiftData store URL - matches SwiftDataManager configuration
        return URL.applicationSupportDirectory.appending(path: "UdxModels.sqlite")
    }
    
    private func createDataPackage(from directory: URL) throws -> Data {
        // Create a simple archive by combining all files into a single data blob
        var archiveData = Data()
        
        // Add a header to identify this as a UDX backup
        let header = "UDXBACKUP1.0".data(using: .utf8)!
        archiveData.append(header)
        
        // Get all files in directory
        let files = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey])
        
        // Add file count
        var fileCount = Int32(files.count)
        archiveData.append(Data(bytes: &fileCount, count: MemoryLayout<Int32>.size))
        
        // Add each file
        for file in files {
            let fileName = file.lastPathComponent
            let fileData = try Data(contentsOf: file)
            
            // Add filename length and filename
            let nameData = fileName.data(using: .utf8)!
            var nameLength = Int32(nameData.count)
            archiveData.append(Data(bytes: &nameLength, count: MemoryLayout<Int32>.size))
            archiveData.append(nameData)
            
            // Add file size and file data
            var fileSize = Int64(fileData.count)
            archiveData.append(Data(bytes: &fileSize, count: MemoryLayout<Int64>.size))
            archiveData.append(fileData)
        }
        
        return archiveData
    }
    
    private func extractDataPackage(from url: URL, to directory: URL) throws {
        let archiveData = try Data(contentsOf: url)
        var offset = 0
        
        // Verify header
        let headerLength = 12
        guard archiveData.count >= headerLength else {
            throw ImportError.invalidFormat
        }
        
        let header = String(data: archiveData[0..<headerLength], encoding: .utf8)
        guard header == "UDXBACKUP1.0" else {
            throw ImportError.invalidFormat
        }
        offset += headerLength
        
        // Read file count
        guard offset + MemoryLayout<Int32>.size <= archiveData.count else {
            throw ImportError.invalidFormat
        }
        let fileCount = archiveData[offset..<offset + MemoryLayout<Int32>.size].withUnsafeBytes { bytes in
            bytes.bindMemory(to: Int32.self).baseAddress!.pointee
        }
        offset += MemoryLayout<Int32>.size
        
        // Extract each file
        for _ in 0..<fileCount {
            // Read filename length
            guard offset + MemoryLayout<Int32>.size <= archiveData.count else {
                throw ImportError.invalidFormat
            }
            let nameLength = archiveData[offset..<offset + MemoryLayout<Int32>.size].withUnsafeBytes { bytes in
                bytes.bindMemory(to: Int32.self).baseAddress!.pointee
            }
            offset += MemoryLayout<Int32>.size
            
            // Read filename
            guard offset + Int(nameLength) <= archiveData.count else {
                throw ImportError.invalidFormat
            }
            let nameData = archiveData[offset..<offset + Int(nameLength)]
            guard let fileName = String(data: nameData, encoding: .utf8) else {
                throw ImportError.invalidFormat
            }
            offset += Int(nameLength)
            
            // Read file size
            guard offset + MemoryLayout<Int64>.size <= archiveData.count else {
                throw ImportError.invalidFormat
            }
            let fileSize = archiveData[offset..<offset + MemoryLayout<Int64>.size].withUnsafeBytes { bytes in
                bytes.bindMemory(to: Int64.self).baseAddress!.pointee
            }
            offset += MemoryLayout<Int64>.size
            
            // Read file data
            guard offset + Int(fileSize) <= archiveData.count else {
                throw ImportError.invalidFormat
            }
            let fileData = archiveData[offset..<offset + Int(fileSize)]
            offset += Int(fileSize)
            
            // Write file
            let fileURL = directory.appendingPathComponent(fileName)
            try fileData.write(to: fileURL)
        }
    }
    
    private func cleanupOldBackups(in directory: URL, keepDays: Int) async throws {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -keepDays, to: Date()) ?? Date()
        
        let backups = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey])
        
        for backup in backups {
            if let creationDate = try? backup.resourceValues(forKeys: [.creationDateKey]).creationDate,
               creationDate < cutoffDate {
                try? fileManager.removeItem(at: backup)
            }
        }
    }
}

// MARK: - Supporting Types

struct ExportMetadata: Codable {
    let version: String
    let exportDate: Date
    let appVersion: String
}

enum ExportError: LocalizedError {
    case storeNotFound
    case archiveCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .storeNotFound:
            return "Could not find the data store"
        case .archiveCreationFailed:
            return "Failed to create backup archive"
        }
    }
}

enum ImportError: LocalizedError {
    case cannotAccessFile
    case invalidFormat
    case incompatibleVersion
    case storeNotFound
    case extractionFailed
    
    var errorDescription: String? {
        switch self {
        case .cannotAccessFile:
            return "Cannot access the selected file"
        case .invalidFormat:
            return "Invalid backup format"
        case .incompatibleVersion:
            return "Incompatible backup version"
        case .storeNotFound:
            return "Could not find the data store"
        case .extractionFailed:
            return "Failed to extract backup archive"
        }
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let backupDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        return formatter
    }()
}