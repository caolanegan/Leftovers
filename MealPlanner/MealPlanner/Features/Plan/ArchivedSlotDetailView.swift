import SwiftUI

/// Read-only view of a filled slot in an ended week (§10.1): meal name,
/// leftovers label, and ingredients *as they were* at archive time.
struct ArchivedSlotDetailView: View {
    let slot: MealSlot

    private var snapshot: ArchivedSlot? {
        guard let json = slot.archivedSnapshotJSON else { return nil }
        return try? ArchiveCoding.decode(ArchivedSlot.self, from: json)
    }

    var body: some View {
        List {
            if let snapshot {
                Section {
                    if let label = snapshot.leftoverSourceLabel {
                        Label("Leftovers · \(label)", systemImage: "arrow.uturn.backward")
                            .foregroundStyle(.secondary)
                    }
                }

                if !snapshot.ingredients.isEmpty {
                    Section("Ingredients") {
                        ForEach(Array(snapshot.ingredients.enumerated()), id: \.offset) { _, line in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(line.name)
                                    if !line.note.isEmpty {
                                        Text(line.note)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if !line.amountText.isEmpty {
                                    Text(line.amountText)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if let meal = slot.meal {
                    Section {
                        NavigationLink(value: AppRoute.meal(meal)) {
                            Text("View Current Recipe")
                        }
                    }
                }
            }
        }
        .navigationTitle(snapshot?.mealName ?? "Meal")
        .navigationBarTitleDisplayMode(.inline)
    }
}
