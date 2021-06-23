//
//  ThrottleTests.swift
//  
//
//  Created by Stuart Austin on 14/11/2020.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class ThrottleTests: XCTestCase {

    private func testBasicBehavior(latest: Bool) {
        typealias Time = VirtualTimeScheduler.SchedulerTimeType
        let scheduler = VirtualTimeScheduler()
        let helper = OperatorTestHelper(
            publisherType: CustomPublisherBase<Time, Never>.self,
            initialDemand: .unlimited,
            receiveValueDemand: .none
        ) {
            $0.throttle(for: .nanoseconds(10), scheduler: scheduler, latest: latest)
        }

        for moment in stride(from: Time.nanoseconds(0),
                             through: .nanoseconds(45),
                             by: .nanoseconds(3))
        {
            scheduler.rewind(to: moment)
            _ = helper.publisher.send(moment)
        }

        scheduler.executeScheduledActions()

        if latest {
            XCTAssertEqual(helper.tracking.history,
                           [.subscription("Throttle"),
                            .value(.nanoseconds(0)),
                            .value(.nanoseconds(9)),
                            .value(.nanoseconds(18)),
                            .value(.nanoseconds(27)),
                            .value(.nanoseconds(39)),
                            .value(.nanoseconds(45))])
        } else {
            XCTAssertEqual(helper.tracking.history,
                           [.subscription("Throttle"),
                            .value(.nanoseconds(0)),
                            .value(.nanoseconds(3)),
                            .value(.nanoseconds(12)),
                            .value(.nanoseconds(21)),
                            .value(.nanoseconds(30)),
                            .value(.nanoseconds(42))])
        }

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
    }

    func testBasicBehaviorLatest() {
        testBasicBehavior(latest: true)
    }

    func testBasicBehaviorNotLatest() {
        testBasicBehavior(latest: false)
    }

    private func testScheduling(latest: Bool) {
        let scheduler = VirtualTimeScheduler()
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .max(100),
                                        receiveValueDemand: .max(12)) {
            $0.throttle(for: .seconds(1337), scheduler: scheduler, latest: latest)
        }
        XCTAssertNotNil(helper.publisher.subscriber,
                        "Subscription must be performed synchronously")

        XCTAssertEqual(helper.tracking.history, [.subscription("Throttle")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(scheduler.history, [.now, // Subscriber created
                                           .now]) // Subscription received by Subscriber

        // Send an initial value to the subject. This should be scheduled immediately
        XCTAssertEqual(helper.publisher.send(1), .none)

        XCTAssertEqual(scheduler.history, [.now,
                                           .now,
                                           // Checking the time when the Subscriber
                                           // receives the input "1"
                                           .now,
                                           // Scheduling the output
                                           // of the input immediately as we have not
                                           // output any values
                                           .schedule(options: nil)])

        // Send some more values to the subject. Since we haven't run the scheduled
        // output above, these won't create any additional scheduled work
        XCTAssertEqual(helper.publisher.send(2), .none)
        XCTAssertEqual(helper.publisher.send(3), .none)

        XCTAssertEqual(helper.tracking.history, [.subscription("Throttle")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(scheduler.scheduledDates, [.nanoseconds(0)])

        XCTAssertEqual(scheduler.history, [.now,
                                           .now,
                                           .now,
                                           .schedule(options: nil),
                                           // Checking the time when the Subscriber
                                           // receives the input "2"
                                           .now,
                                           // Checking the time when the Subscriber
                                           // receives the input "3"
                                           .now])

        scheduler.executeScheduledActions()

        XCTAssertEqual(helper.tracking.history, [.subscription("Throttle"),
                                                 // Expect only 3 or 1 to be output
                                                 .value(latest ? 3 : 1)])

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        XCTAssertEqual(scheduler.history, [.now,
                                           .now,
                                           .now,
                                           .schedule(options: nil),
                                           .now,
                                           .now,
                                           .now]) // Log the time of the output

        // Send another value to the subject. This should be scheduled after the interval
        XCTAssertEqual(helper.publisher.send(4), .none)

        XCTAssertEqual(helper.tracking.history, [.subscription("Throttle"),
                                                 .value(latest ? 3 : 1)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(scheduler.scheduledDates, [.seconds(1337)])

        XCTAssertEqual(scheduler.history, [.now,
                                           .now,
                                           .now,
                                           .schedule(options: nil),
                                           .now,
                                           .now,
                                           .now,
                                           // Checking the time when the Subscriber
                                           // receives the input "4"
                                           .now,
                                           // When scheduling the output, it uses
                                           // the minimum tolerance
                                           .minimumTolerance,
                                           // Scheduling of the output
                                           .scheduleAfterDate(.seconds(1337),
                                                              tolerance: .nanoseconds(7),
                                                              options: nil)])

        XCTAssertEqual(helper.tracking.history, [.subscription("Throttle"),
                                                 .value(latest ? 3 : 1)])
        XCTAssertEqual(scheduler.scheduledDates, [.seconds(1337)])

        XCTAssertEqual(scheduler.history, [.now,
                                           .now,
                                           .now,
                                           .schedule(options: nil),
                                           .now,
                                           .now,
                                           .now,
                                           // Checking the time when the Subscriber
                                           // receives the input "4"
                                           .now,
                                           // When scheduling the output, it uses
                                           // the minimum tolerance
                                           .minimumTolerance,
                                           // Scheduling of the output
                                           .scheduleAfterDate(.seconds(1337),
                                                              tolerance: .nanoseconds(7),
                                                              options: nil)])

        helper.publisher.send(completion: .failure(.oops))
        helper.publisher.send(completion: .finished)
        XCTAssertEqual(helper.publisher.send(5), .none)

        XCTAssertEqual(helper.tracking.history, [.subscription("Throttle"),
                                                 .value(latest ? 3 : 1)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(scheduler.scheduledDates, [.seconds(1337)])
        XCTAssertEqual(scheduler.history, [.now,
                                           .now,
                                           .now,
                                           .schedule(options: nil),
                                           .now,
                                           .now,
                                           .now,
                                           .now,
                                           .minimumTolerance,
                                           .scheduleAfterDate(.seconds(1337),
                                                              tolerance: .nanoseconds(7),
                                                              options: nil),
                                           .now])
        scheduler.executeScheduledActions()
        XCTAssertEqual(helper.tracking.history, [.subscription("Throttle"),
                                                 .value(latest ? 3 : 1),
                                                 .value(4),
                                                 .completion(.failure(.oops))])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(scheduler.history, [.now,
                                           .now,
                                           .now,
                                           .schedule(options: nil),
                                           .now,
                                           .now,
                                           .now,
                                           .now,
                                           .minimumTolerance,
                                           .scheduleAfterDate(.seconds(1337),
                                                              tolerance: .nanoseconds(7),
                                                              options: nil),
                                           .now])
        XCTAssertEqual(scheduler.now, .seconds(1337))
    }

    func testSchedulingLatest() {
        testScheduling(latest: true)
    }

    func testSchedulingNotLatest() {
        testScheduling(latest: false)
    }

    func testThrottleDemand() {
        let scheduler = VirtualTimeScheduler()
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .max(2),
                                        receiveValueDemand: .none) {
            $0.throttle(for: .seconds(1337), scheduler: scheduler, latest: false)
        }

        XCTAssertEqual(helper.tracking.history, [.subscription("Throttle")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(scheduler.history, [.now, // Subscriber created
                                           .now]) // Subscription received by Subscriber

        // Send an initial value to the subject. This should be scheduled immediately
        XCTAssertEqual(helper.publisher.send(1), .none)

        XCTAssertEqual(scheduler.history, [.now,
                                           .now,
                                           // Checking the time when the Subscriber
                                           // receives the input "1"
                                           .now,
                                           // Scheduling the output of the input
                                           // immediately as we have not output any values
                                           .schedule(options: nil)])

        // Send some more values to the subject.
        // Since we haven't run the scheduled output above, these won't create
        // any additional scheduled work
        XCTAssertEqual(helper.publisher.send(5), .none)
        XCTAssertEqual(helper.publisher.send(6), .none)

        XCTAssertEqual(helper.tracking.history, [.subscription("Throttle")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(scheduler.scheduledDates, [.nanoseconds(0)])

        XCTAssertEqual(scheduler.history, [.now,
                                           .now,
                                           .now,
                                           .schedule(options: nil),
                                           // Checking the time when the Subscriber
                                           // receives the input "5"
                                           .now,
                                           // Checking the time when the Subscriber
                                           // receives the input "6"
                                           .now])

        scheduler.executeScheduledActions()

        // Send a second value to the subject. This should be scheduled after the interval
        XCTAssertEqual(helper.publisher.send(2), .none)

        XCTAssertEqual(helper.tracking.history, [.subscription("Throttle"),
                                                 .value(1)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(scheduler.scheduledDates, [.seconds(1337)])

        XCTAssertEqual(scheduler.history, [.now,
                                           .now,
                                           .now,
                                           .schedule(options: nil),
                                           .now,
                                           .now,
                                           .now,
                                           // Checking the time when the Subscriber
                                           // receives the input "2"
                                           .now,
                                           // When scheduling the output, it uses
                                           // the minimum tolerance
                                           .minimumTolerance,
                                           // Scheduling of the output
                                           .scheduleAfterDate(.seconds(1337),
                                                              tolerance: .nanoseconds(7),
                                                              options: nil)])

        scheduler.executeScheduledActions()

        XCTAssertEqual(helper.tracking.history, [.subscription("Throttle"),
                                                 .value(1),
                                                 .value(2)])

        // Send a third value to the subject.
        // This should not be output at all due to the demand
        XCTAssertEqual(helper.publisher.send(3), .none)

        XCTAssertEqual(helper.tracking.history, [.subscription("Throttle"),
                                                 .value(1),
                                                 .value(2)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(scheduler.scheduledDates, [])

        XCTAssertEqual(scheduler.history, [.now,
                                           .now,
                                           .now,
                                           .schedule(options: nil),
                                           .now,
                                           .now,
                                           .now,
                                           // Checking the time when the Subscriber
                                           // receives the input "4"
                                           .now,
                                           // When scheduling the output, it uses
                                           // the minimum tolerance
                                           .minimumTolerance,
                                           // Scheduling of the output
                                           .scheduleAfterDate(.seconds(1337),
                                                              tolerance: .nanoseconds(7),
                                                              options: nil),
                                           .now,
                                           .now])

        scheduler.executeScheduledActions()

        XCTAssertEqual(helper.tracking.history, [.subscription("Throttle"),
                                                 .value(1),
                                                 .value(2)])
    }

    func testThrottleGap() {
        let scheduler = VirtualTimeScheduler()
        let extractedExpr = OperatorTestHelper(publisherType: CustomPublisher.self,
                                               initialDemand: .unlimited,
                                               receiveValueDemand: .none) {
            $0.throttle(for: .seconds(60), scheduler: scheduler, latest: false)
        }
        let helper = extractedExpr

        XCTAssertEqual(helper.tracking.history, [.subscription("Throttle")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(scheduler.history, [.now,
                                           .now])

        XCTAssertEqual(helper.publisher.send(0), .none)

        XCTAssertEqual(scheduler.history, [.now,
                                           .now,
                                           .now,
                                           .schedule(options: nil)])

        XCTAssertEqual(helper.tracking.history, [.subscription("Throttle")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(scheduler.scheduledDates, [.nanoseconds(0)])

        XCTAssertEqual(scheduler.history, [.now,
                                           .now,
                                           .now,
                                           .schedule(options: nil)])

        scheduler.executeScheduledActions()

        XCTAssertEqual(scheduler.history, [.now,
                                           .now,
                                           .now,
                                           .schedule(options: nil),
                                           .now])

        XCTAssertEqual(helper.tracking.history, [.subscription("Throttle"), .value(0)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(scheduler.scheduledDates, [])

        var future = scheduler.now + .seconds(45)

        XCTAssertEqual(scheduler.history, [.now,
                                           .now,
                                           .now,
                                           .schedule(options: nil),
                                           .now,
                                           .now])

        // change the current time to be 45 seconds into the future
        scheduler.rewind(to: future)

        XCTAssertEqual(helper.publisher.send(1), .none)

        XCTAssertEqual(scheduler.history, [.now,
                                           .now,
                                           .now,
                                           .schedule(options: nil),
                                           .now,
                                           .now,
                                           .now,
                                           .minimumTolerance,
                                           .scheduleAfterDate(.seconds(60),
                                                              tolerance: .nanoseconds(7),
                                                              options: nil)])

        XCTAssertEqual(helper.tracking.history, [.subscription("Throttle"), .value(0)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        // next value should be emitted 60 seconds from the start of time
        XCTAssertEqual(scheduler.scheduledDates, [.seconds(60)])

        scheduler.executeScheduledActions()

        XCTAssertEqual(scheduler.history, [.now,
                                           .now,
                                           .now,
                                           .schedule(options: nil),
                                           .now,
                                           .now,
                                           .now,
                                           .minimumTolerance,
                                           .scheduleAfterDate(.seconds(60),
                                                              tolerance: .nanoseconds(7),
                                                              options: nil),
                                           .now])

        XCTAssertEqual(helper.tracking.history, [.subscription("Throttle"),
                                                 .value(0),
                                                 .value(1)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(scheduler.scheduledDates, [])

        future = scheduler.now + .seconds(61)

        XCTAssertEqual(scheduler.history, [.now,
                                           .now,
                                           .now,
                                           .schedule(options: nil),
                                           .now,
                                           .now,
                                           .now,
                                           .minimumTolerance,
                                           .scheduleAfterDate(.seconds(60),
                                                              tolerance: .nanoseconds(7),
                                                              options: nil),
                                           .now,
                                           .now])

        // change the current time to be 61 seconds into the future
        scheduler.rewind(to: future)

        XCTAssertEqual(helper.publisher.send(2), .none)

        XCTAssertEqual(scheduler.history, [.now,
                                           .now,
                                           .now,
                                           .schedule(options: nil),
                                           .now,
                                           .now,
                                           .now,
                                           .minimumTolerance,
                                           .scheduleAfterDate(.seconds(60),
                                                              tolerance: .nanoseconds(7),
                                                              options: nil),
                                           .now,
                                           .now,
                                           .now,
                                           // next value should be scheduled immediately
                                           // as the interval has passed
                                           .schedule(options: nil)])

        XCTAssertEqual(helper.tracking.history, [.subscription("Throttle"),
                                                 .value(0),
                                                 .value(1)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        // next value should be emitted 121 seconds from the start of time
        XCTAssertEqual(scheduler.scheduledDates, [.seconds(121)])

        scheduler.executeScheduledActions()

        XCTAssertEqual(scheduler.history, [.now,
                                           .now,
                                           .now,
                                           .schedule(options: nil),
                                           .now,
                                           .now,
                                           .now,
                                           .minimumTolerance,
                                           .scheduleAfterDate(.seconds(60),
                                                              tolerance: .nanoseconds(7),
                                                              options: nil),
                                           .now,
                                           .now,
                                           .now,
                                           .schedule(options: nil),
                                           .now])

        XCTAssertEqual(helper.tracking.history, [.subscription("Throttle"),
                                                 .value(0),
                                                 .value(1),
                                                 .value(2)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(scheduler.scheduledDates, [])
    }

    func testRequest() throws {
        let scheduler = VirtualTimeScheduler()
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: nil,
                                        receiveValueDemand: .none) {
            $0.throttle(for: .seconds(10), scheduler: scheduler, latest: true)
        }
        scheduler.executeScheduledActions()

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(helper.tracking.history, [.subscription("Throttle")])

        try XCTUnwrap(helper.downstreamSubscription).request(.max(10))
        try XCTUnwrap(helper.downstreamSubscription).request(.max(4))
        try XCTUnwrap(helper.downstreamSubscription).request(.max(5))
        try XCTUnwrap(helper.downstreamSubscription).request(.none)
        XCTAssertEqual(helper.publisher.send(2000), .none)

        XCTAssertEqual(helper.tracking.history, [.subscription("Throttle")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        scheduler.executeScheduledActions()
        XCTAssertEqual(helper.tracking.history, [.subscription("Throttle"),
                                                 .value(2000)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
    }

    func testCancelAlreadyCancelled() throws {
        let scheduler = VirtualTimeScheduler()
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .unlimited,
                                        receiveValueDemand: .none) {
            $0.throttle(for: .seconds(10), scheduler: scheduler, latest: true)
        }

        scheduler.executeScheduledActions()
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(helper.tracking.history, [.subscription("Throttle")])

        try XCTUnwrap(helper.downstreamSubscription).cancel()
        try XCTUnwrap(helper.downstreamSubscription).request(.max(42))
        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited), .cancelled])
        XCTAssertEqual(helper.tracking.history, [.subscription("Throttle")])
        XCTAssertEqual(scheduler.history, [.now, .now])

        XCTAssertEqual(helper.publisher.send(0), .none)
        helper.publisher.send(completion: .finished)

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited), .cancelled])
        XCTAssertEqual(helper.tracking.history, [.subscription("Throttle")])
        XCTAssertEqual(scheduler.history, [.now, .now])
    }

    func testNoDemandReceivesNoValues() throws {
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)

        let tracking = TrackingSubscriber(
            receiveValue: { _ in
                XCTFail("Unexpected value received")
                return .none
            }
        )

        let throttle = publisher.throttle(for: .milliseconds(1),
                                          scheduler: ImmediateScheduler.shared,
                                          latest: true)
        throttle.subscribe(tracking)

        XCTAssertEqual(tracking.history, [.subscription("Throttle")])
        XCTAssertEqual(subscription.history, [.requested(.unlimited)])

        XCTAssertEqual(publisher.send(1), .none)

        XCTAssertEqual(tracking.history, [.subscription("Throttle")])
        XCTAssertEqual(subscription.history, [.requested(.unlimited)])

        XCTAssertEqual(tracking.history, [.subscription("Throttle")])
        XCTAssertEqual(subscription.history, [.requested(.unlimited)])
    }

    func testCancelWhileReceivingInput() throws {
        let scheduler = VirtualTimeScheduler()
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriber(
            receiveSubscription: {
                downstreamSubscription = $0
                $0.request(.unlimited)
            },
            receiveValue: { _ in
                XCTAssertNotNil(downstreamSubscription)
                downstreamSubscription?.cancel()
                return .max(42)
            }
        )

        let throttle = publisher.throttle(for: .seconds(60),
                                          scheduler: scheduler,
                                          latest: true)
        throttle.subscribe(tracking)

        XCTAssertEqual(tracking.history, [.subscription("Throttle")])
        XCTAssertEqual(subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(scheduler.history, [.now, .now])

        XCTAssertEqual(publisher.send(1), .none)

        XCTAssertEqual(tracking.history, [.subscription("Throttle")])
        XCTAssertEqual(subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(scheduler.history, [.now, .now, .now, .schedule(options: nil)])

        scheduler.executeScheduledActions()

        XCTAssertEqual(tracking.history, [.subscription("Throttle"), .value(1)])
        XCTAssertEqual(subscription.history, [.requested(.unlimited), .cancelled])
        XCTAssertEqual(scheduler.history, [.now,
                                           .now,
                                           .now,
                                           .schedule(options: nil),
                                           .now])
    }

    func testCancelWhilstScheduledOutput() {
        let scheduler = VirtualTimeScheduler()
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriber(
            receiveSubscription: {
                downstreamSubscription = $0
                $0.request(.unlimited)
            },
            receiveValue: { _ in
                XCTAssertNotNil(downstreamSubscription)
                return .max(42)
            }
        )

        let throttle = publisher.throttle(for: .seconds(60),
                                          scheduler: scheduler,
                                          latest: true)
        throttle.subscribe(tracking)

        XCTAssertEqual(tracking.history, [.subscription("Throttle")])
        XCTAssertEqual(subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(scheduler.history, [.now, .now])

        XCTAssertEqual(publisher.send(1), .none)

        XCTAssertEqual(tracking.history, [.subscription("Throttle")])
        XCTAssertEqual(subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(scheduler.history, [.now, .now, .now, .schedule(options: nil)])

        tracking.cancel()

        scheduler.executeScheduledActions()

        XCTAssertEqual(tracking.history, [])
        XCTAssertEqual(subscription.history, [.requested(.unlimited), .cancelled])
        XCTAssertEqual(scheduler.history, [.now,
                                           .now,
                                           .now,
                                           .schedule(options: nil)])
    }

    func testReceiveCompletionImmediatelyAfterSubscription() {
        let scheduler = VirtualTimeScheduler()
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .unlimited,
                                        receiveValueDemand: .none) {
            $0.throttle(for: .seconds(60), scheduler: scheduler, latest: true)
        }

        helper.publisher.send(completion: .failure(.oops))

        XCTAssertEqual(helper.tracking.history, [.subscription("Throttle")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(scheduler.history, [.now, .now, .now, .schedule(options: nil)])

        scheduler.executeScheduledActions()

        XCTAssertEqual(helper.tracking.history, [.subscription("Throttle"),
                                                 .completion(.failure(.oops))])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
    }

    func testReceiveCompletionImmediatelyAfterValue() {
        let scheduler = VirtualTimeScheduler()
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .unlimited,
                                        receiveValueDemand: .max(418)) {
            $0.throttle(for: .seconds(60), scheduler: scheduler, latest: true)
        }
        XCTAssertEqual(helper.publisher.send(-1), .none)
        scheduler.executeScheduledActions()

        XCTAssertEqual(helper.publisher.send(1000), .none)
        helper.publisher.send(completion: .finished)

        XCTAssertEqual(helper.tracking.history, [.subscription("Throttle"),
                                                 .value(-1)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(scheduler.history, [.now,
                                           .now,
                                           .now,
                                           .schedule(options: nil),
                                           .now,
                                           .now,
                                           .minimumTolerance,
                                           .scheduleAfterDate(.seconds(60),
                                                              tolerance: .nanoseconds(7),
                                                              options: nil),
                                           .now])

        scheduler.executeScheduledActions()

        XCTAssertEqual(helper.tracking.history, [.subscription("Throttle"),
                                                 .value(-1),
                                                 .value(1000),
                                                 .completion(.finished)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
    }

    func testReceiveInputRecursively() {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .unlimited,
                                        receiveValueDemand: .max(418)) {
            $0.throttle(for: .seconds(60),
                        scheduler: ImmediateScheduler.shared,
                        latest: true)
        }

        var recursionCounter = 5
        helper.tracking.onValue = { _ in
            if recursionCounter == 0 { return }
            recursionCounter -= 1
            _ = helper.publisher.send(-1)
        }

        XCTAssertEqual(helper.publisher.send(0), .none)
        XCTAssertEqual(helper.tracking.history, [.subscription("Throttle"),
                                                 .value(0),
                                                 .value(-1),
                                                 .value(-1),
                                                 .value(-1),
                                                 .value(-1),
                                                 .value(-1)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
    }

    func testReceiveCompletionRecursively() {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .unlimited,
                                        receiveValueDemand: .max(418)) {
            $0.throttle(for: .seconds(60),
                        scheduler: ImmediateScheduler.shared,
                        latest: true)
        }
        helper.tracking.onFinish = {
            helper.publisher.send(completion: .finished)
        }
        helper.publisher.send(completion: .finished)
    }

    func testWeakCaptureWhenSchedulingValue() {
        let scheduler = VirtualTimeScheduler()
        var value: Int?
        var subscriberReleased = false
        do {
            let publisher = CustomPublisher(subscription: CustomSubscription())
            let throttle = publisher.throttle(for: .seconds(60),
                                              scheduler: scheduler,
                                              latest: true)
            let tracking =
                TrackingSubscriber(receiveSubscription: { $0.request(.unlimited) },
                                   receiveValue: { value = $0; return .none },
                                   onDeinit: { subscriberReleased = true })
            throttle.subscribe(tracking)
            scheduler.executeScheduledActions()
            XCTAssertEqual(tracking.history, [.subscription("Throttle")])
            XCTAssertEqual(publisher.send(42), .none)
            XCTAssertEqual(tracking.history, [.subscription("Throttle")])
            XCTAssertEqual(scheduler.history, [.now, .now, .now, .schedule(options: nil)])
            tracking.cancel()
            publisher.cancel()
        }
        XCTAssertTrue(subscriberReleased)
        XCTAssertNil(value)
    }

    func testWeakCaptureWhenSchedulingCompletion() {
        let scheduler = VirtualTimeScheduler()
        var completion: Subscribers.Completion<TestingError>?
        var subscriberReleased = false
        do {
            let publisher = CustomPublisher(subscription: CustomSubscription())
            let throttle = publisher.throttle(for: .seconds(60),
                                              scheduler: scheduler,
                                              latest: true)
            let tracking = TrackingSubscriber(receiveCompletion: { completion = $0 },
                                              onDeinit: { subscriberReleased = true })
            throttle.subscribe(tracking)
            scheduler.executeScheduledActions()
            XCTAssertEqual(tracking.history, [.subscription("Throttle")])
            publisher.send(completion: .finished)
            XCTAssertEqual(tracking.history, [.subscription("Throttle")])
            XCTAssertEqual(scheduler.history, [.now, .now, .now, .schedule(options: nil)])
            tracking.cancel()
            publisher.cancel()
        }
        XCTAssertTrue(subscriberReleased)
        XCTAssertNil(completion)
        scheduler.executeScheduledActions()
        XCTAssertNil(completion)
    }

    func testThrottleReceiveSubscriptionTwice() throws {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: nil,
                                        receiveValueDemand: .none) {
            $0.throttle(for: .seconds(60),
                        scheduler: ImmediateScheduler.shared,
                        latest: true)
        }

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        let secondSubscription = CustomSubscription()

        try XCTUnwrap(helper.publisher.subscriber)
            .receive(subscription: secondSubscription)

        XCTAssertEqual(secondSubscription.history, [.cancelled])

        try XCTUnwrap(helper.publisher.subscriber)
            .receive(subscription: helper.subscription)

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited),
                                                     .cancelled])

        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited),
                                                     .cancelled,
                                                     .cancelled])
    }

    func testThrottleReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(value: 213,
                                           expected: .history([], demand: .none)) {
            $0.throttle(for: .seconds(60),
                        scheduler: ImmediateScheduler.shared,
                        latest: true)
        }
    }

    func testThrottleReceiveCompletionBeforeSubscription()  {
        testReceiveCompletionBeforeSubscription(inputType: Int.self,
                                                expected: .history([])) {
            $0.throttle(for: .seconds(60),
                        scheduler: ImmediateScheduler.shared,
                        latest: true)
        }
    }

    func testThrottleRequestBeforeSubscription() {
        testRequestBeforeSubscription(inputType: Int.self, shouldCrash: false) {
            $0.throttle(for: .seconds(60),
                        scheduler: ImmediateScheduler.shared,
                        latest: true)
        }
    }

    func testThrottleCancelBeforeSubscription() {
        testCancelBeforeSubscription(inputType: Int.self,
                                     expected: .history([.cancelled])) {
            $0.throttle(for: .seconds(60),
                        scheduler: ImmediateScheduler.shared,
                        latest: true)
        }
    }

    func testThrottleReflection() throws {
        try testReflection(parentInput: String.self,
                           parentFailure: Error.self,
                           description: "Throttle",
                           customMirror: childrenIsEmpty,
                           playgroundDescription: "Throttle",
                           { $0.throttle(for: .seconds(60),
                                         scheduler: ImmediateScheduler.shared,
                                         latest: true) })
    }

    func testThrottleLifecycle() throws {
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: true) {
            $0.throttle(for: .seconds(60),
                        scheduler: ImmediateScheduler.shared,
                        latest: true)
        }
    }
}
