import SwiftUI


// ---------------------------------------------------------------------------
// MARK: - ConversationItem
// ---------------------------------------------------------------------------

struct ConversationItem: Identifiable, Sendable {
    let id: UUID
    let title: String
    let createdAt: Date
    let updatedAt: Date
    let messageCount: Int
}


// ---------------------------------------------------------------------------
// MARK: - ConversationListView
// ---------------------------------------------------------------------------

struct ConversationListView: View {

    @ObservedObject var chatViewModel: ChatViewModel
    @Environment(\.dismiss) var dismiss

    private let bg   = Color(red: 0.05, green: 0.05, blue: 0.05)
    private let card = Color(red: 0.11, green: 0.11, blue: 0.11)
    private let red  = Color(red: 0.88, green: 0.1, blue: 0.1)

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Conversations")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color(white: 0.55))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                // New Chat button
                Button {
                    Task {
                        await chatViewModel.createConversation()
                        dismiss()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                        Text("New Chat")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(red)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

                // Conversation list
                if chatViewModel.conversations.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 40))
                            .foregroundStyle(Color(white: 0.4))
                        Text("No conversations yet")
                            .font(.system(size: 16))
                            .foregroundStyle(Color(white: 0.5))
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    List {
                        ForEach(chatViewModel.conversations) { conversation in
                            conversationRow(conversation)
                                .listRowBackground(bg)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                                .onTapGesture {
                                    Task {
                                        await chatViewModel.switchConversation(id: conversation.id)
                                        dismiss()
                                    }
                                }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let conversation = chatViewModel.conversations[index]
                                Task {
                                    await chatViewModel.deleteConversation(id: conversation.id)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(bg)
                }
            }
        }
        .task {
            await chatViewModel.loadConversations()
        }
    }

    // MARK: - Row

    private func conversationRow(_ conversation: ConversationItem) -> some View {
        let isActive = chatViewModel.activeConversationId == conversation.id

        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(conversation.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(dateFormatter.string(from: conversation.createdAt))
                    .font(.system(size: 12))
                    .foregroundColor(Color(white: 0.55))
            }

            Spacer(minLength: 8)

            // Message count badge
            Text("\(conversation.messageCount)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(white: 0.55))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(white: 0.2))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(card)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            isActive ? red : Color.clear,
                            lineWidth: 1.5
                        )
                )
        )
        .contentShape(Rectangle())
    }
}


// ---------------------------------------------------------------------------
// MARK: - Preview
// ---------------------------------------------------------------------------

#Preview {
    ConversationListView(chatViewModel: ChatViewModel())
}
