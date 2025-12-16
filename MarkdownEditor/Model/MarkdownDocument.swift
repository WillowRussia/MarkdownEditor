//
//  MarkdownDocument.swift
//  MarkdownEditor
//
//  Created by Илья Востров on 15.12.2025.
//

import Foundation

struct MarkdownDocument: Identifiable, Equatable {
    let id: UUID
    var title: String
    var raw: String
    var updatedAt: Date

    init(id: UUID = UUID(), title: String = "Без названия", raw: String, updatedAt: Date = .now) {
        self.id = id
        self.title = title
        self.raw = raw
        self.updatedAt = updatedAt
    }
}

struct EditorSettings {
    var fontSize: CGFloat = 18
    var theme: Theme = .system
    var autosaveInterval: TimeInterval = 3
    enum Theme { case light, dark, system }
}
