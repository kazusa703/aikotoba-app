import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @State private var notifications: [AppNotification] = []
    @State private var isLoading = true
    
    let service = MessageService()

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    if isLoading {
                        ProgressView()
                            .tint(AppColors.primary)
                            .padding(.top, 50)
                    } else if notifications.isEmpty {
                        emptyState
                    } else {
                        // 未読セクション
                        if !unreadNotifications.isEmpty {
                            sectionHeader("新着")
                            ForEach(unreadNotifications) { notification in
                                notificationRow(notification)
                            }
                        }
                        
                        // 既読セクション
                        if !readNotifications.isEmpty {
                            sectionHeader("以前")
                            ForEach(readNotifications) { notification in
                                notificationRow(notification)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("アクティビティ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !notifications.isEmpty && !unreadNotifications.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("すべて既読") {
                        Task { await markAllAsRead() }
                    }
                    .font(.subheadline)
                    .foregroundColor(AppColors.primary)
                }
            }
        }
        .task {
            await loadNotifications()
        }
        .refreshable {
            await loadNotifications()
        }
    }
    
    // MARK: - Computed Properties
    
    private var unreadNotifications: [AppNotification] {
        notifications.filter { !$0.is_read }
    }
    
    private var readNotifications: [AppNotification] {
        notifications.filter { $0.is_read }
    }
    
    // MARK: - Components
    
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppColors.background)
    }
    
    private func notificationRow(_ notification: AppNotification) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // アイコン
                ZStack {
                    Circle()
                        .fill(notification.color.opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: notification.icon)
                        .font(.system(size: 20))
                        .foregroundColor(notification.color)
                }
                
                // テキスト
                VStack(alignment: .leading, spacing: 4) {
                    Text(notification.title)
                        .font(.subheadline)
                        .fontWeight(notification.is_read ? .regular : .bold)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text(notification.body)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                    
                    Text(timeAgo(notification.created_at))
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()
                
                // 未読マーク
                if !notification.is_read {
                    Circle()
                        .fill(AppColors.accent)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(notification.is_read ? Color.white : AppColors.accent.opacity(0.05))
            .contentShape(Rectangle())
            .onTapGesture {
                Task {
                    await markAsRead(notification)
                }
            }
            
            Divider()
                .padding(.leading, 78)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppColors.primaryGradient)
                    .frame(width: 80, height: 80)
                
                Image(systemName: "bell")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
            }
            
            Text("アクティビティはありません")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)
            
            Text("投稿が奪われたり、奪取の試みがあった場合にここに表示されます")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 80)
    }
    
    // MARK: - Methods
    
    private func loadNotifications() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            notifications = try await service.fetchNotifications()
        } catch {
            print("Notification error: \(error)")
        }
    }
    
    private func markAsRead(_ notification: AppNotification) async {
        guard !notification.is_read else { return }
        
        do {
            try await service.markNotificationRead(notification.id)
            // ローカルで更新
            if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
                await MainActor.run {
                    // 新しい通知オブジェクトを作成して置き換え
                    var updatedNotifications = notifications
                    let updated = AppNotification(
                        id: notification.id,
                        user_id: notification.user_id,
                        title: notification.title,
                        body: notification.body,
                        type: notification.type,
                        related_message_id: notification.related_message_id,
                        is_read: true,
                        created_at: notification.created_at
                    )
                    updatedNotifications[index] = updated
                    notifications = updatedNotifications
                }
            }
        } catch {
            print("Mark read error: \(error)")
        }
    }
    
    private func markAllAsRead() async {
        do {
            try await service.markAllNotificationsRead()
            await loadNotifications()
        } catch {
            print("Mark all read error: \(error)")
        }
    }
    
    // MARK: - Helpers
    
    private func timeAgo(_ date: Date) -> String {
        let now = Date()
        let components = Calendar.current.dateComponents([.minute, .hour, .day, .weekOfYear], from: date, to: now)
        
        if let weeks = components.weekOfYear, weeks > 0 {
            return "\(weeks)週間前"
        } else if let days = components.day, days > 0 {
            return "\(days)日前"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours)時間前"
        } else if let minutes = components.minute, minutes > 0 {
            return "\(minutes)分前"
        } else {
            return "たった今"
        }
    }
}

#Preview {
    NavigationStack {
        NotificationsView()
            .environmentObject(SessionStore())
    }
}
