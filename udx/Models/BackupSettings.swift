import Foundation

enum BackupFrequency: String, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case manual = "Manual"
    
    var displayName: String {
        return self.rawValue
    }
    
    var description: String {
        switch self {
        case .daily:
            return "Backup automatically every day"
        case .weekly:
            return "Backup automatically every week"
        case .monthly:
            return "Backup automatically every month"
        case .manual:
            return "Backup only when you choose"
        }
    }
    
    var systemImageName: String {
        switch self {
        case .daily:
            return "calendar.day.timeline.left"
        case .weekly:
            return "calendar.week"
        case .monthly:
            return "calendar.month"
        case .manual:
            return "hand.tap"
        }
    }
}

// UserDefaults extension for backup settings
extension UserDefaults {
    private enum Keys {
        static let backupFrequency = "BackupFrequency"
        static let lastBackupDate = "LastBackupDate"
        static let backupFrequencyChangedDate = "BackupFrequencyChangedDate"
    }
    
    var backupFrequency: BackupFrequency {
        get {
            guard let rawValue = string(forKey: Keys.backupFrequency),
                  let frequency = BackupFrequency(rawValue: rawValue) else {
                return .daily // Default to daily
            }
            return frequency
        }
        set {
            set(newValue.rawValue, forKey: Keys.backupFrequency)
            set(Date(), forKey: Keys.backupFrequencyChangedDate)
        }
    }
    
    var lastBackupDate: Date? {
        get { object(forKey: Keys.lastBackupDate) as? Date }
        set { set(newValue, forKey: Keys.lastBackupDate) }
    }
    
    var backupFrequencyChangedDate: Date? {
        get { object(forKey: Keys.backupFrequencyChangedDate) as? Date }
    }
}
