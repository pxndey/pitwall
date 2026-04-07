import SwiftUI

struct HomeView: View {

    @StateObject private var chatViewModel = ChatViewModel()
    @State private var inputText: String = ""

    // MARK: - Colors

    private let bgTop     = Color(red: 0.05, green: 0.05, blue: 0.05)
    private let bgBottom  = Color(red: 0.15, green: 0.0,  blue: 0.0)
    private let redAccent = Color(red: 0.88, green: 0.1,  blue: 0.1)
    private let bubbleDark = Color(red: 0.12, green: 0.12, blue: 0.12)
    private let barBg     = Color(red: 0.1,  green: 0.1,  blue: 0.1)

    // MARK: - Body

    var body: some View {
        ZStack {
            // Full-screen gradient background
            LinearGradient(
                colors: [bgTop, bgBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                navHeader
                messagesArea
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .safeAreaInset(edge: .bottom) {
            inputBar
        }
    }

    // MARK: - Nav Header

    private var navHeader: some View {
        ZStack {
            HStack {
                Image(systemName: "rocket.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(redAccent)
                    .padding(.leading, 20)
                Spacer()
            }

            Text("PITWALL")
                .font(.system(size: 20, weight: .black, design: .default))
                .tracking(4)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, topSafeAreaPadding)
        .padding(.bottom, 12)
        .background(bgTop.opacity(0.95))
    }

    // MARK: - Messages Area

    private var messagesArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    if chatViewModel.messages.isEmpty && !chatViewModel.isLoading {
                        emptyState
                    } else {
                        ForEach(chatViewModel.messages) { message in
                            messageBubble(message)
                                .id(message.id)
                        }
                        if chatViewModel.isLoading {
                            thinkingBubble
                                .id("thinking")
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .task {
                await chatViewModel.loadHistory()
            }
            .onChange(of: chatViewModel.messages.count) {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: chatViewModel.isLoading) {
                if chatViewModel.isLoading {
                    withAnimation {
                        proxy.scrollTo("thinking", anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Bubble Views

    @ViewBuilder
    private func messageBubble(_ message: ChatViewModel.Message) -> some View {
        let isUser = message.role == "user"

        HStack {
            if isUser { Spacer(minLength: 60) }

            Text(message.content)
                .font(.body)
                .foregroundColor(.white)
                .padding(12)
                .background(
                    isUser ? redAccent : bubbleDark
                )
                .clipShape(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: isUser ? .trailing : .leading)

            if !isUser { Spacer(minLength: 60) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    private var thinkingBubble: some View {
        HStack {
            HStack(spacing: 6) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.8)
                Text("thinking...")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(12)
            .background(bubbleDark)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Spacer(minLength: 60)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        Text("Ask me anything about the race.")
            .font(.body)
            .foregroundColor(.gray)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, 80)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.white.opacity(0.1))

            HStack(alignment: .bottom, spacing: 10) {
                TextField("Message Pitwall...", text: $inputText, axis: .vertical)
                    .lineLimit(1...4)
                    .font(.body)
                    .foregroundColor(.white)
                    .tint(redAccent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(red: 0.18, green: 0.18, blue: 0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                Button {
                    let text = inputText
                    inputText = ""
                    Task {
                        await chatViewModel.send(text: text)
                    }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isSendDisabled ? .gray : redAccent)
                        .padding(10)
                }
                .disabled(isSendDisabled)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .padding(.bottom, bottomSafeAreaPadding)
        }
        .background(barBg)
    }

    // MARK: - Helpers

    private var isSendDisabled: Bool {
        inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || chatViewModel.isLoading
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let last = chatViewModel.messages.last {
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    private var topSafeAreaPadding: CGFloat {
        (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows
            .first?.safeAreaInsets.top ?? 0)
    }

    private var bottomSafeAreaPadding: CGFloat {
        (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows
            .first?.safeAreaInsets.bottom ?? 0)
    }
}

// MARK: - Preview

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
}
