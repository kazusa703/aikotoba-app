import SwiftUI

struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var notifications: [AppNotification] = []
    @State private var isLoading = false
    
    let service = MessageService()
    
    // Instagram Colors
    private let instagramGradient = LinearGradient(
        colors: [
            Color(red: 131/255, green: 58/255, blue: 180/255),
            Color(red: 253/255, green: 29/255, blue: 29/255),
            Color(red: 252/255, green: 176/255, blue: 69/255)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                } else if notifications.isEmpty {
                    emptyView
                } else {
                    notificationList
                }
            }
            .navigationTitle("アクティビティ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .task {
                isLoading = true
                do {
                    notifications = try await service.fetchNotifications()
                } catch {
                    print("Notification error: \(error)")
                }
                isLoading = false
            }
        }
    }
    
    // MARK: - Empty View
    private var emptyView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                    .frame(width: 80, height: 80)
                
                Image(systemName: "heart")
                    .font(.system(size: 36))
                    .foregroundColor(.gray)
            }
            
            Text("アクティビティはありません")
                .font(.headline)
            
            Text("投稿への反応があるとここに表示されます")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
    }
    
    // MARK: - Notification List
    private var notificationList: some View {
        List {
            ForEach(notifications) { item in
                notificationRow(item)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
        .listStyle(.plain)
    }
    
    private func notificationRow(_ item: AppNotification) -> some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(instagramGradient)
                    .frame(width: 44, height: 44)
                
                Image(systemName: iconForNotification(item))
                    .foregroundColor(.white)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(item.body)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                Text(formatDate(item.created_at))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Unread indicator
            if !item.is_read {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Helpers
    private func iconForNotification(_ item: AppNotification) -> String {
        if item.title.contains("奪") {
            return "flag.fill"
        } else if item.title.contains("防衛") {
            return "shield.fill"
        } else {
            return "bell.fill"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
