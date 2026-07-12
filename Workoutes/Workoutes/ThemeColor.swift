import SwiftUI

enum ThemeColor: String, CaseIterable, Identifiable {
    case primary, mint, blue, purple, orange, green, red, indigo
    
    var id: Self { self }
    
    var color: Color {
        switch self {
        case .primary: return Color(red: 50/255, green: 104/255, blue: 132/255)
        case .mint: return .mint
        case .blue: return .blue
        case .purple: return .purple
        case .orange: return .orange
        case .green: return .green
        case .red: return .red
        case .indigo: return .indigo
        }
    }
    
    var name: String {
        self.rawValue.capitalized
    }
}
