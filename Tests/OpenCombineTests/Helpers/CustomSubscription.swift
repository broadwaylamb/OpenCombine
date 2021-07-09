//
//  CustomSubscription.swift
//  
//
//  Created by Sergej Jaskiewicz on 16.06.2019.
//

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

/// `CustomSubscription` tracks all the requests and cancellations
/// in its `history` property.
///
/// In order to inject `CustomSubscription` into the chain of subscriptions,
/// use the `CustomSubscriber` class.
final class CustomSubscription: Subscription, CustomStringConvertible {

    enum Event: Equatable, CustomStringConvertible {
        case requested(Subscribers.Demand)
        case cancelled

        var description: String {
            switch self {
            case .requested(let demand):
                return ".requested(.\(demand))"
            case .cancelled:
                return ".cancelled"
            }
        }
    }

    /// The history of requests and cancellations of this subscription.
    private(set) var history: [Event] = []

    var onRequest: ((Subscribers.Demand) -> Void)?
    var onCancel: (() -> Void)?
    var onDeinit: (() -> Void)?

    init(onRequest: ((Subscribers.Demand) -> Void)? = nil,
         onCancel: (() -> Void)? = nil,
         onDeinit: (() -> Void)? = nil) {
        self.onRequest = onRequest
        self.onCancel = onCancel
        self.onDeinit = onDeinit
    }

    deinit {
        onDeinit?()
    }

    var lastRequested: Subscribers.Demand? {
        return history.lazy.compactMap {
            switch $0 {
            case .requested(let demand):
                return demand
            case .cancelled:
                return nil
            }
        }.last
    }

    var cancelled = false

    func request(_ demand: Subscribers.Demand) {
        history.append(.requested(demand))
        onRequest?(demand)
    }

    func cancel() {
        history.append(.cancelled)
        cancelled = true
        onCancel?()
    }

    var description: String { return "CustomSubscription" }
}

extension CustomSubscription: Equatable {
    static func == (lhs: CustomSubscription, rhs: CustomSubscription) -> Bool {
        return lhs === rhs
    }
}
