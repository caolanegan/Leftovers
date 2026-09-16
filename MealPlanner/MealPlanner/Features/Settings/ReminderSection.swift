import SwiftUI
import UIKit
import UserNotifications
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MealPlanner", category: "ReminderSection")

private let weekdayOptions: [(name: String, value: Int)] = [
    ("Monday", 2), ("Tuesday", 3), ("Wednesday", 4), ("Thursday", 5),
    ("Friday", 6), ("Saturday", 7), ("Sunday", 1),
]

/// §10.12 item 1 / §11.
struct ReminderSection: View {
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
        } header: {
            Text("Shopping Reminder")
        } footer: {
            if enabled {
                Text(footerText)
            }
        }
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
            weekday: weekday, minutes: minutes, now: .now, calendar: calendar, locale: Locale(identifier: "en_GB")
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

    private func refreshStatus() async {
        let status = await scheduler.authorizationStatus()
        authorizationStatus = status
        guard enabled else { return }
        switch status {
        case .authorized, .provisional, .ephemeral:
            await schedule()
        default:
            break  // Denied: the footer warns. The stored toggle is left alone.
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

#Preview {
    Form {
        ReminderSection()
    }
}
