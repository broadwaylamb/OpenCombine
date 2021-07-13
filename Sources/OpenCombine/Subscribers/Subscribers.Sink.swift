//
//  Subscribers.Sink.swift
//  
//
//  Created by Sergej Jaskiewicz on 16.06.2019.
//

extension Subscribers {

    /// A simple subscriber that requests an unlimited number of values upon subscription.
    public final class Sink<Input, Failure: Error>
        : Subscriber,
          Cancellable,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
    {

        /// The closure to execute on receipt of a value.
        public var receiveValue: (Input) -> Void

        /// The closure to execute on completion.
        public var receiveCompletion: (Subscribers.Completion<Failure>) -> Void

        private var status = SubscriptionStatus.awaitingSubscription

        private let lock = UnfairLock.allocate()

        public var description: String { return "Sink" }

        public var customMirror: Mirror {
            return Mirror(self, children: EmptyCollection())
        }

        public var playgroundDescription: Any { return description }

        /// Initializes a sink with the provided closures.
        ///
        /// - Parameters:
        ///   - receiveCompletion: The closure to execute on completion.
        ///   - receiveValue: The closure to execute on receipt of a value.
        public init(
            receiveCompletion: @escaping (Subscribers.Completion<Failure>) -> Void,
            receiveValue: @escaping ((Input) -> Void)
        ) {
            self.receiveCompletion = receiveCompletion
            self.receiveValue = receiveValue
        }

        deinit {
            lock.deallocate()
        }

        public func receive(subscription: Subscription) {
            lock.lock()
            guard case .awaitingSubscription = status else {
                lock.unlock()
                subscription.cancel()
                return
            }
            status = .subscribed(subscription)
            lock.unlock()
            subscription.request(.unlimited)
        }

        public func receive(_ value: Input) -> Subscribers.Demand {
            lock.lock()
            let receiveValue = self.receiveValue
            lock.unlock()
            receiveValue(value)
            return .none
        }

        public func receive(completion: Subscribers.Completion<Failure>) {
            lock.lock()
            status = .terminal
            let receiveCompletion = self.receiveCompletion
            self.receiveCompletion = { _ in }

            // We MUST release the closures AFTER unlocking the lock,
            // since releasing a closure may trigger execution of arbitrary code,
            // for example, if the closure captures an object with a deinit.
            // When closure deallocates, the object's deinit is called, and holding
            // the lock at that moment can lead to deadlocks.
            // See https://github.com/OpenCombine/OpenCombine/issues/208

            withExtendedLifetime(receiveValue) {
                receiveValue = { _ in }
                lock.unlock()
            }

            receiveCompletion(completion)
        }

        public func cancel() {
            lock.lock()
            guard case let .subscribed(subscription) = status else {
                lock.unlock()
                return
            }
            status = .terminal

            // We MUST release the closures AFTER unlocking the lock,
            // since releasing a closure may trigger execution of arbitrary code,
            // for example, if the closure captures an object with a deinit.
            // When closure deallocates, the object's deinit is called, and holding
            // the lock at that moment can lead to deadlocks.
            // See https://github.com/OpenCombine/OpenCombine/issues/208

            withExtendedLifetime((receiveValue, receiveCompletion)) {
                receiveCompletion = { _ in }
                receiveValue = { _ in }
                lock.unlock()
            }
            subscription.cancel()
        }
    }
}

extension Publisher {

    /// Attaches a subscriber with closure-based behavior.
    ///
    /// Use `sink(receiveCompletion:receiveValue:)` to observe values received by
    /// the publisher and process them using a closure you specify.
    ///
    /// In this example, a `Range` publisher publishes integers to
    /// a `sink(receiveCompletion:receiveValue:)` operator’s `receiveValue` closure that
    /// prints them to the console. Upon completion
    /// the `sink(receiveCompletion:receiveValue:)` operator’s `receiveCompletion` closure
    /// indicates the successful termination of the stream.
    ///
    ///     let myRange = (0...3)
    ///     cancellable = myRange.publisher
    ///         .sink(receiveCompletion: { print ("completion: \($0)") },
    ///               receiveValue: { print ("value: \($0)") })
    ///
    ///     // Prints:
    ///     //  value: 0
    ///     //  value: 1
    ///     //  value: 2
    ///     //  value: 3
    ///     //  completion: finished
    ///
    /// This method creates the subscriber and immediately requests an unlimited number
    /// of values, prior to returning the subscriber.
    /// The return value should be held, otherwise the stream will be canceled.
    ///
    /// - parameter receiveComplete: The closure to execute on completion.
    /// - parameter receiveValue: The closure to execute on receipt of a value.
    /// - Returns: A cancellable instance, which you use when you end assignment of
    ///   the received value. Deallocation of the result will tear down the subscription
    ///   stream.
    public func sink(
        receiveCompletion: @escaping (Subscribers.Completion<Failure>) -> Void,
        receiveValue: @escaping ((Output) -> Void)
    ) -> AnyCancellable {
        let subscriber = Subscribers.Sink<Output, Failure>(
            receiveCompletion: receiveCompletion,
            receiveValue: receiveValue
        )
        subscribe(subscriber)
        return AnyCancellable(subscriber)
    }
}

extension Publisher where Failure == Never {

    /// Attaches a subscriber with closure-based behavior to a publisher that never fails.
    ///
    /// Use `sink(receiveValue:)` to observe values received by the publisher and print
    /// them to the console. This operator can only be used when the stream doesn’t fail,
    /// that is, when the publisher’s `Failure` type is `Never`.
    ///
    /// In this example, a `Range` publisher publishes integers to a `sink(receiveValue:)`
    /// operator’s `receiveValue` closure that prints them to the console:
    ///
    ///     let integers = (0...3)
    ///     integers.publisher
    ///         .sink { print("Received \($0)") }
    ///
    ///     // Prints:
    ///     //  Received 0
    ///     //  Received 1
    ///     //  Received 2
    ///     //  Received 3
    ///
    /// This method creates the subscriber and immediately requests an unlimited number of
    /// values, prior to returning the subscriber.
    /// The return value should be held, otherwise the stream will be canceled.
    ///
    /// - parameter receiveValue: The closure to execute on receipt of a value.
    /// - Returns: A cancellable instance, which you use when you end assignment of
    ///   the received value. Deallocation of the result will tear down the subscription
    ///   stream.
    public func sink(
        receiveValue: @escaping (Output) -> Void
    ) -> AnyCancellable {
        let subscriber = Subscribers.Sink<Output, Failure>(
            receiveCompletion: { _ in },
            receiveValue: receiveValue
        )
        subscribe(subscriber)
        return AnyCancellable(subscriber)
    }
}
