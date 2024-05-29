@testable import Parley

final class ParleyStub: ParleyProtocol {
    init(
        messagesManager: MessagesManagerProtocol,
        messageRepository: MessageRepositoryProtocol,
        imageLoader: ImageLoaderProtocol
    ) {
        self.messagesManager = messagesManager
        self.messageRepository = messageRepository
        self.imageLoader = imageLoader
    }

    var state: Parley.State = .configured
    var reachable = true
    var alwaysPolling = false
    var pushEnabled = true

    var messagesManager: MessagesManagerProtocol!
    var messageRepository: MessageRepositoryProtocol!
    var imageLoader: ImageLoaderProtocol!

    var delegate: ParleyDelegate?

    func isCachingEnabled() -> Bool {
        true
    }

    func send(_ message: Message, isNewMessage: Bool) async {}
    func send(_ text: String, silent: Bool) {}
    func userStartTyping() {}
    func loadMoreMessages(_ lastMessageId: Int) {}
    func sendNewMessageWithMedia(_ media: MediaModel) async {}
}
