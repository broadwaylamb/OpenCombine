//
//  ZipTests.swift
//
//  Created by Eric Patey on 28.08.20019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class ZipTests: XCTestCase {
    static let arities = (2...4)

    struct ChildInfo {
        let subscription: CustomSubscription
        let publisher: CustomPublisher
    }

    func testSendsExpectedValues() {
        ZipTests.arities.forEach { arity in
            let (children, zip) = getChildrenAndZipForArity(arity)

            let downstreamSubscriber = TrackingSubscriber(receiveSubscription: {
                $0.request(.unlimited)
            })

            zip.subscribe(downstreamSubscriber)

            (0..<arity).forEach { XCTAssertEqual(children[$0].publisher.send(1), .none) }

            XCTAssertEqual(downstreamSubscriber.history, [.subscription("Zip"),
                                                          .value(arity)])
        }
    }

    func testChildDemand() {
        [Subscribers.Demand.unlimited, .max(1)].forEach { initialDemand in
            let (children, zip) = getChildrenAndZipForArity(2)

            var downstreamSubscription: Subscription?
            let downstreamSubscriber = TrackingSubscriberBase<Int, TestingError>(
                receiveSubscription: { downstreamSubscription = $0 })

            zip.subscribe(downstreamSubscriber)

            // Confirm initial demand
            downstreamSubscription?.request(initialDemand)
            (0..<2).forEach { XCTAssertEqual(children[$0].subscription.history,
                                             [.requested(initialDemand)])
            }

            // Confirm no incremental demand
            (0..<2).forEach { XCTAssertEqual(children[$0].publisher.send(1), .max(0)) }

            // Confirm no additional subscription demand
            (0..<2).forEach { XCTAssertEqual(children[$0].subscription.history,
                                             [.requested(initialDemand)])
            }

            // Confirm value was sent
            XCTAssertEqual(downstreamSubscriber.history, [.subscription("Zip"),
                                                          .value(2)])

            // Confirm subsequent demand
            downstreamSubscription?.request(.max(2))
            (0..<2).forEach { XCTAssertEqual(children[$0].subscription.history,
                                             [.requested(initialDemand),
                                              .requested(.max(2))])
            }
        }
    }

    func testDownstreamDemandRequestedWhileSendingValue() {
        [Subscribers.Demand.unlimited, .max(10)].forEach { initialDemand in
            let (children, zip) = getChildrenAndZipForArity(2)
            var downstreamSubscription: Subscription?
            let downstreamSubscriber = TrackingSubscriber(
                receiveSubscription: {
                    downstreamSubscription = $0
                    $0.request(initialDemand)
                },
                receiveValue: { _ in
                    downstreamSubscription?.request(.max(666))
                    return Subscribers.Demand.none
                }
            )

            zip.subscribe(downstreamSubscriber)

            XCTAssertEqual(children[0].publisher.send(1), .none)
            // Apple will use the result of .receive(_ input:) INSTEAD of sending
            // .request to the subscription if a request is received WHILE processing
            // the .receive.
            // AppleRef: 001
            XCTAssertEqual(children[1].publisher.send(1), .max(666))

            XCTAssertEqual(children[0].subscription.history,
                           [.requested(initialDemand),
                            .requested(.max(666))])
            XCTAssertEqual(children[1].subscription.history,
                           [.requested(initialDemand)])
        }
    }

    func testUpstreamValueReceivedWhileSendingValue() {
        let (children, zip) = getChildrenAndZipForArity(2)

        let downstreamSubscriber = TrackingSubscriber(
            receiveSubscription: { $0.request(.unlimited) },
            receiveValue: { _ in
                XCTAssertEqual(children[0].publisher.send(1), .none)
                return Subscribers.Demand.none
            }
        )

        zip.subscribe(downstreamSubscriber)

        XCTAssertEqual(children[0].publisher.send(1), .none)
        XCTAssertEqual(children[1].publisher.send(1), .none)

        XCTAssertEqual(downstreamSubscriber.history, [.subscription("Zip"),
                                                      .value(2)])
    }

    func testUpstreamFinishReceivedWhileSendingValue() {
        let (children, zip) = getChildrenAndZipForArity(2)

        let downstreamSubscriber = TrackingSubscriber(
            receiveSubscription: { $0.request(.unlimited) },
            receiveValue: { _ in
            children[0].publisher.send(completion: .finished)
                return Subscribers.Demand.none
            }
        )

        zip.subscribe(downstreamSubscriber)

        XCTAssertEqual(children[0].publisher.send(1), .none)
        XCTAssertEqual(children[0].publisher.send(1), .none)
        XCTAssertEqual(children[1].publisher.send(1), .none)

        XCTAssertEqual(downstreamSubscriber.history, [.subscription("Zip"),
                                                      .value(2)])
    }

    // NOTE about how/when Apple sends .finished on `Zip`.
    //
    // The documentation says:
    //      If either upstream publisher finishes successfuly or fails with an error,
    //      the zipped publisher does the same.
    //
    // This may be true for`.failed`, but it just isn't true for `.finished`.
    // The combination of tests in here confirm Apple's actual behavior. An assesment
    // is made to determine if it is possible for the `Zip` to send any more values
    // downstream. Roughly speaking, if any children required to provide component
    // values for the next value have finished, then it will be impossible for `Zip`
    // to send any more values.
    // This assessment is slightly complicated by the fact that `Zip` buffers _surplus_
    // component values while waiting to complete the entire tuple.
    //
    // AppleRef: 002 The algorithm is currently further complicated by the fact that this
    // assessment is not made continuously, but rather only when one of the child
    // subcriptions sends a `.finished`. This means that Apple's behavior is inconsistent.
    // Sometimes, the `Zip` remains alive even though no futher emissions are possible.
    // Sometimes it finishes. Ugh.
    //
    // If I were in charge, `Zip` would finish as soon as it becomes impossible for it
    // to send another value - regarless of what triggers that change in state.

    func testZipCompletesOnlyAfterAllChildrenComplete() {
        let upstreamSubscription = CustomSubscription()
        let child1Publisher = CustomPublisher(subscription: upstreamSubscription)
        let child2Publisher = CustomPublisher(subscription: upstreamSubscription)

        let zip = child1Publisher.zip(child2Publisher) { $0 + $1 }

        let downstreamSubscriber = TrackingSubscriberBase<Int, TestingError>(
            receiveSubscription: { $0.request(.unlimited) })

        zip.subscribe(downstreamSubscriber)

        XCTAssertEqual(child1Publisher.send(100), .none)
        XCTAssertEqual(child1Publisher.send(200), .none)
        XCTAssertEqual(child1Publisher.send(300), .none)
        XCTAssertEqual(child2Publisher.send(1), .none)
        child1Publisher.send(completion: .finished)

        XCTAssertEqual(downstreamSubscriber.history, [.subscription("Zip"),
                                                      .value(101)])

        XCTAssertEqual(child2Publisher.send(2), .none)
        XCTAssertEqual(child2Publisher.send(3), .none)
        // This is so bogus. So, even though no further values are possible, Apple delays
        // the completion. It seems to consider the fact that no more values are possible
        // ONLY after one child sends a .finished
        // Ref: 53EB
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("Zip"),
                                                      .value(101),
                                                      .value(202),
                                                      .value(303)])

        child2Publisher.send(completion: .finished)
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("Zip"),
                                                      .value(101),
                                                      .value(202),
                                                      .value(303),
                                                      .completion(.finished)])

        XCTAssertEqual(
            upstreamSubscription.history,
            [.requested(.unlimited), .requested(.unlimited)]
        )
    }

    func testUpstreamExceedsDemand() {
        // Must use CustomPublisher if we want to force send a value beyond the demand
        let child1Subscription = CustomSubscription()
        let child1Publisher = CustomPublisher(subscription: child1Subscription)
        let child2Subscription = CustomSubscription()
        let child2Publisher = CustomPublisher(subscription: child2Subscription)

        let zip = child1Publisher.zip(child2Publisher) { $0 + $1 }

        var downstreamSubscription: Subscription?
        let downstreamSubscriber = TrackingSubscriber(receiveSubscription: {
            downstreamSubscription = $0
            $0.request(.max(1))
        })

        zip.subscribe(downstreamSubscriber)

        XCTAssertEqual(child1Publisher.send(100), .none)
        XCTAssertEqual(child2Publisher.send(1), .none)
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("Zip"),
                                                      .value(101)])

        XCTAssertEqual(child1Publisher.send(200), .none)
        XCTAssertEqual(child1Publisher.send(300), .none)
        XCTAssertEqual(child2Publisher.send(2), .none)
        // Surplus is sent downstream despite demand of zero
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("Zip"),
                                                      .value(101),
                                                      .value(202)])

        XCTAssertEqual(child2Publisher.send(3), .none)
        downstreamSubscription?.request(.max(1))
        // Surplus is buffered for sending when demand resumes
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("Zip"),
                                                      .value(101),
                                                      .value(202),
                                                      .value(303)])
    }

    private func getChildrenAndZipForArity(_ childCount: Int)
        -> ([ChildInfo], AnyPublisher<Int, TestingError>)
    {
        var children = [ChildInfo]()
        for _ in (0..<childCount) {
            let subscription = CustomSubscription()
            let publisher = CustomPublisher(subscription: subscription)
            children.append(ChildInfo(subscription: subscription,
                                      publisher: publisher))
        }

        let zip: AnyPublisher<Int, TestingError>

        switch childCount {
        case 2:
            zip = AnyPublisher(children[0].publisher.zip(children[1].publisher)
            { $0 + $1 })
        case 3:
            zip = AnyPublisher(children[0].publisher
                .zip(children[1].publisher,
                     children[2].publisher) { $0 + $1 + $2 })
        case 4:
            zip = AnyPublisher(children[0].publisher
                .zip(children[1].publisher,
                     children[2].publisher,
                     children[3].publisher) { $0 + $1 + $2 + $3 })
        default:
            fatalError()
        }

        return (children, zip)
    }

    func testImmediateFinishWhenOneChildFinishesWithNoSurplus() {
        ZipTests.arities.forEach { arity in
            for childToFinish in (0..<arity) {
                let description = "Zip\(arity) childToFinish=\(childToFinish)"
                let (children, zip) = getChildrenAndZipForArity(arity)
                let downstreamSubscriber = TrackingSubscriber(receiveSubscription: {
                    $0.request(.unlimited)
                })

                zip.subscribe(downstreamSubscriber)

                children[childToFinish].publisher.send(completion: .finished)
                XCTAssertEqual(downstreamSubscriber.history,
                               [.subscription("Zip"),
                                .completion(.finished)],
                               description)

                for child in (0..<arity) {
                    if child == childToFinish {
                        XCTAssertEqual(children[child].subscription.history,
                                       [.requested(.unlimited)],
                                       description)
                    } else {
                        XCTAssertEqual(children[child].subscription.history,
                                       [.requested(.unlimited),
                                        .cancelled],
                                       description)
                    }
                }
            }
        }
    }

    // NOTE: This behavior betrays Apple's comments which say:
    //      If either upstream publisher finishes successfuly or fails with an error,
    //      the zipped publisher does the same.
    // That appears to not be true for finishing successfully if the completing child
    // has a surplus. Rather, the zip remains alive until it is impossible to deliver
    // another result.
    func testDelayedFinishWhenOneChildFinishesWithSurplus() {
        ZipTests.arities.forEach { arity in
            for childToSend in (0..<arity) {
                for childToFinish in (0..<arity) {
                    let (children, zip) = getChildrenAndZipForArity(arity)

                    let downstreamSubscriber = TrackingSubscriber(receiveSubscription: {
                        $0.request(.unlimited)
                    })

                    zip.subscribe(downstreamSubscriber)

                    _ = children[childToSend].publisher.send(666)

                    children[childToFinish].publisher.send(completion: .finished)
                    if childToSend == childToFinish {
                        XCTAssertEqual(downstreamSubscriber.history,
                                       [.subscription("Zip")])
                        // Finish the others
                        (0..<arity)
                            .filter { $0 != childToFinish }
                            .forEach( {
                                children[$0].publisher.send(completion: .finished)
                            })

                        XCTAssertEqual(downstreamSubscriber.history,
                                       [.subscription("Zip"),
                                        .completion(.finished)])
                    } else {
                        XCTAssertEqual(downstreamSubscriber.history,
                                       [.subscription("Zip"),
                                        .completion(.finished)])
                    }
                }
            }
        }
    }

    func testBCancelledAfterAFailed() {
        let child1Subscription = CustomSubscription()
        let child1Publisher = CustomPublisher(subscription: child1Subscription)

        let child2Subscription = CustomSubscription()
        let child2Publisher = CustomPublisher(subscription: child2Subscription)

        let zip = child1Publisher.zip(child2Publisher) { $0 + $1 }

        let downstreamSubscriber = TrackingSubscriber(receiveSubscription: {
            $0.request(.unlimited)
        })

        zip.subscribe(downstreamSubscriber)

        child1Publisher.send(completion: .failure(.oops))
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("Zip"),
                                                      .completion(.failure(.oops))])

        XCTAssertEqual(child1Subscription.history, [.requested(.unlimited),
                                                    .cancelled])

        XCTAssertEqual(child2Subscription.history, [.requested(.unlimited),
                                                    .cancelled])
    }

    func testAValueAfterAChildFinishedWithoutSurplus() {
        let child1Publisher = PassthroughSubject<Int, TestingError>()
        let child2Publisher = PassthroughSubject<Int, TestingError>()

        let zip = child1Publisher.zip(child2Publisher) { $0 + $1 }

        let downstreamSubscriber = TrackingSubscriber(
            receiveSubscription: { $0.request(.unlimited) })

        zip.subscribe(downstreamSubscriber)
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("Zip")])

        child1Publisher.send(completion: .finished)
        // This is strange and inconsistent. In other cases, zip doesn't complete
        // until ALL children have completed
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("Zip"),
                                                      .completion(.finished)])

        child1Publisher.send(200)
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("Zip"),
                                                      .completion(.finished)])

        child2Publisher.send(1)
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("Zip"),
                                                      .completion(.finished)])

        child2Publisher.send(completion: .finished)
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("Zip"),
                                                      .completion(.finished)])
    }

    func testBValueAfterAChildFinishedWithoutSurplus() {
        let child1Publisher = PassthroughSubject<Int, TestingError>()
        let child2Publisher = PassthroughSubject<Int, TestingError>()

        let zip = child1Publisher.zip(child2Publisher) { $0 + $1 }

        let downstreamSubscriber = TrackingSubscriber(
            receiveSubscription: { $0.request(.unlimited) })

        zip.subscribe(downstreamSubscriber)
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("Zip")])

        child1Publisher.send(completion: .finished)
        // This is strange and inconsistent. In other cases, zip doesn't complete
        // until ALL children have completed
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("Zip"),
                                                      .completion(.finished)])

        child2Publisher.send(1)
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("Zip"),
                                                      .completion(.finished)])

        child2Publisher.send(completion: .finished)
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("Zip"),
                                                      .completion(.finished)])
    }

    func testAValueAfterAChildFinishedWithSurplus() {
        let child1Publisher = PassthroughSubject<Int, TestingError>()
        let child2Publisher = PassthroughSubject<Int, TestingError>()

        let zip = child1Publisher.zip(child2Publisher) { $0 + $1 }

        let downstreamSubscriber = TrackingSubscriber(
            receiveSubscription: { $0.request(.unlimited) })

        zip.subscribe(downstreamSubscriber)

        child1Publisher.send(100)
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("Zip")])

        child1Publisher.send(completion: .finished)
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("Zip")])

        child1Publisher.send(200)
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("Zip")])

        child2Publisher.send(1)
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("Zip"),
                                                      .value(101)])

        child2Publisher.send(completion: .finished)
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("Zip"),
                                                      .value(101),
                                                      .completion(.finished)])
    }

    func testBValueAfterAChildFinishedWithSurplus() {
        let child1Publisher = PassthroughSubject<Int, TestingError>()
        let child2Publisher = PassthroughSubject<Int, TestingError>()

        let zip = child1Publisher.zip(child2Publisher) { $0 + $1 }

        let downstreamSubscriber = TrackingSubscriber(
            receiveSubscription: { $0.request(.unlimited) })

        zip.subscribe(downstreamSubscriber)

        child1Publisher.send(100)
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("Zip")])

        child1Publisher.send(completion: .finished)
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("Zip")])

        child2Publisher.send(1)
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("Zip"),
                                                      .value(101)])

        child2Publisher.send(completion: .finished)
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("Zip"),
                                                      .value(101),
                                                      .completion(.finished)])
    }

    func testValueAfterFailed() {
        let child1Publisher = PassthroughSubject<Int, TestingError>()
        let child2Publisher = PassthroughSubject<Int, TestingError>()

        let zip = child1Publisher.zip(child2Publisher) { $0 + $1 }

        let downstreamSubscriber = TrackingSubscriber(
            receiveSubscription: { $0.request(.unlimited) })

        zip.subscribe(downstreamSubscriber)

        child1Publisher.send(100)
        child1Publisher.send(completion: .failure(.oops))
        child2Publisher.send(1)

        XCTAssertEqual(downstreamSubscriber.history, [.subscription("Zip"),
                                                      .completion(.failure(.oops))])
    }

    func testFinishAfterFinished() {
        let child1Publisher = PassthroughSubject<Int, TestingError>()
        let child2Publisher = PassthroughSubject<Int, TestingError>()

        let zip = child1Publisher.zip(child2Publisher) { $0 + $1 }

        let downstreamSubscriber = TrackingSubscriber(
            receiveSubscription: { $0.request(.unlimited) })

        zip.subscribe(downstreamSubscriber)

        child1Publisher.send(completion: .finished)
        child2Publisher.send(completion: .finished)
        child1Publisher.send(completion: .finished)

        XCTAssertEqual(downstreamSubscriber.history, [.subscription("Zip"),
                                                      .completion(.finished)])
    }

    func testFinishAfterFailed() {
        let child1Publisher = PassthroughSubject<Int, TestingError>()
        let child2Publisher = PassthroughSubject<Int, TestingError>()

        let zip = child1Publisher.zip(child2Publisher) { $0 + $1 }

        let downstreamSubscriber = TrackingSubscriber(
            receiveSubscription: { $0.request(.unlimited) })

        zip.subscribe(downstreamSubscriber)

        child1Publisher.send(completion: .failure(.oops))
        child1Publisher.send(completion: .finished)

        XCTAssertEqual(downstreamSubscriber.history, [.subscription("Zip"),
                                                      .completion(.failure(.oops))])
    }

    func testFailedAfterFinished() {
        let child1Publisher = PassthroughSubject<Int, TestingError>()
        let child2Publisher = PassthroughSubject<Int, TestingError>()

        let zip = child1Publisher.zip(child2Publisher) { $0 + $1 }

        let downstreamSubscriber = TrackingSubscriber(
            receiveSubscription: { $0.request(.unlimited) })

        zip.subscribe(downstreamSubscriber)

        child1Publisher.send(completion: .finished)
        child2Publisher.send(completion: .finished)
        child1Publisher.send(completion: .failure(.oops))

        XCTAssertEqual(downstreamSubscriber.history, [.subscription("Zip"),
                                                      .completion(.finished)])
    }

    func testFailedAfterFailed() {
        let child1Publisher = PassthroughSubject<Int, TestingError>()
        let child2Publisher = PassthroughSubject<Int, TestingError>()

        let zip = child1Publisher.zip(child2Publisher) { $0 + $1 }

        let downstreamSubscriber = TrackingSubscriber(
            receiveSubscription: { $0.request(.unlimited) })

        zip.subscribe(downstreamSubscriber)

        child1Publisher.send(completion: .failure(.oops))
        child1Publisher.send(completion: .failure(.oops))

        XCTAssertEqual(downstreamSubscriber.history, [.subscription("Zip"),
                                                      .completion(.failure(.oops))])
    }

    func testZip2Lifecycle() throws {
        let child2Publisher = PassthroughSubject<Int, TestingError>()
        try testLifecycle(sendValue: 42,
                          cancellingSubscriptionReleasesSubscriber: false,
                          { $0.zip(child2Publisher) })
    }

    func testZip3Lifecycle() throws {
        let child2Publisher = PassthroughSubject<Int, TestingError>()
        let child3Publisher = PassthroughSubject<Int, TestingError>()
        try testLifecycle(sendValue: 42,
                          cancellingSubscriptionReleasesSubscriber: false,
                          { $0.zip(child2Publisher, child3Publisher) })
    }

    func testZip4Lifecycle() throws {
        let child2Publisher = PassthroughSubject<Int, TestingError>()
        let child3Publisher = PassthroughSubject<Int, TestingError>()
        let child4Publisher = PassthroughSubject<Int, TestingError>()
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: false,
                          { $0.zip(child2Publisher, child3Publisher, child4Publisher) })
    }

    func testZipReceiveSubscriptionTwice() throws {
        let child2Publisher = PassthroughSubject<Int, TestingError>()

        // Can't use `testReceiveSubscriptionTwice` helper here as `(Int, Int)` output
        // can't be made `Equatable`.
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: nil,
            receiveValueDemand: .none,
            createSut: { $0.zip(child2Publisher) }
        )

        XCTAssertEqual(helper.subscription.history, [])

        let secondSubscription = CustomSubscription()

        try XCTUnwrap(helper.publisher.subscriber)
            .receive(subscription: secondSubscription)

        XCTAssertEqual(secondSubscription.history, [.cancelled])

        try XCTUnwrap(helper.publisher.subscriber)
            .receive(subscription: helper.subscription)

        XCTAssertEqual(helper.subscription.history, [.cancelled])

        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(helper.subscription.history, [.cancelled, .cancelled])

        let thirdSubscription = CustomSubscription()

        try XCTUnwrap(helper.publisher.subscriber)
            .receive(subscription: thirdSubscription)
    }

    func testNoDemandOnSubscriptionCrashes() {
        ZipTests.arities.forEach { arity in
            let (_, zip) = getChildrenAndZipForArity(arity)

            let downstreamSubscriber = TrackingSubscriber(
                receiveSubscription: { subscription in
                    self.assertCrashes { subscription.request(.none) }
                }
            )

            zip.subscribe(downstreamSubscriber)
        }
    }

    func testIncreasedDemand() throws {
        ZipTests.arities.forEach { arity in
            let (children, zip) = getChildrenAndZipForArity(arity)

            let downstreamSubscriber = TrackingSubscriber(
                receiveValue: { _ in
                    .max(1)
                }
            )

            zip.subscribe(downstreamSubscriber)

            (0..<arity).forEach {
                let demand = children[$0].publisher.send(1)
                if $0 == arity - 1 {
                    XCTAssertEqual(demand, .max(1))
                } else {
                    XCTAssertEqual(demand, .none)
                }
            }

            XCTAssertEqual(downstreamSubscriber.history, [.subscription("Zip"),
                                                          .value(arity)])
        }
    }

    func testZipCurrentValueSubject() throws {
        let subject = CurrentValueSubject<Void, Never>(())

        let zip = [42].publisher.zip(subject)

        let downstreamSubscriber = TrackingSubscriberBase<(Int, ()), Never>(
            receiveSubscription: { $0.request(.unlimited) })

        zip.subscribe(downstreamSubscriber)

        let history = downstreamSubscriber.history
        XCTAssertEqual(history.count, 2)

        // tuples aren't Equatable, so matching the elements one by one
        switch history[0] {
        case .subscription("Zip"):
          break
        default:
          XCTFail("Failed to match the first subscription event in \(#function)")
        }

        switch history[1] {
        // swiftlint:disable:next empty_enum_arguments
        case .value((42, ())):
          break
        default:
          XCTFail("Failed to match the value event in \(#function)")
        }
    }
}
