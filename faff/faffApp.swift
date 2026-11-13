//
//  faffApp.swift
//  faff
//
//  Created by kyle reddy  on 6/20/24.
//

import SwiftUI
import SwiftData

@main
struct faffApp: App {
    /// Outcome of opening the SwiftData store at launch.
    private enum Store {
        case ready(ModelContainer)
        /// The on-disk store could not be opened, but an empty in-memory one
        /// stands in so the app still runs. Nothing the user does will persist.
        case ephemeral(ModelContainer, reason: String)
        /// Nothing could be created at all.
        case unavailable(reason: String)
    }

    private let store: Store
    @State private var themeManager = ThemeManager.shared

    init() {
        store = Self.openStore()
    }

    /// Open the persistent store, degrading instead of crashing. A corrupt or
    /// unmigratable store used to hit `fatalError` here, which turns any bad
    /// state into an unrecoverable launch crash.
    private static func openStore() -> Store {
        do {
            let container = try ModelContainer(
                for: MediaItem.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: false)
            )
            seedIfNeeded(container)
            normalizeSortOrder(container)
            return .ready(container)
        } catch {
            let reason = error.localizedDescription
            // Last resort: run against a scratch store so the person can still
            // open the app, read the explanation, and export or reinstall.
            do {
                let fallback = try ModelContainer(
                    for: MediaItem.self,
                    configurations: ModelConfiguration(isStoredInMemoryOnly: true)
                )
                return .ephemeral(fallback, reason: reason)
            } catch {
                return .unavailable(reason: reason)
            }
        }
    }

    /// Seed sample data only on a fresh (empty) store so the user's real data —
    /// including imports and cached definitions — persists across launches.
    /// Release builds start empty and are populated by the user.
    private static func seedIfNeeded(_ container: ModelContainer) {
        #if DEBUG
        let context = container.mainContext
        let existing = (try? context.fetchCount(FetchDescriptor<MediaItem>())) ?? 0
        if existing == 0 {
            SampleData.generateSampleData(modelContext: context)
        }
        #endif
    }

    /// One-time backfill for stores written before `sortIndex` existed.
    ///
    /// Lightweight migration gives every existing row the default of 0, which
    /// leaves the sort just as unstable as having no sort at all. Stamping
    /// distinct indices once turns the current arbitrary order into a fixed
    /// one the user can then rearrange.
    private static func normalizeSortOrder(_ container: ModelContainer) {
        let context = container.mainContext
        guard let items = try? context.fetch(FetchDescriptor<MediaItem>()),
              items.count > 1,
              items.allSatisfy({ $0.sortIndex == 0 })
        else { return }

        for (offset, item) in items.enumerated() {
            item.sortIndex = offset
            // Words carry the same default, so settle their order too.
            if item.learnedWords.allSatisfy({ $0.sortIndex == 0 }) {
                for (wordOffset, word) in item.learnedWords.enumerated() {
                    word.sortIndex = wordOffset
                }
            }
        }
        try? context.save()
    }

    var body: some Scene {
        WindowGroup {
            switch store {
            case .ready(let container):
                MainTabView()
                    .environment(themeManager)
                    .preferredColorScheme(themeManager.theme.isDark ? .dark : .light)
                    .modelContainer(container)

            case .ephemeral(let container, let reason):
                MainTabView()
                    .environment(themeManager)
                    .preferredColorScheme(themeManager.theme.isDark ? .dark : .light)
                    .modelContainer(container)
                    .storeFailureAlert(reason: reason)

            case .unavailable(let reason):
                StoreUnavailableView(reason: reason)
                    .environment(themeManager)
            }
        }
    }
}

// MARK: - Degraded-store UI

private extension View {
    /// One-time warning that the session is running against a scratch store.
    func storeFailureAlert(reason: String) -> some View {
        modifier(StoreFailureAlert(reason: reason))
    }
}

private struct StoreFailureAlert: ViewModifier {
    let reason: String
    @State private var isPresented = true

    func body(content: Content) -> some View {
        content.alert("Your library couldn\u{2019}t be opened", isPresented: $isPresented) {
            Button("Continue", role: .cancel) {}
        } message: {
            Text("faff is running with a temporary, empty library, so anything you add now will be lost when you quit. Your saved words have not been deleted.\n\n\(reason)")
        }
    }
}

/// Shown only if even an in-memory store cannot be created.
private struct StoreUnavailableView: View {
    let reason: String
    @Environment(ThemeManager.self) private var themeManager

    private var theme: AppTheme { themeManager.theme }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(theme.primary)
                    .accessibilityHidden(true)
                Text("faff can\u{2019}t start")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
                Text("The word library couldn\u{2019}t be loaded. Restarting the app usually fixes this. If it keeps happening, reinstalling will clear the damaged library.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme.textSecondary)
                Text(reason)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme.textSecondary.opacity(0.7))
                    .padding(.top, 4)
            }
            .padding(32)
        }
    }
}
