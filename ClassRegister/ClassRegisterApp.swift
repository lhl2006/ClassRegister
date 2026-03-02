//
//  ClassRegisterApp.swift
//  ClassRegister
//
//  Created by lhl on 2026/3/2.
//

import SwiftData
import SwiftUI

@main
struct ClassRegisterApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [PhotoRecord.self])
    }
}
