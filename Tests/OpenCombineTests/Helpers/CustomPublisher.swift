//
//  CustomPublisher.swift
//  
//
//  Created by Sergej Jaskiewicz on 16.06.2019.
//

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

/// `CustomPublisher` sends the `subscription` object it has been initialized with
/// to whoever subscribed to this publisher.
///
/// This is useful in conjunction with the `CustomSubscription` class, which allows you
/// to track the demand requested by the subscribers of this publisher.
///
/// Example:
///
///     let subscription = CustomSubscription()
///     let publisher = CustomPublisher(subscription: subscription)
///
///     let subscriber = AnySubscriber(receiveSubscription: {
///         $0.request(42)
///         $0.cancel()
///     })
///
///     publisher.subscribe(subscriber)
///
///     assert(subscription.history == [.requested(.max(42)), .cancelled])
typealias CustomPublisher = CustomPublisherBase<Int, TestingError>

class CustomPublisherBase<Output, Failure: Error>: Publisher, Cancellable {

    private(set) var subscriber: AnySubscriber<Output, Failure>?
    private(set) var erasedSubscriber: Any?
    private let subscription: Subscription?

    var willSubscribe: ((AnySubscriber<Output, Failure>, Any) -> Void)?

    var didSubscribe: ((AnySubscriber<Output, Failure>, Any) -> Void)?

    var onDeinit: (() -> Void)?

    required init(subscription: Subscription?) {
        self.subscription = subscription
    }

    deinit {
        onDeinit?()
    }

    func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Failure == Downstream.Failure, Output == Downstream.Input
    {
        let anySubscriber = AnySubscriber(subscriber)
        self.subscriber = anySubscriber
        willSubscribe?(anySubscriber, subscriber)
        erasedSubscriber = subscriber
        subscription.map(subscriber.receive(subscription:))
        didSubscribe?(anySubscriber, subscriber)
    }

    func send(subscription: CustomSubscription) {
        subscriber!.receive(subscription: subscription)
    }

    func send(_ value: Output) -> Subscribers.Demand {
        return subscriber?.receive(value) ?? .none
    }

    func send(completion: Subscribers.Completion<Failure>) {
        subscriber?.receive(completion: completion)
    }

    func cancel() {
        subscriber = nil
        erasedSubscriber = nil
    }
}

extension CustomPublisherBase: Equatable {
    static func == (lhs: CustomPublisherBase<Output, Failure>,
                    rhs: CustomPublisherBase<Output, Failure>) -> Bool {
        return lhs === rhs
    }
}

typealias CustomConnectablePublisher = CustomConnectablePublisherBase<Int, TestingError>

final class CustomConnectablePublisherBase<Output, Failure: Error>
    : CustomPublisherBase<Output, Failure>,
      ConnectablePublisher
{

    enum Event: CustomStringConvertible {
        case connected, disconnected

        var description: String {
            switch self {
            case .connected:
                return ".connected"
            case .disconnected:
                return ".disconnected"
            }
        }
    }

    struct Connection: Cancellable {

        let onCancel: () -> Void

        func cancel() {
            onCancel()
        }
    }

    private(set) var connectionHistory: [Event] = []

    func connect() -> Cancellable {
        connectionHistory.append(.connected)
        return Connection { self.connectionHistory.append(.disconnected) }
    }
}
