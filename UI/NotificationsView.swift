import SwiftUI

struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var notifications: [AppNotification] = []
    let service = MessageService()

    var body: some View {
        NavigationStack {
            List(notifications) { item in
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundColor(.red) // 警告っぽく赤色に
                    
                    Text(item.body)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    Text(item.created_at.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("お知らせ")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
            .task {
                do {
                    notifications = try await service.fetchNotifications()
                } catch {
                    print("Notification error: \(error)")
                }
            }
            .overlay {
                if notifications.isEmpty {
                    ContentUnavailableView("お知らせはありません", systemImage: "bell.slash")
                }
            }
        }
    }
}
