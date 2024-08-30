//
//  Enums.swift
//  faff
//
//  Created by kyle reddy  on 6/26/24.
//

import Foundation
import SwiftUI

enum MediaType: String, Codable, CaseIterable {
    case book, movie, podcast, other
}

enum ProgressStatus: String, Codable, CaseIterable {
    case inProgress = "In Progress"
    case completed = "Completed"
    case repeated = "Repeated"
    
    var color: Color {
        switch self {
        case .inProgress: return .blue
        case .completed: return .green
        case .repeated: return .purple
        }
    }
    
    var icon: String {
        switch self {
        case .inProgress: return "book"
        case .completed: return "checkmark.circle.fill"
        case .repeated: return "arrow.clockwise.circle.fill"
        }
    }
}
