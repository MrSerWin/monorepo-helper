#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-swift-app" "$@"
create_project_dir

MODULE_NAME=$(echo "$PROJECT_NAME" | sed 's/[-_]//g; s/\b\(.\)/\u\1/g; s/ //g')
# Fallback if sed doesn't capitalize
if [[ -z "$MODULE_NAME" ]]; then
  MODULE_NAME="MyApp"
fi

# --- Package.swift ---
write_file "Package.swift" "// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: \"${MODULE_NAME}\",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: \"${MODULE_NAME}Models\",
            targets: [\"${MODULE_NAME}Models\"]
        )
    ],
    targets: [
        .target(
            name: \"${MODULE_NAME}Models\",
            path: \"Sources/Models\"
        ),
        .testTarget(
            name: \"${MODULE_NAME}ModelsTests\",
            dependencies: [\"${MODULE_NAME}Models\"],
            path: \"Tests/ModelsTests\"
        )
    ]
)"

# --- Xcode project generation script ---
write_file_heredoc "setup-xcode.sh" << 'SETUPEOF'
#!/usr/bin/env bash
# Run this to generate an Xcode project (requires Xcode installed)
# Alternatively, open Package.swift in Xcode for SPM-based development
echo "To develop this app:"
echo "  1. Open Package.swift in Xcode for the models library"
echo "  2. Or open the .xcodeproj if generated via 'swift package generate-xcodeproj'"
echo ""
echo "For a full app target, open Xcode > File > New > Project and add existing files."
SETUPEOF
chmod +x setup-xcode.sh

# --- Sources/App/MyApp.swift ---
write_file_heredoc "Sources/App/${MODULE_NAME}App.swift" << APPEOF
import SwiftUI
import SwiftData

@main
struct ${MODULE_NAME}App: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
APPEOF

# --- Sources/App/ContentView.swift ---
write_file_heredoc "Sources/App/ContentView.swift" << 'CVEOF'
import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @State private var viewModel = ItemViewModel()

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(items) { item in
                    NavigationLink {
                        ItemDetailView(item: item)
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(item.title)
                                    .font(.headline)
                                Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem {
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Items")
            .overlay {
                if items.isEmpty {
                    ContentUnavailableView(
                        "No Items",
                        systemImage: "tray",
                        description: Text("Tap + to add your first item.")
                    )
                }
            }
        } detail: {
            Text("Select an item")
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(title: "Item \(items.count + 1)")
            modelContext.insert(newItem)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
CVEOF

# --- Sources/Models/Item.swift ---
write_file_heredoc "Sources/Models/Item.swift" << 'MODELEOF'
import Foundation
import SwiftData

@Model
final class Item: Identifiable {
    var id: UUID
    var title: String
    var timestamp: Date
    var isCompleted: Bool

    init(title: String, timestamp: Date = .now, isCompleted: Bool = false) {
        self.id = UUID()
        self.title = title
        self.timestamp = timestamp
        self.isCompleted = isCompleted
    }
}
MODELEOF

# --- Sources/ViewModels/ItemViewModel.swift ---
write_file_heredoc "Sources/ViewModels/ItemViewModel.swift" << 'VMEOF'
import Foundation
import Observation

@Observable
final class ItemViewModel {
    var searchText: String = ""
    var isShowingAddSheet: Bool = false
    var selectedSortOrder: SortOrder = .dateDescending

    enum SortOrder: String, CaseIterable {
        case dateAscending = "Oldest First"
        case dateDescending = "Newest First"
        case titleAscending = "A-Z"
        case titleDescending = "Z-A"
    }

    var sortComparator: KeyPathComparator<Item> {
        switch selectedSortOrder {
        case .dateAscending:
            return KeyPathComparator(\.timestamp, order: .forward)
        case .dateDescending:
            return KeyPathComparator(\.timestamp, order: .reverse)
        case .titleAscending:
            return KeyPathComparator(\.title, order: .forward)
        case .titleDescending:
            return KeyPathComparator(\.title, order: .reverse)
        }
    }
}
VMEOF

# --- Sources/Views/ItemDetailView.swift ---
write_file_heredoc "Sources/Views/ItemDetailView.swift" << 'DETAILEOF'
import SwiftUI
import SwiftData

struct ItemDetailView: View {
    @Bindable var item: Item

    var body: some View {
        Form {
            Section("Details") {
                TextField("Title", text: $item.title)
                Toggle("Completed", isOn: $item.isCompleted)
            }

            Section("Info") {
                LabeledContent("Created") {
                    Text(item.timestamp, format: Date.FormatStyle(date: .abbreviated, time: .shortened))
                }
                LabeledContent("ID") {
                    Text(item.id.uuidString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ItemDetailView(item: Item(title: "Sample Item"))
    }
    .modelContainer(for: Item.self, inMemory: true)
}
DETAILEOF

# --- Sources/Views/AddItemView.swift ---
write_file_heredoc "Sources/Views/AddItemView.swift" << 'ADDEOF'
import SwiftUI
import SwiftData

struct AddItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("New Item") {
                    TextField("Title", text: $title)
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let item = Item(title: title)
                        modelContext.insert(item)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

#Preview {
    AddItemView()
        .modelContainer(for: Item.self, inMemory: true)
}
ADDEOF

# --- Tests/ModelsTests/ItemTests.swift ---
write_file_heredoc "Tests/ModelsTests/ItemTests.swift" << 'TESTEOF'
import Testing
import Foundation
@testable import Models

@Test func itemInitialization() {
    let item = Item(title: "Test Item")
    #expect(item.title == "Test Item")
    #expect(item.isCompleted == false)
    #expect(item.id != UUID())
}

@Test func itemCompletion() {
    let item = Item(title: "Test")
    item.isCompleted = true
    #expect(item.isCompleted == true)
}
TESTEOF

init_git
write_gitignore \
  ".build/" \
  "*.xcodeproj/" \
  "*.xcworkspace/" \
  "xcuserdata/" \
  "DerivedData/" \
  "*.playground/" \
  ".swiftpm/"
write_editorconfig

write_readme "$PROJECT_NAME" "A Swift 6 app with SwiftUI, SwiftData, and @Observable pattern." \
  "swift build" \
  "open Package.swift  # Opens in Xcode" \
  "- \`swift build\` - Build the package
- \`swift test\` - Run tests
- Open in Xcode for full app development"

finish "swift build" "open Package.swift"
