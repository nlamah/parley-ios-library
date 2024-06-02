import SnapshotTesting
import XCTest

@testable import Parley

final class ParleyViewTests: XCTestCase {
    private let secondsOfMinute = 60

    private let stickyMessage = """
                Due to high inquiry volumes, our response times may be longer than usual. We appreciate your patience and will get back to you as soon as possible. Thank you for your understanding.
    """

    func testParleyView() {
        let messagesManagerStub = MessagesManagerStub()

        messagesManagerStub.stickyMessage = stickyMessage

        messagesManagerStub.messages = [
            Message.makeTestData(time: Date(timeIntSince1970: 1), type: .date),
            Message.makeTestData(
                id: 1,
                time: Date(timeIntSince1970: 1),
                title: nil,
                message: "This is my question.",
                type: .user,
                agent: nil
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
                message: "Thank you for your **prompt** *reply* ❤️",
                type: .user,
                status: .pending,
                agent: nil
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
                imageLoader: ImageLoaderStub(),
                localizationManager: ParleyLocalizationManager()
            ),
            pollingService: PollingServiceStub(),
            notificationService: NotificationServiceStub()
        )

        applySize(sut: sut)

        assert(sut: sut)
    }

    func testOfflineView() {
        let messagesManagerStub = MessagesManagerStub()

        messagesManagerStub.messages = [
            Message.makeTestData(time: Date(timeIntSince1970: 1), type: .date),
            Message.makeTestData(
                id: 1,
                time: Date(timeIntSince1970: 1),
                title: nil,
                message: "This is my question.",
                type: .user,
                agent: nil
            ),
        ]

        let parleyStub = ParleyStub(
            messagesManager: messagesManagerStub,
            messageRepository: MessageRepositoryStub(),
            imageLoader: ImageLoaderStub(),
            localizationManager: ParleyLocalizationManager()
        )

        parleyStub.reachable = false

        let sut = ParleyView(
            parley: parleyStub,
            pollingService: PollingServiceStub(),
            notificationService: NotificationServiceStub()
        )

        applySize(sut: sut)

        assert(sut: sut)
    }

    func testPushDisabled() {
        let messagesManagerStub = MessagesManagerStub()

        messagesManagerStub.messages = [
            Message.makeTestData(time: Date(timeIntSince1970: 1), type: .date),
            Message.makeTestData(
                id: 1,
                time: Date(timeIntSince1970: 1),
                title: nil,
                message: "This is my question.",
                type: .user,
                agent: nil
            ),
        ]

        let parleyStub = ParleyStub(
            messagesManager: messagesManagerStub,
            messageRepository: MessageRepositoryStub(),
            imageLoader: ImageLoaderStub(),
            localizationManager: ParleyLocalizationManager()
        )

        parleyStub.pushEnabled = false

        let sut = ParleyView(
            parley: parleyStub,
            pollingService: PollingServiceStub(),
            notificationService: NotificationServiceStub()
        )

        applySize(sut: sut)

        assert(sut: sut)
    }

    private func applySize(sut: UIView) {
        sut.translatesAutoresizingMaskIntoConstraints = false
        sut.widthAnchor.constraint(equalToConstant: 320).isActive = true
        sut.heightAnchor.constraint(equalToConstant: 600).isActive = true
    }

    private func assert(
        sut: UIView,
        traits: UITraitCollection = UITraitCollection(),
        file: StaticString = #file,
        testName: String = #function,
        line: UInt = #line
    ) {
        assertSnapshot(matching: sut, as: .image(traits: traits), file: file, testName: testName, line: line)
    }
}
