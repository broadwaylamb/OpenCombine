//
//  Publishers.Throttle.swift
//  
//
//  Created by Stuart Austin on 14/11/2020.
//

extension Publisher {

    /// Publishes either the most-recent or first element published by the upstream
    /// publisher in the specified time interval.
    ///
    /// Use `throttle(for:scheduler:latest:)` to selectively republish elements from
    /// an upstream publisher during an interval you specify. Other elements received from
    /// the upstream in the throttling interval aren’t republished.
    ///
    /// In the example below, a `Timer.TimerPublisher` produces elements on 3-second
    /// intervals; the `throttle(for:scheduler:latest:)` operator delivers the first
    /// event, then republishes only the latest event in the following ten second
    /// intervals:
    ///
    ///     cancellable = Timer.publish(every: 3.0, on: .main, in: .default)
    ///         .autoconnect()
    ///         .print("\(Date().description)")
    ///         .throttle(for: 10.0, scheduler: RunLoop.main, latest: true)
    ///         .sink(
    ///             receiveCompletion: { print ("Completion: \($0).") },
    ///             receiveValue: { print("Received Timestamp \($0).") }
    ///          )
    ///
    ///     // Prints:
    ///     //    Publish at: 2020-03-19 18:26:54 +0000: receive value: (2020-03-19 18:26:57 +0000)
    ///     //    Received Timestamp 2020-03-19 18:26:57 +0000.
    ///     //    Publish at: 2020-03-19 18:26:54 +0000: receive value: (2020-03-19 18:27:00 +0000)
    ///     //    Publish at: 2020-03-19 18:26:54 +0000: receive value: (2020-03-19 18:27:03 +0000)
    ///     //    Publish at: 2020-03-19 18:26:54 +0000: receive value: (2020-03-19 18:27:06 +0000)
    ///     //    Publish at: 2020-03-19 18:26:54 +0000: receive value: (2020-03-19 18:27:09 +0000)
    ///     //    Received Timestamp 2020-03-19 18:27:09 +0000.
    ///
    /// - Parameters:
    ///   - interval: The interval at which to find and emit either the most recent or
    ///     the first element, expressed in the time system of the scheduler.
    ///   - scheduler: The scheduler on which to publish elements.
    ///   - latest: A Boolean value that indicates whether to publish the most recent
    ///     element. If `false`, the publisher emits the first element received during
    ///     the interval.
    /// - Returns: A publisher that emits either the most-recent or first element received
    ///   during the specified interval.
    public func throttle<Context: Scheduler>(
        for interval: Context.SchedulerTimeType.Stride,
        scheduler: Context,
        latest: Bool
    ) -> Publishers.Throttle<Self, Context> {
        return .init(upstream: self,
                     interval: interval,
                     scheduler: scheduler,
                     latest: latest)
    }
}

extension Publishers {

    /// A publisher that publishes either the most-recent or first element published by
    /// the upstream publisher in a specified time interval.
    public struct Throttle<Upstream: Publisher, Context: Scheduler>: Publisher {

        public typealias Output = Upstream.Output

        public typealias Failure = Upstream.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// The interval in which to find and emit the most recent element.
        public let interval: Context.SchedulerTimeType.Stride

        /// The scheduler on which to publish elements.
        public let scheduler: Context

        /// A Boolean value indicating whether to publish the most recent element.
        ///
        /// If `false`, the publisher emits the first element received during
        /// the interval.
        public let latest: Bool

        public init(upstream: Upstream,
                    interval: Context.SchedulerTimeType.Stride,
                    scheduler: Context,
                    latest: Bool) {
            self.upstream = upstream
            self.interval = interval
            self.scheduler = scheduler
            self.latest = latest
        }

        /// Attaches the specified subscriber to this publisher.
        ///
        /// Implementations of ``Publisher`` must implement this method.
        ///
        /// The provided implementation of ``Publisher/subscribe(_:)-4u8kn``calls
        /// this method.
        ///
        /// - Parameter subscriber: The subscriber to attach to this ``Publisher``,
        ///     after which it can receive values.
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Downstream.Input == Output, Downstream.Failure == Failure
        {
            let inner = Inner(parent: self, downstream: subscriber)
            upstream.subscribe(inner)
        }
    }
}

extension Publishers.Throttle {
    private final class Inner<Downstream: Subscriber>
        : Subscriber,
          Subscription,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Downstream.Input == Output, Downstream.Failure == Failure
    {
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure

        typealias Parent = Publishers.Throttle<Upstream, Context>

        private enum State {
            case ready(Parent, Downstream)
            case subscribed(Parent,
                            Downstream,
                            Subscription,
                            Subscribers.Completion<Failure>?)
            case terminal
        }

        private let lock = UnfairLock.allocate()
        private let downstreamLock = UnfairRecursiveLock.allocate()
        private var state: State
        private var demand = Subscribers.Demand.none
        private var currentValue: Input?
        private var dueTime: Context.SchedulerTimeType
        private var scheduledToEmit = false
        private var alreadySentSubscription = false

        init(parent: Parent, downstream: Downstream) {
            self.state = .ready(parent, downstream)
            self.dueTime = parent.scheduler.now
        }

        deinit {
            lock.deallocate()
            downstreamLock.deallocate()
        }

        func receive(subscription: Subscription) {
            lock.lock()
            guard case let .ready(parent, downstream) = state else {
                lock.unlock()
                subscription.cancel()
                return
            }
            state = .subscribed(parent, downstream, subscription, nil)
            dueTime = parent.scheduler.now
            alreadySentSubscription = true
            lock.unlock()

            // TODO: Test order
            downstreamLock.lock()
            downstream.receive(subscription: self)
            downstreamLock.unlock()

            subscription.request(.unlimited)
        }

        func receive(_ input: Input) -> Subscribers.Demand {
            lock.lock()
            guard case let .subscribed(parent, _, _, nil) = state else {
                lock.unlock()
                return .none
            }

            let late = parent.scheduler.now >= dueTime

            if parent.latest {
                currentValue = input
            } else {
                if late {
                    dueTime = dueTime.advanced(by: parent.interval)
                    currentValue = input
                } else {
                    if currentValue == nil {
                        currentValue = input
                    }
                }
            }

            if scheduledToEmit || demand == .none {
                lock.unlock()
                return .none
            }

            scheduleEmittingAndConsumeLock(scheduler: parent.scheduler, late: late)

            return .none
        }

        func receive(completion: Subscribers.Completion<Failure>) {
            lock.lock()
            guard case let .subscribed(parent,
                                       downstream,
                                       subscription,
                                       nil) = state
            else {
                // TODO: Test with non-nil completion
                if !scheduledToEmit {
                    state = .terminal
                }
                lock.unlock()
                return
            }
            dueTime = parent.scheduler.now
            state = .subscribed(parent, downstream, subscription, completion)

            if scheduledToEmit {
                lock.unlock()
                return
            }

            scheduledToEmit = true
            lock.unlock()
            parent.scheduler.schedule(emitToDownstream)
        }

        func request(_ demand: Subscribers.Demand) {
            lock.lock()
            guard case let .subscribed(parent, _, _, nil) = state else {
                // TODO: Test with non-nil completion
                lock.unlock()
                return
            }

            self.demand += demand

            if currentValue == nil || scheduledToEmit {
                lock.unlock()
                return
            }

            // TODO: Test if we schedule even for zero demand

            scheduleEmittingAndConsumeLock(scheduler: parent.scheduler,
                                           late: parent.scheduler.now >= dueTime)
        }

        func cancel() {
            lock.lock()
            guard case let .subscribed(_, _, subscription, _) = state else {
                state = .terminal
                lock.unlock()
                return
            }
            state = .terminal
            currentValue = nil
            demand = .none
            lock.unlock()

            subscription.cancel()
        }

        var description: String { return "Throttle" }

        var customMirror: Mirror { return Mirror(self, children: EmptyCollection()) }

        var playgroundDescription: Any { return description }

        // MARK: - Private

        private func scheduleEmittingAndConsumeLock(scheduler: Context, late: Bool) {
#if DEBUG
            lock.assertOwner()
#endif
            scheduledToEmit = true
            if late {
                lock.unlock()
                scheduler.schedule(emitToDownstream)
            } else {
                let dueTime = self.dueTime
                lock.unlock()
                scheduler.schedule(after: dueTime, emitToDownstream)
            }
        }

        private func emitToDownstream() {
            lock.lock()
            guard case let .subscribed(parent,
                                       downstream,
                                       _,
                                       completion) = state, scheduledToEmit
            else {
                lock.unlock()
                return
            }

            var shouldSendValueDownstream = false
            let valueToSend = currentValue
            if valueToSend != nil {
                if demand == .none {
                    shouldSendValueDownstream = false
                } else {
                    demand -= 1
                    currentValue = nil
                    shouldSendValueDownstream = true
                }
            }

            scheduledToEmit = false
            if completion == nil {
                dueTime = parent.scheduler.now.advanced(by: parent.interval)
            } else {
                state = .terminal
            }
            lock.unlock()
            downstreamLock.lock()

            let newDemand = shouldSendValueDownstream
                ? (valueToSend.map(downstream.receive(_:)) ?? .none)
                : .none

            if let completion = completion {
                downstream.receive(completion: completion)
            }
            downstreamLock.unlock()

            if newDemand == .none || completion != nil {
                return
            }

            lock.lock()
            demand += newDemand
            lock.unlock()
        }
    }
}
