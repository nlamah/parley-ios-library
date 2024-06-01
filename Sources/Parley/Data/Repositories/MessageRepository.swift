import Foundation
import UIKit

final class MessageRepository {

    private let messageRemoteService: MessageRemoteService

    init(messageRemoteService: MessageRemoteService) {
        self.messageRemoteService = messageRemoteService
    }

    func find(_ id: Int, onSuccess: @escaping (_ message: Message) -> (), onFailure: @escaping (_ error: Error) -> ()) {
        messageRemoteService.find(id, onSuccess: onSuccess, onFailure: onFailure)
    }

    func findAll(
        onSuccess: @escaping (_ messageCollection: MessageCollection) -> (),
        onFailure: @escaping (_ error: Error) -> ()
    ) {
        messageRemoteService.findAll(onSuccess: onSuccess, onFailure: onFailure)
    }

    func findBefore(
        _ id: Int,
        onSuccess: @escaping (_ messageCollection: MessageCollection) -> (),
        onFailure: @escaping (_ error: Error) -> ()
    ) {
        messageRemoteService.findBefore(id, onSuccess: onSuccess, onFailure: onFailure)
    }

    func findAfter(
        _ id: Int,
        onSuccess: @escaping (_ messageCollection: MessageCollection) -> (),
        onFailure: @escaping (_ error: Error) -> ()
    ) {
        messageRemoteService.findAfter(id, onSuccess: onSuccess, onFailure: onFailure)
    }

    func store(_ message: Message) async throws -> Message {
        try await withCheckedThrowingContinuation { continuation in
            messageRemoteService.store(message) { message in
                continuation.resume(returning: message)
            } onFailure: { error in
                continuation.resume(throwing: error)
            }
        }
    }
}
