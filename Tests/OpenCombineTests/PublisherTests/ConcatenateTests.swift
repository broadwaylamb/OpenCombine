//
//  ConcatenateTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 09.12.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class ConcatenateTests: XCTestCase {

    func testAppendBasicBehavior() {
        let subscription1 = CustomSubscription()
        let subscription2 = CustomSubscription()
        let publisher1 = CustomPublisher(subscription: subscription1)
        let publisher2 = CustomPublisher(subscription: subscription2)

        let append = publisher1.append(publisher2)

        let tracking = TrackingSubscriber(
            receiveSubscription: { $0.request(.max(10)) },
            receiveValue: { .max($0) },
            receiveCompletion: { _ in }
        )

        append.subscribe(tracking)

        XCTAssertEqual(tracking.history, [.subscription("Concatenate")])
        XCTAssertEqual(subscription1.history, [.requested(.max(10))])
        XCTAssertEqual(subscription2.history, [])

        XCTAssertEqual(publisher1.send(1), .max(1))
        XCTAssertEqual(publisher2.send(-1), .none)
        XCTAssertEqual(publisher1.send(2), .max(2))
        XCTAssertEqual(publisher2.send(-2), .none)
        XCTAssertEqual(publisher1.send(3), .max(3))
        XCTAssertEqual(publisher2.send(-3), .none)
        publisher2.send(completion: .failure(.oops))

        XCTAssertEqual(tracking.history, [.subscription("Concatenate"),
                                          .value(1),
                                          .value(2),
                                          .value(3)])
        XCTAssertEqual(subscription1.history, [.requested(.max(10))])
        XCTAssertEqual(subscription2.history, [])

        publisher1.send(completion: .finished)

        XCTAssertEqual(tracking.history, [.subscription("Concatenate"),
                                          .value(1),
                                          .value(2),
                                          .value(3)])
        XCTAssertEqual(subscription1.history, [.requested(.max(10))])
        XCTAssertEqual(subscription2.history, [.requested(.max(13))])

        XCTAssertEqual(publisher1.send(4000), .none)
        XCTAssertEqual(publisher2.send(5), .max(5))

        XCTAssertEqual(tracking.history, [.subscription("Concatenate"),
                                          .value(1),
                                          .value(2),
                                          .value(3),
                                          .value(5)])
        XCTAssertEqual(subscription1.history, [.requested(.max(10))])
        XCTAssertEqual(subscription2.history, [.requested(.max(13))])

        publisher2.send(completion: .finished)
        publisher2.send(completion: .finished)
        publisher2.send(completion: .failure(.oops))

        XCTAssertEqual(publisher1.send(6000), .none)
        XCTAssertEqual(publisher2.send(7), .none)

        XCTAssertEqual(tracking.history, [.subscription("Concatenate"),
                                          .value(1),
                                          .value(2),
                                          .value(3),
                                          .value(5),
                                          .completion(.finished)])
        XCTAssertEqual(subscription1.history, [.requested(.max(10))])
        XCTAssertEqual(subscription2.history, [.requested(.max(13))])

        let subscription3 = CustomSubscription()
        publisher2.send(subscription: subscription3)

        XCTAssertEqual(tracking.history, [.subscription("Concatenate"),
                                          .value(1),
                                          .value(2),
                                          .value(3),
                                          .value(5),
                                          .completion(.finished)])
        XCTAssertEqual(subscription3.history, [.cancelled])
    }

    func testSecondCompletion() {
        let subscription1 = CustomSubscription()
        let subscription2 = CustomSubscription()
        let publisher1 = CustomPublisher(subscription: subscription1)
        let publisher2 = CustomPublisher(subscription: subscription2)

        let append = publisher1.append(publisher2)

        let tracking = TrackingSubscriber(
            receiveSubscription: { $0.request(.max(10)) },
            receiveValue: { .max($0) },
            receiveCompletion: { _ in }
        )

        append.subscribe(tracking)

        XCTAssertEqual(subscription1.history, [.requested(.max(10))])
        XCTAssertEqual(subscription2.history, [])

        publisher1.send(completion: .finished)
        publisher1.send(completion: .finished)

        XCTAssertEqual(subscription1.history, [.requested(.max(10))])
        XCTAssertEqual(subscription2.history, [.requested(.max(10))])

        publisher2.send(completion: .finished)

        XCTAssertEqual(subscription1.history, [.requested(.max(10))])
        XCTAssertEqual(subscription2.history, [.requested(.max(10))])
        XCTAssertEqual(tracking.history, [.subscription("Concatenate"),
                                          .completion(.finished)])
    }

    func testConcatenateTwoSequences() {
        let sequence1: Publishers.Sequence =
            sequence(first: 1, next: { $0 > 20 ? nil : $0 * 2 })
                .publisher

        let sequence2: Publishers.Sequence = (33 ..< 40).publisher

        let expected = [1, 2, 4, 8, 16, 32, 33, 34, 35, 36, 37, 38, 39]

        var historyAppend = [Int]()
        var appendCompleted = false
        let append: Publishers.Concatenate = sequence1.append(sequence2)
        let cancellableAppend = append
            .sink(receiveCompletion: { _ in appendCompleted = true },
                  receiveValue: { historyAppend.append($0) })
        XCTAssertEqual(historyAppend, expected)
        XCTAssertTrue(appendCompleted)
        cancellableAppend.cancel()

        var historyPrepend = [Int]()
        var prependCompleted = false
        let prepend: Publishers.Concatenate = sequence2.prepend(sequence1)
        let cancellablePrepend = prepend
            .sink(receiveCompletion: { _ in prependCompleted = true },
                  receiveValue: { historyPrepend.append($0) })
        XCTAssertEqual(historyPrepend, [1, 2, 4, 8, 16, 32, 33, 34, 35, 36, 37, 38, 39])
        XCTAssertTrue(prependCompleted)
        cancellablePrepend.cancel()
    }

    func testPrefixFailureFailsDownstream() {
        let subscription1 = CustomSubscription()
        let subscription2 = CustomSubscription()
        let publisher1 = CustomPublisher(subscription: subscription1)
        let publisher2 = CustomPublisher(subscription: subscription2)

        let append = publisher1.append(publisher2)

        let tracking = TrackingSubscriber(
            receiveSubscription: { $0.request(.max(10)) },
            receiveValue: { .max($0) },
            receiveCompletion: { _ in }
        )

        append.subscribe(tracking)

        XCTAssertEqual(tracking.history, [.subscription("Concatenate")])
        XCTAssertEqual(subscription1.history, [.requested(.max(10))])
        XCTAssertEqual(subscription2.history, [])

        publisher1.send(completion: .failure(.oops))

        XCTAssertEqual(tracking.history, [.subscription("Concatenate"),
                                          .completion(.failure(.oops))])
        XCTAssertEqual(subscription1.history, [.requested(.max(10))])
        XCTAssertEqual(subscription2.history, [])

        XCTAssertEqual(publisher1.send(2), .none)
        XCTAssertEqual(publisher2.send(3), .none)
        publisher2.send(completion: .finished)

        XCTAssertEqual(tracking.history, [.subscription("Concatenate"),
                                          .completion(.failure(.oops))])
        XCTAssertEqual(subscription1.history, [.requested(.max(10))])
        XCTAssertEqual(subscription2.history, [])
    }

    func testSubscribesToUpstreamThenSendsSubscriptionDownstream() {
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let append = publisher.append(1, 2, 3)
        let tracking = TrackingSubscriber()

        var didSubscribe = false

        publisher.didSubscribe = { _, _ in
            XCTAssertEqual(tracking.history, [.subscription("Concatenate")])
            didSubscribe = true
        }

        XCTAssertEqual(tracking.history, [])

        append.subscribe(tracking)

        XCTAssertTrue(didSubscribe)
        XCTAssertEqual(tracking.history, [.subscription("Concatenate")])
    }

    func testBackpressure() throws {
        let subscription1 = CustomSubscription()
        let subscription2 = CustomSubscription()
        let publisher1 = CustomPublisher(subscription: subscription1)
        let publisher2 = CustomPublisher(subscription: subscription2)

        let append = publisher1.append(publisher2)
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriber(
            receiveSubscription: { downstreamSubscription = $0; $0.request(.max(10)) },
            receiveValue: { .max($0) },
            receiveCompletion: { _ in }
        )

        publisher2.willSubscribe = { _, _ in
            downstreamSubscription?.request(.max(7))
            XCTAssertEqual(subscription1.history, [.requested(.max(10)),
                                                   .requested(.none)])
            XCTAssertEqual(subscription2.history, [])
        }

        append.subscribe(tracking)
        try XCTUnwrap(downstreamSubscription).request(.none)
        XCTAssertEqual(publisher1.send(3), .max(3))

        XCTAssertEqual(tracking.history, [.subscription("Concatenate"),
                                          .value(3)])
        XCTAssertEqual(subscription1.history, [.requested(.max(10)),
                                               .requested(.none)])
        XCTAssertEqual(subscription2.history, [])

        publisher1.send(completion: .finished)

        XCTAssertEqual(subscription1.history, [.requested(.max(10)),
                                               .requested(.none)])
        XCTAssertEqual(subscription2.history, [.requested(.max(19))])

        try XCTUnwrap(downstreamSubscription).request(.unlimited)

        XCTAssertEqual(subscription1.history, [.requested(.max(10)),
                                               .requested(.none)])
        XCTAssertEqual(subscription2.history, [.requested(.max(19)),
                                               .requested(.unlimited)])

        publisher2.send(completion: .finished)

        try XCTUnwrap(downstreamSubscription).request(.max(42))

        XCTAssertEqual(subscription1.history, [.requested(.max(10)),
                                               .requested(.none)])
        XCTAssertEqual(subscription2.history, [.requested(.max(19)),
                                               .requested(.unlimited)])
    }

    func testCancelAlreadyCancelled() throws {
        let subscription1 = CustomSubscription()
        let subscription2 = CustomSubscription()
        let publisher1 = CustomPublisher(subscription: subscription1)
        let publisher2 = CustomPublisher(subscription: subscription2)

        let append = publisher1.append(publisher2)
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriber(
            receiveSubscription: { downstreamSubscription = $0 },
            receiveValue: { .max($0) },
            receiveCompletion: { _ in }
        )
        append.subscribe(tracking)
        try XCTUnwrap(downstreamSubscription).cancel()
        try XCTUnwrap(downstreamSubscription).cancel()
        try XCTUnwrap(downstreamSubscription).request(.max(2))
        try XCTUnwrap(downstreamSubscription).cancel()
        try XCTUnwrap(downstreamSubscription).request(.max(3))

        XCTAssertEqual(tracking.history, [.subscription("Concatenate")])
        XCTAssertEqual(subscription1.history, [.cancelled])
        XCTAssertEqual(subscription2.history, [])

        XCTAssertEqual(publisher1.send(0), .none)

        XCTAssertEqual(tracking.history, [.subscription("Concatenate")])
        XCTAssertEqual(subscription1.history, [.cancelled])
        XCTAssertEqual(subscription2.history, [])
    }

    func testCompletionAfterCancellation() throws {
        let subscription1 = CustomSubscription()
        let subscription2 = CustomSubscription()
        let publisher1 = CustomPublisher(subscription: subscription1)
        let publisher2 = CustomPublisher(subscription: subscription2)

        let append = publisher1.append(publisher2)
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriber(
            receiveSubscription: { downstreamSubscription = $0 },
            receiveValue: { .max($0) },
            receiveCompletion: { _ in }
        )
        append.subscribe(tracking)

        try XCTUnwrap(downstreamSubscription).cancel()

        publisher1.send(completion: .finished)

        XCTAssertEqual(subscription1.history, [.cancelled])
        XCTAssertEqual(subscription2.history, [])
        XCTAssertEqual(tracking.history, [.subscription("Concatenate")])
    }

    func testRecursivelyReceiveValue() {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .max(3),
                                        receiveValueDemand: .none,
                                        createSut: { $0.append() })

        var recursion = 10
        helper.tracking.onValue = {
            if recursion == 0 { return }
            recursion -= 1
            XCTAssertEqual(helper.publisher.send($0 + 1), .none)
        }

        XCTAssertEqual(helper.publisher.send(1), .none)

        XCTAssertEqual(helper.tracking.history, [.subscription("Concatenate"),
                                                 .value(1),
                                                 .value(2),
                                                 .value(3)])
    }

    func testRecursivelyReceiveFailure() {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: nil,
                                        receiveValueDemand: .none,
                                        createSut: { $0.append() })

        var recursion = 10
        helper.tracking.onFailure = { _ in
            if recursion == 0 { return }
            recursion -= 1
            helper.publisher.send(completion: .failure(.oops))
        }

        helper.publisher.send(completion: .failure(.oops))

        XCTAssertEqual(helper.tracking.history, [.subscription("Concatenate"),
                                                 .completion(.failure(.oops))])
    }

    func testHelperMethods() {
        let publisher = CustomPublisher(subscription: nil)
        XCTAssertEqual(publisher.append(2, 3, 5, 7).suffix.sequence, [2, 3, 5, 7])
        XCTAssertEqual(publisher.append(CollectionOfOne(42)).suffix.sequence.first, 42)
        XCTAssertEqual(publisher.prepend(7, 5, 3, 2).prefix.sequence, [7, 5, 3, 2])
        XCTAssertEqual(publisher.prepend(CollectionOfOne(42)).prefix.sequence.first, 42)
    }

    func testReleasesSuffixOnCancellation() throws {
        var suffixIsDestroyed = false

        var downstreamSubscription: Subscription?

        do {
            let prefix =
                CustomPublisherBase<Int, Never>(subscription: CustomSubscription())
            let suffix =
                CustomPublisherBase<Int, Never>(subscription: CustomSubscription())
            suffix.onDeinit = {
                suffixIsDestroyed = true
            }

            let tracking = TrackingSubscriberBase<Int, Never>(
                receiveSubscription: {
                    downstreamSubscription = $0
                }
            )

            prefix.append(suffix).subscribe(tracking)
        }

        XCTAssertFalse(suffixIsDestroyed)

        try XCTUnwrap(downstreamSubscription).cancel()

        XCTAssertTrue(suffixIsDestroyed)
    }

    func testReceiveCompletionWhileCancelling() throws {

        var downstreamSubscription: Subscription?

        do {
            let prefix =
                CustomPublisherBase<Int, Never>(subscription: CustomSubscription())
            let autofinish = AutomaticallyFinish<Int, Never>()

            let tracking = TrackingSubscriberBase<Int, Never>(
                receiveSubscription: {
                    downstreamSubscription = $0
                }
            )

            prefix.append(autofinish).subscribe(tracking)

            prefix.send(completion: .finished)
        }

        // autofinish is deallocated here, a completion is sent
        try XCTUnwrap(downstreamSubscription).cancel()
    }

    func testAppendReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(
            value: 12,
            expected: .history([], demand: .none),
            { $0.append(1, 2, 3) }
        )
    }

    func testPrependReceiveValueBeforeSubscription() {
        let empty = Empty<Int, Never>(completeImmediately: true)
        testReceiveValueBeforeSubscription(
            value: 12,
            expected: .history([.subscription("Concatenate")], demand: .none),
            { $0.prepend(empty) }
        )
    }

    func testAppendReceiveCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([]),
            { $0.append(1, 2, 3) }
        )
    }

    func testPrependReceiveCompletionBeforeSubscription() {
        let empty = Empty<Int, Never>(completeImmediately: true)
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([.subscription("Concatenate")]),
            { $0.prepend(empty) }
        )
    }

    func testAppendReceiveSubscriptionTwice() throws {
        try testReceiveSubscriptionTwice { $0.append(1, 2, 3) }
    }

    func testCombineIdentifier() throws {
        let subscription1 = CustomSubscription()
        let subscription2 = CustomSubscription()
        let publisher1 = CustomPublisher(subscription: subscription1)
        let publisher2 = CustomPublisher(subscription: subscription2)

        let append = publisher1.append(publisher2)
        var _downstreamSubscription: Subscription?
        let tracking = TrackingSubscriber(
            receiveSubscription: { _downstreamSubscription = $0 },
            receiveValue: { .max($0) },
            receiveCompletion: { _ in }
        )
        append.subscribe(tracking)

        let downstreamSubscription = try XCTUnwrap(_downstreamSubscription)

        let prefixSubscriber = try XCTUnwrap(publisher1.erasedSubscriber)
        XCTAssertEqual(
            downstreamSubscription.combineIdentifier,
            (prefixSubscriber as? CustomCombineIdentifierConvertible)?.combineIdentifier
        )
        XCTAssertNil(publisher2.erasedSubscriber)

        publisher1.send(completion: .finished)

        let suffixSubscriber = try XCTUnwrap(publisher2.erasedSubscriber)
        XCTAssertEqual(
            downstreamSubscription.combineIdentifier,
            (suffixSubscriber as? CustomCombineIdentifierConvertible)?.combineIdentifier
        )

        XCTAssert(type(of: downstreamSubscription) != type(of: prefixSubscriber))
        XCTAssert(type(of: downstreamSubscription) != type(of: suffixSubscriber))
        XCTAssert(type(of: prefixSubscriber)        != type(of: suffixSubscriber))
    }

    func testConcatenateReflection() throws {
        try testReflection(parentInput: Float.self,
                           parentFailure: TestingError.self,
                           description: "Concatenate",
                           customMirror: childrenIsEmpty,
                           playgroundDescription: "Concatenate",
                           { $0.append(2, 3, 5, 7) })

        try testReflection(parentInput: Float.self,
                           parentFailure: TestingError.self,
                           description: "Concatenate",
                           customMirror: childrenIsEmpty,
                           playgroundDescription: "Concatenate",
                           { Empty().append($0) })
    }

    func testConcatenateLifecycle() throws {
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: false,
                          finishingIsPassedThrough: true,
                          { $0.append() })

        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: false,
                          finishingIsPassedThrough: false,
                          { $0.prepend(1, 2, 3) })
    }
}
