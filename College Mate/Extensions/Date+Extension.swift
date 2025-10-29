//
//  Helper.swift
//  College Mate
//
//  Created by Sagar Jangra on 10/01/2025.
//

import SwiftUI

extension Date {
    
    // A single, reusable formatter to improve performance.
    private static let formatter = DateFormatter()
    
    /// Converts the date to a string with a specified format.
    /// - Parameter format: The date format string (e.g., "dd/MM/yy").
    /// - Returns: A formatted string representation of the date.
    func formattedAsString(format: String) -> String {
        Date.formatter.dateFormat = format
        return Date.formatter.string(from: self)
    }
    
    var startOfMonth: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year,.month], from: self)
        
        return calendar.date(from: components) ?? self
    }
    
    var endOfMonth: Date {
        let calendar = Calendar.current
//        let components = calendar.dateComponents([.year,.month], from: self)
        return calendar.date(byAdding: .init(month: 1, minute: -1), to: self.startOfMonth) ?? self
    }
}
