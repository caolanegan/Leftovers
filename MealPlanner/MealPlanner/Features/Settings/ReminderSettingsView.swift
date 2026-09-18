import SwiftUI
import UIKit
import UserNotifications
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MealPlanner", category: "ReminderSettingsView")

private let weekdayOptions: [(name: String, value: Int)] = [
    ("Monday", 2), ("Tuesday", 3), ("Wednesday", 4), ("Thursday", 5),
    ("Friday", 6), ("Saturday", 7), ("Sunday", 1),
]

/// §10.12 page 1 / §11. Was a `Section` embedded directly in `SettingsView`'s
/// `Form` (M11); v1.6 moves it onto its own page, reached from the root's
/// "Shopping Reminder" row — same behaviour and storage, only its location
/// changes.
struct ReminderSettingsView: View {
    @AppStorage("reminder.enabled") private var enabled = false
    @AppStorage("reminder.weekday") private var weekday = 1
    @AppStorage("reminder.minutes") private var minutes = 1080

    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var showingDeniedAlert = false

    private let scheduler = NotificationScheduler()
    private let calendar = WeekMath.appCalendar

    var body: some View {
        Form {
            Section {
                Toggle("Reminder", isOn: $enabled)
                    .onChange(of: enabled) { _, newValue in handleToggle(newValue) }
                if enabled {
                    Picker("Day", selection: $weekday) {
                        ForEach(weekdayOptions, id: \.value) { option in
                            Text(option.name).tag(option.value)
                        }
                    }
                    .onChange(of: weekday) { _, _ in reschedule() }
                    DatePicker("Time", selection: timeBinding, displayedComponents: .hourAndMinute)
                }
            } footer: {
                if enabled {
                    Text(footerText)
                }
            }
        }
        .navigationTitle("Shopping Reminder")
        .task { await refreshStatus() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await refreshStatus() }
            }
        }
        .alert("Notifications are off", isPresented: $showingDeniedAlert) {
            Button("Open Settings") { openAppSettings() }
            Button("OK", role: .cancel) {}
        } message: {
            Text("Turn on notifications for MealPlanner in Settings to get this reminder.")
        }
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: { calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now },
            set: { newDate in
                let components = calendar.dateComponents([.hour, .minute], from: newDate)
                minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
                reschedule()
            }
        )
    }

    private var footerText: String {
        if authorizationStatus == .denied {
            return "Notifications are turned off for MealPlanner. Turn them on in Settings to get this reminder."
        }
        return NotificationScheduler.footerText(
            weekday: weekday, minutes: minutes, now: .now, calendar: calendar, locale: .current
        )
    }

    private func handleToggle(_ isOn: Bool) {
        guard isOn else {
            scheduler.cancelWeeklyReminder()
            return
        }
        Task {
            let status = await scheduler.authorizationStatus()
            switch status {
            case .notDetermined:
                do {
                    let granted = try await scheduler.requestAuthorization()
                    authorizationStatus = granted ? .authorized : .denied
                    if granted {
                        await schedule()
                    } else {
                        enabled = false
                        showingDeniedAlert = true
                    }
                } catch {
                    logger.error("Failed to request notification authorization: \(error, privacy: .public)")
                    enabled = false
                    showingDeniedAlert = true
                }
            case .denied:
                authorizationStatus = .denied
                enabled = false
                showingDeniedAlert = true
            default:
                authorizationStatus = status
                await schedule()
            }
        }
    }

    private func reschedule() {
        guard enabled else { return }
        Task { await schedule() }
    }

    private func schedule() async {
        do {
            try await scheduler.scheduleWeeklyReminder(weekday: weekday, hour: minutes / 60, minute: minutes % 60)
        } catch {
            logger.error("Failed to schedule reminder: \(error, privacy: .public)")
        }
    }

    /// Display-only: updates the footer's permission warning. Rescheduling
    /// on `scenePhase == .active` is `RootTabView`'s job (§9.2) — it runs
    /// whether or not this page is open. This only reacts to the user's own
    /// actions (toggle on, day/time change), so the two never both write.
    private func refreshStatus() async {
        authorizationStatus = await scheduler.authorizationStatus()
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }

    /// The Settings root row's trailing value: "Off", or e.g. "Sun 18:00".
    static func trailingValue(enabled: Bool, weekday: Int, minutes: Int) -> String {
        guard enabled else { return "Off" }
        let dayNames = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let dayName = (1...7).contains(weekday) ? dayNames[weekday] : "Sun"
        return String(format: "%@ %02d:%02d", dayName, minutes / 60, minutes % 60)
    }
}

#Preview {
    NavigationStack {
        ReminderSettingsView()
    }
}
