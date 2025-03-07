//
//  Item.swift
//  udx
//
//  Created by Uday Bhateja on 07/03/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
