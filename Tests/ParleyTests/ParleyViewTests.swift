import SnapshotTesting
import XCTest

@testable import Parley

final class ParleyViewTests: XCTestCase {
    private let secondsOfMinute: Int = 60
    func testParleyView() throws {
        let messagesManagerStub = MessagesManagerStub()

        messagesManagerStub.messages = [
            Message.makeTestData(
                id: 1,
                time: Date(timeIntSince1970: 1),
                title: nil,
                message: "This is my question.",
                type: .user
            ),
            Message.makeTestData(
                id: 2,
                time: Date(timeIntSince1970: 1 * secondsOfMinute),
                title: nil,
                message: "We will look into that!",
                type: .agent
            ),
            Message.makeTestData(
                id: 3,
                time: Date(timeIntSince1970: 2 * secondsOfMinute),
                title: nil,
                message: "Thank you for your prompt reply ❤️",
                type: .user
            ),
            Message.makeTestData(
                id: 3,
                time: Date(timeIntSince1970: 3 * secondsOfMinute),
                title: nil,
                message: "Thank you for your prompt reply",
                type: .agentTyping
            ),
        ]

        let sut = ParleyView(
            parley: ParleyStub(
                messagesManager: messagesManagerStub,
                messageRepository: MessageRepositoryStub(),
                imageLoader: ImageLoaderStub()
            ),
            pollingService: PollingServiceStub(),
            notificationService: NotificationServiceStub()
        )

        sut.translatesAutoresizingMaskIntoConstraints = false
        sut.widthAnchor.constraint(equalToConstant: 320).isActive = true
        sut.heightAnchor.constraint(equalToConstant: 600).isActive = true

        assertSnapshot(matching: sut, as: .image)
        assertSnapshot(
            matching: sut,
            as: .image(traits: UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge))
        )
    }
}
