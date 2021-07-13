//
//  Publishers.Concatenate.swift
//  
//
//  Created by Sergej Jaskiewicz on 24.10.2019.
//

extension Publisher {

    /// Prefixes a publisher’s output with the specified values.
    ///
    /// Use `prepend(_:)` when you need to prepend specific elements before the output
    /// of a publisher.
    ///
    /// In the example below, the `prepend(_:)` operator publishes the provided elements
    /// before republishing all elements from `dataElements`:
    ///
    ///     let dataElements = (0...10)
    ///     cancellable = dataElements.publisher
    ///         .prepend(0, 1, 255)
    ///         .sink { print("\($0)", terminator: " ") }
    ///
    ///     // Prints: "0 1 255 0 1 2 3 4 5 6 7 8 9 10"
    ///
    /// - Parameter elements: The elements to publish before this publisher’s elements.
    /// - Returns: A publisher that prefixes the specified elements prior to this
    ///   publisher’s elements.
    public func prepend(
        _ elements: Output...
    ) -> Publishers.Concatenate<Publishers.Sequence<[Output], Failure>, Self> {
        return prepend(elements)
    }

    /// Prefixes a publisher’s output with the specified sequence.
    ///
    /// Use `prepend(_:)` to publish values from two publishers when you need to prepend
    /// one publisher’s elements to another.
    ///
    /// In this example the `/prepend(_:)-v9sb` operator publishes the provided sequence
    /// before republishing all elements from `dataElements`:
    ///
    ///     let prefixValues = [0, 1, 255]
    ///     let dataElements = (0...10)
    ///     cancellable = dataElements.publisher
    ///         .prepend(prefixValues)
    ///         .sink { print("\($0)", terminator: " ") }
    ///
    ///     // Prints: "0 1 255 0 1 2 3 4 5 6 7 8 9 10"
    ///
    /// - Parameter elements: A sequence of elements to publish before this publisher’s
    ///   elements.
    /// - Returns: A publisher that prefixes the sequence of elements prior to this
    ///   publisher’s elements.
    public func prepend<Elements: Sequence>(
        _ elements: Elements
    ) -> Publishers.Concatenate<Publishers.Sequence<Elements, Failure>, Self>
        where Output == Elements.Element
    {
        return prepend(.init(sequence: elements))
    }

    /// Prefixes the output of this publisher with the elements emitted by the given
    /// publisher.
    ///
    /// Use `prepend(_:)` to publish values from two publishers when you need to prepend
    /// one publisher’s elements to another.
    ///
    /// In the example below, a publisher of `prefixValues` publishes its elements before
    /// the `dataElements` publishes its elements:
    ///
    ///     let prefixValues = [0, 1, 255]
    ///     let dataElements = (0...10)
    ///     cancellable = dataElements.publisher
    ///         .prepend(prefixValues.publisher)
    ///         .sink { print("\($0)", terminator: " ") }
    ///
    ///     // Prints: "0 1 255 0 1 2 3 4 5 6 7 8 9 10"
    ///
    /// - Parameter publisher: The prefixing publisher.
    /// - Returns: A publisher that prefixes the prefixing publisher’s elements prior to
    ///   this publisher’s elements.
    public func prepend<Prefix: Publisher>(
        _ publisher: Prefix
    ) -> Publishers.Concatenate<Prefix, Self>
        where Failure == Prefix.Failure, Output == Prefix.Output
    {
        return .init(prefix: publisher, suffix: self)
    }

    /// Appends a publisher’s output with the specified elements.
    ///
    /// Use `append(_:)` when you need to prepend specific elements after the output of
    /// a publisher.
    ///
    /// In the example below, the `append(_:)` operator publishes the provided elements
    /// after republishing all elements from `dataElements`:
    ///
    ///     let dataElements = (0...10)
    ///     cancellable = dataElements.publisher
    ///         .append(0, 1, 255)
    ///         .sink { print("\($0)", terminator: " ") }
    ///
    ///     // Prints: "0 1 2 3 4 5 6 7 8 9 10 0 1 255"
    ///
    ///
    /// - Parameter elements: Elements to publish after this publisher’s elements.
    /// - Returns: A publisher that appends the specifiecd elements after this publisher’s
    ///   elements.
    public func append(
        _ elements: Output...
    ) -> Publishers.Concatenate<Self, Publishers.Sequence<[Output], Failure>> {
        return append(elements)
    }

    /// Appends a publisher’s output with the specified sequence.
    ///
    /// Use `append(_:)` to append a sequence to the end of
    /// a publisher’s output.
    ///
    /// In the example below, the `append(_:)` publisher republishes all elements from
    /// `groundTransport` until it finishes, then publishes the members of `airTransport`:
    ///
    ///     let groundTransport = ["car", "bus", "truck", "subway", "bicycle"]
    ///     let airTransport = ["parasail", "jet", "helicopter", "rocket"]
    ///     cancellable = groundTransport.publisher
    ///         .append(airTransport)
    ///         .sink { print("\($0)", terminator: " ") }
    ///
    ///     // Prints: "car bus truck subway bicycle parasail jet helicopter rocket"
    ///
    /// - Parameter elements: A sequence of elements to publish after this publisher’s
    ///   elements.
    /// - Returns: A publisher that appends the sequence of elements after this
    ///   publisher’s elements.
    public func append<Elements: Sequence>(
        _ elements: Elements
    ) -> Publishers.Concatenate<Self, Publishers.Sequence<Elements, Failure>>
        where Output == Elements.Element
    {
        return append(.init(sequence: elements))
    }

    /// Appends the output of this publisher with the elements emitted by the given
    /// publisher.
    ///
    /// Use `append(_:)` to append the output of one publisher to another.
    /// The `append(_:)` operator produces no elements until this publisher finishes.
    /// It then produces this publisher’s elements, followed by the given publisher’s
    /// elements. If this publisher fails with an error, the given publishers elements
    /// aren’t published.
    ///
    /// In the example below, the `append` publisher republishes all elements from
    /// the `numbers` publisher until it finishes, then publishes all elements from
    /// the `otherNumbers` publisher:
    ///
    ///     let numbers = (0...10)
    ///     let otherNumbers = (25...35)
    ///     cancellable = numbers.publisher
    ///         .append(otherNumbers.publisher)
    ///         .sink { print("\($0)", terminator: " ") }
    ///
    ///     // Prints: "0 1 2 3 4 5 6 7 8 9 10 25 26 27 28 29 30 31 32 33 34 35 "
    ///
    /// - Parameter publisher: The appending publisher.
    /// - Returns: A publisher that appends the appending publisher’s elements after this
    ///   publisher’s elements.
    public func append<Suffix: Publisher>(
        _ publisher: Suffix
    ) -> Publishers.Concatenate<Self, Suffix>
        where Suffix.Failure == Failure, Suffix.Output == Output
    {
        return .init(prefix: self, suffix: publisher)
    }
}

extension Publishers {

    /// A publisher that emits all of one publisher’s elements before those from another
    /// publisher.
    public struct Concatenate<Prefix: Publisher, Suffix: Publisher>: Publisher
        where Prefix.Failure == Suffix.Failure, Prefix.Output == Suffix.Output
    {
        public typealias Output = Suffix.Output

        public typealias Failure = Suffix.Failure

        /// The publisher to republish, in its entirety, before republishing elements from
        /// `suffix`.
        public let prefix: Prefix

        /// The publisher to republish only after `prefix` finishes.
        public let suffix: Suffix

        public init(prefix: Prefix, suffix: Suffix) {
            self.prefix = prefix
            self.suffix = suffix
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Suffix.Failure == Downstream.Failure, Suffix.Output == Downstream.Input
        {
            let inner = Inner(downstream: subscriber, suffix: suffix)
            prefix.subscribe(Inner<Downstream>.PrefixSubscriber(inner: inner))
        }
    }
}

extension Publishers.Concatenate: Equatable where Prefix: Equatable, Suffix: Equatable {}

extension Publishers.Concatenate {
    fileprivate final class Inner<Downstream: Subscriber>
        : Subscription,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Downstream.Input == Suffix.Output, Downstream.Failure == Suffix.Failure
    {
        typealias Input = Suffix.Output

        typealias Failure = Suffix.Failure

        fileprivate struct PrefixSubscriber {
            let inner: Inner<Downstream>
        }

        fileprivate struct SuffixSubscriber {
            let inner: Inner<Downstream>
        }

        private let downstream: Downstream

        private var prefixState = SubscriptionStatus.awaitingSubscription

        private var suffixState = SubscriptionStatus.awaitingSubscription

        private var suffix: Suffix?

        private var pending = Subscribers.Demand.none

        private let lock = UnfairLock.allocate()

        fileprivate init(downstream: Downstream, suffix: Suffix) {
            self.downstream = downstream
            self.suffix = suffix
        }

        deinit {
            lock.deallocate()
        }

        func request(_ demand: Subscribers.Demand) {
            lock.lock()
            pending += demand
            guard let subscription = prefixState.subscription ?? suffixState.subscription
            else {
                lock.unlock()
                return
            }
            lock.unlock()
            subscription.request(demand)
        }

        func cancel() {
            lock.lock()
            let upstreamSubscription =
                prefixState.subscription ?? suffixState.subscription
            prefixState = .terminal
            suffixState = .terminal

            // We MUST release the object AFTER unlocking the lock,
            // since releasing it may trigger execution of arbitrary code,
            // for example, if the object has a deinit.
            // When the object deallocates, its deinit is called, and holding
            // the lock at that moment can lead to deadlocks.

            withExtendedLifetime(suffix) {
                suffix = nil
                lock.unlock()
                upstreamSubscription?.cancel()
            }
        }

        var description: String { return "Concatenate" }

        var customMirror: Mirror {
            return Mirror(self, children: EmptyCollection())
        }

        var playgroundDescription: Any { return description }

        // MARK: - Private

        private func prefixReceive(subscription: Subscription) {
            lock.lock()
            guard case .awaitingSubscription = prefixState else {
                lock.unlock()
                subscription.cancel()
                return
            }
            prefixState = .subscribed(subscription)
            lock.unlock()
            downstream.receive(subscription: self)
        }

        private func prefixReceive(_ input: Input) -> Subscribers.Demand {
            lock.lock()
            guard case .subscribed = prefixState, pending != .none else {
                lock.unlock()
                return .none
            }
            pending -= 1
            lock.unlock()
            let newDemand = downstream.receive(input)
            if newDemand == .none {
                return .none
            }
            lock.lock()
            pending += newDemand
            lock.unlock()
            return newDemand
        }

        private func prefixReceive(completion: Subscribers.Completion<Failure>) {
            lock.lock()
            guard case .subscribed = prefixState else {
                lock.unlock()
                return
            }
            prefixState = .terminal
            lock.unlock()
            switch completion {
            case .finished:
                suffix?.subscribe(SuffixSubscriber(inner: self))
            case .failure:
                downstream.receive(completion: completion)
            }
        }

        private func suffixReceive(subscription: Subscription) {
            lock.lock()
            guard case .awaitingSubscription = suffixState else {
                lock.unlock()
                subscription.cancel()
                return
            }
            suffixState = .subscribed(subscription)
            let pending = self.pending
            lock.unlock()
            if pending != .none {
                subscription.request(pending)
            }
        }

        private func suffixReceive(_ input: Input) -> Subscribers.Demand {
            lock.lock()
            guard case .subscribed = suffixState else {
                lock.unlock()
                return .none
            }
            lock.unlock()
            return downstream.receive(input)
        }

        private func suffixReceive(completion: Subscribers.Completion<Failure>) {
            lock.lock()
            guard case .subscribed = suffixState else {
                lock.unlock()
                return
            }
            prefixState = .terminal
            suffixState = .terminal
            lock.unlock()
            downstream.receive(completion: completion)
        }
    }
}

// MARK: - PrefixSubscriber conformances

extension Publishers.Concatenate.Inner.PrefixSubscriber: Subscriber {

    fileprivate typealias Input = Suffix.Output

    fileprivate typealias Failure = Suffix.Failure

    fileprivate var combineIdentifier: CombineIdentifier {
        return inner.combineIdentifier
    }

    fileprivate func receive(subscription: Subscription) {
        inner.prefixReceive(subscription: subscription)
    }

    fileprivate func receive(_ input: Input) -> Subscribers.Demand {
        return inner.prefixReceive(input)
    }

    fileprivate func receive(completion: Subscribers.Completion<Failure>) {
        inner.prefixReceive(completion: completion)
    }
}

extension Publishers.Concatenate.Inner.PrefixSubscriber
    : CustomStringConvertible
{
    fileprivate var description: String {
        return inner.description
    }
}

extension Publishers.Concatenate.Inner.PrefixSubscriber
    : CustomReflectable
{
    fileprivate var customMirror: Mirror {
        return inner.customMirror
    }
}

extension Publishers.Concatenate.Inner.PrefixSubscriber
    : CustomPlaygroundDisplayConvertible
{
    fileprivate var playgroundDescription: Any {
        return inner.playgroundDescription
    }
}

// MARK: - SuffixSubscriber conformances

extension Publishers.Concatenate.Inner.SuffixSubscriber: Subscriber {

    fileprivate typealias Input = Suffix.Output

    fileprivate typealias Failure = Suffix.Failure

    fileprivate var combineIdentifier: CombineIdentifier {
        return inner.combineIdentifier
    }

    fileprivate func receive(subscription: Subscription) {
        inner.suffixReceive(subscription: subscription)
    }

    fileprivate func receive(_ input: Input) -> Subscribers.Demand {
        return inner.suffixReceive(input)
    }

    fileprivate func receive(completion: Subscribers.Completion<Failure>) {
        inner.suffixReceive(completion: completion)
    }
}

extension Publishers.Concatenate.Inner.SuffixSubscriber
    : CustomStringConvertible
{
    fileprivate var description: String {
        return inner.description
    }
}

extension Publishers.Concatenate.Inner.SuffixSubscriber
    : CustomReflectable
{
    fileprivate var customMirror: Mirror {
        return inner.customMirror
    }
}

extension Publishers.Concatenate.Inner.SuffixSubscriber
    : CustomPlaygroundDisplayConvertible
{
    fileprivate var playgroundDescription: Any {
        return inner.playgroundDescription
    }
}
