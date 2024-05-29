@testable import Parley

final class MessageRepositoryStub: MessageRepositoryProtocol {
    func find(_ id: Int, onSuccess: @escaping (Message) -> (), onFailure: @escaping (Error) -> ()) {
        onSuccess(Message.makeTestData())
    }

    func findAll(onSuccess: @escaping (MessageCollection) -> (), onFailure: @escaping (Error) -> ()) {
    }

    func findBefore(
        _ id: Int,
        onSuccess: @escaping (MessageCollection) -> (),
        onFailure: @escaping (Error) -> ()
    ) {

    }

    func findAfter(
        _ id: Int,
        onSuccess: @escaping (MessageCollection) -> (),
        onFailure: @escaping (Error) -> ()
    ) {

    }

    func store(_ message: Message) async throws -> Message {
        message
    }
}
