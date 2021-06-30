//
//  ResultPublisherTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 17.06.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class ResultPublisherTests: XCTestCase {

    private typealias Sut<Output> = ResultPublisher<Output, TestingError>

    func testOnceSuccessNoInitialDemand() {
        let success = makePublisher(42)
        let tracking = TrackingSubscriber()
        success.subscribe(tracking)

        XCTAssertEqual(tracking.history, [.subscription("Once")])

        tracking.subscriptions.first?.request(.max(100))
        tracking.subscriptions.first?.request(.max(1))

        XCTAssertEqual(tracking.history, [.subscription("Once"),
                                          .value(42),
                                          .completion(.finished)])
    }

    func testOnceSuccessWithInitialDemand() {
        let just = makePublisher(42)
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.unlimited) })
        just.subscribe(tracking)

        XCTAssertEqual(tracking.history, [.subscription("Once"),
                                          .value(42),
                                          .completion(.finished)])
    }

    func testSuccessCancelOnSubscription() {
        let success = makePublisher(42)
        let tracking = TrackingSubscriber(
            receiveSubscription: { $0.request(.max(1)); $0.cancel() }
        )
        success.subscribe(tracking)

        XCTAssertEqual(tracking.history, [.subscription("Once"),
                                          .value(42),
                                          .completion(.finished)])
    }

    func testOnceFailure() {
        let failure = Sut<Int>("failure" as TestingError)
        let tracking = TrackingSubscriber()
        failure.subscribe(tracking)

        XCTAssertEqual(tracking.history, [.subscription("Empty"),
                                          .completion(.failure("failure"))])
    }

    func testFailureCancelOnSubscription() {
        let failure = Sut<Int>("failure" as TestingError)
        let tracking = TrackingSubscriber(
            receiveSubscription: { $0.cancel() }
        )
        failure.subscribe(tracking)

        XCTAssertEqual(tracking.history, [.subscription("Empty"),
                                          .completion(.failure("failure"))])
    }

    func testRecursion() {
        let success = makePublisher(42)
        var subscription: Subscription?
        let tracking = TrackingSubscriberBase<Int, TestingError>(
            receiveSubscription: {
                subscription = $0
                $0.request(.unlimited)
            },
            receiveValue: { _ in
                subscription?.request(.unlimited)
                return .none
            }
        )
        success.subscribe(tracking)
    }

    func testReflection() throws {

        func testCustomMirror(_ mirror: Mirror) -> Bool {
            return mirror.children.count == 1 &&
                mirror.children.first!.label == nil &&
                (mirror.children.first!.value as? Int) == 42
        }

        try testSubscriptionReflection(description: "Once",
                                       customMirror: expectedChildren((nil, "42")),
                                       playgroundDescription: "Once",
                                       sut: Sut(42))
    }

    func testCrashesOnZeroDemand() {
        assertCrashes {
            let tracking =
                TrackingSubscriberBase<Int, TestingError>(receiveSubscription: {
                    $0.request(.none)
                })
            makePublisher(42).subscribe(tracking)
        }
    }

    func testLifecycle() {
        var deinitCount = 0
        do {
            let once = makePublisher(42)
            let tracking = TrackingSubscriber(onDeinit: { deinitCount += 1 })
            once.subscribe(tracking)
            tracking.subscriptions.first?.cancel()
        }
        XCTAssertEqual(deinitCount, 1)
    }

    func testCustomMirror() throws {
        let publisher = makePublisher(42)
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriber(
            receiveSubscription: { downstreamSubscription = $0 }
        )
        publisher.subscribe(tracking)

        var reflected = ""
        try dump(XCTUnwrap(downstreamSubscription), to: &reflected)

        XCTAssertEqual(reflected, """
        ▿ Once #0
          - 42

        """)
    }

    func testResultPublisherMultiThreaded() throws
    {
      class ExternallyTriggered: Subscriber {
        typealias Input = Int
        typealias Failure = TestingError

        let combineIdentifier = CombineIdentifier()
        var sub: Subscription?

        func receive(subscription: Subscription) { sub = subscription }
        func receive(_ input: Input) -> Subscribers.Demand { return .none }
        func receive(completion: Subscribers.Completion<Failure>) {}

        func request() { sub?.request(.unlimited) }
        func cancel() { sub?.cancel() }
      }

      assertCrashes {
        for i in 1...10000 {
          let pub = makePublisher(i)
//          let pub = Optional.OCombine.Publisher(i)
//          let pub = Just(i)
          let sub = ExternallyTriggered()
          pub.subscribe(sub)
          DispatchQueue.global(qos: .utility).async { sub.request() }
          DispatchQueue.global(qos: .utility).async { sub.cancel() }
        }
      }
    }

    // MARK: - Operator specializations for Once

    func testMinOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(112).min().result, .success(112))
        XCTAssertEqual(Sut<Int>("error").min().result, .failure("error"))

        var count = 0
        let comparator: (Int, Int) -> Bool = { count += 1; return $0 > $1 }
        XCTAssertEqual(Sut<Int>(1).min(by: comparator).result, .success(1))
        XCTAssertEqual(Sut<Int>("error").min(by: comparator).result, .failure("error"))

        XCTAssertEqual(count, 0, "comparator should not be called for min(by:)")
    }

    func testTryMinOperatorSpecialization() {
        var count = 0
        let comparator: (Int, Int) -> Bool = { count += 1; return $0 > $1 }
        let throwingComparator: (Int, Int) throws -> Bool = { _, _ in
            count += 1
            throw TestingError.oops
        }
        XCTAssertEqual(try Sut<Int>(1).tryMin(by: comparator).result.get(), 1)
        assertThrowsError(try Sut<Int>(1).tryMin(by: throwingComparator).result.get(),
                          .oops)
        assertThrowsError(try Sut<Int>(.oops).tryMin(by: throwingComparator).result.get(),
                          .oops)

        XCTAssertEqual(count, 2)
    }

    func testMaxOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(341).max().result, .success(341))
        XCTAssertEqual(Sut<Int>("error").max().result, .failure("error"))

        var count = 0
        let comparator: (Int, Int) -> Bool = { count += 1; return $0 > $1 }
        XCTAssertEqual(Sut<Int>(2).max(by: comparator).result, .success(2))
        XCTAssertEqual(Sut<Int>("error").max(by: comparator).result, .failure("error"))

        XCTAssertEqual(count, 0, "comparator should not be called for max(by:)")
    }

    func testTryMaxOperatorSpecialization() {
        var count = 0
        let comparator: (Int, Int) -> Bool = { count += 1; return $0 > $1 }
        let throwingComparator: (Int, Int) throws -> Bool = { _, _ in
            count += 1
            throw TestingError.oops
        }

        XCTAssertEqual(try Sut<Int>(2).tryMax(by: comparator).result.get(), 2)
        assertThrowsError(try Sut<Int>(2).tryMax(by: throwingComparator).result.get(),
                          .oops)
        assertThrowsError(try Sut<Int>(.oops).tryMax(by: throwingComparator).result.get(),
                          .oops)

        XCTAssertEqual(count, 2)
    }

    func testContainsOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(10).contains(12).result, .success(false))
        XCTAssertEqual(Sut<Int>(10).contains(10).result, .success(true))
        XCTAssertEqual(Sut<Int>("error").contains(12).result, .failure("error"))

        var count = 0
        let predicate: (Int) -> Bool = { count += 1; return $0 < 100 }
        XCTAssertEqual(Sut<Int>(64).contains(where: predicate).result, .success(true))
        XCTAssertEqual(Sut<Int>(112).contains(where: predicate).result, .success(false))
        XCTAssertEqual(Sut<Int>("error").contains(where: predicate).result,
                       .failure("error"))

        XCTAssertEqual(count, 2)
    }

    func testTryContainsOperatorSpecialization() {
        var count = 0
        let predicate: (Int) -> Bool = { count += 1; return $0 > 0 }
        let throwingPredicate: (Int) throws -> Bool = { _ in
            count += 1
            throw TestingError.oops
        }

        XCTAssertFalse(try Sut<Int>(0).tryContains(where: predicate).result.get())
        XCTAssertTrue(try Sut<Int>(1).tryContains(where: predicate).result.get())
        assertThrowsError(
            try Sut<Int>(1).tryContains(where: throwingPredicate).result.get(),
            .oops
        )
        assertThrowsError(
            try Sut<Int>("error").tryContains(where: throwingPredicate).result.get(),
            "error"
        )
        XCTAssertEqual(count, 3)
    }

    func testRemoveDuplicatesOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(1000).removeDuplicates().result, .success(1000))
        XCTAssertEqual(Sut<Int>("error").removeDuplicates().result, .failure("error"))

        var count = 0
        let comparator: (Int, Int) -> Bool = { count += 1; return $0 == $1 }
        XCTAssertEqual(Sut<Int>(44).removeDuplicates(by: comparator).result, .success(44))
        XCTAssertEqual(Sut<Int>("error").removeDuplicates(by: comparator).result,
                       .failure("error"))

        XCTAssertEqual(count,
                       0,
                       "comparator should not be called for removeDuplicates(by:)")
    }

    func testTryRemoveDuplicatesOperatorSpecialization() {
        var count = 0
        let comparator: (Int, Int) -> Bool = { count += 1; return $0 > $1 }
        let throwingComparator: (Int, Int) throws -> Bool = {
            XCTAssertEqual($0, $1)
            count += 1
            throw TestingError.oops
        }

        XCTAssertEqual(try Sut<Int>(44).tryRemoveDuplicates(by: comparator).result.get(),
                       44)
        assertThrowsError(
            try Sut<Int>(44).tryRemoveDuplicates(by: throwingComparator).result.get(),
            .oops
        )
        assertThrowsError(
            try Sut<Int>("error")
                .tryRemoveDuplicates(by: throwingComparator).result.get(),
            "error"
        )

        XCTAssertEqual(count, 2)
    }

    func testAllSatisfyOperatorSpecialization() {
        var count = 0
        let predicate: (Int) -> Bool = { count += 1; return $0 > 0 }
        XCTAssertEqual(Sut<Int>(0).allSatisfy(predicate).result, .success(false))
        XCTAssertEqual(Sut<Int>(1).allSatisfy(predicate).result, .success(true))
        XCTAssertEqual(Sut<Int>("error").allSatisfy(predicate).result, .failure("error"))

        XCTAssertEqual(count, 2)
    }

    func testTryAllSatisfyOperatorSpecialization() {
        var count = 0
        let predicate: (Int) -> Bool = { count += 1; return $0 > 0 }
        let throwingPredicate: (Int) throws -> Bool = { _ in
            count += 1
            throw TestingError.oops
        }

        XCTAssertFalse(try Sut<Int>(0).tryAllSatisfy(predicate).result.get())
        XCTAssertTrue(try Sut<Int>(1).tryAllSatisfy(predicate).result.get())
        assertThrowsError(
            try Sut<Int>(1).tryAllSatisfy(throwingPredicate).result.get(),
            .oops
        )
        assertThrowsError(
            try Sut<Int>("error").tryAllSatisfy(throwingPredicate).result.get(),
            "error"
        )

        XCTAssertEqual(count, 3)
    }

    func testCollectOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(13).collect().result, .success([13]))
        XCTAssertEqual(Sut<Int>("error").collect().result, .failure("error"))
    }

    func testCountOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(10000).count().result, .success(1))
        XCTAssertEqual(Sut<Int>("error").count().result, .failure("error"))
    }

    func testFirstOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(3).first().result, .success(3))
        XCTAssertEqual(Sut<Int>("error").first().result, .failure("error"))
    }

    func testLastOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(4).last().result, .success(4))
        XCTAssertEqual(Sut<Int>("error").last().result, .failure("error"))
    }

    func testIgnoreOutputOperatorSpecialization() {
        XCTAssertTrue(Sut<Double>(13.0).ignoreOutput().completeImmediately)
        XCTAssertTrue(Sut<Double>("error").ignoreOutput().completeImmediately)

        do {
            var completion: Subscribers.Completion<TestingError>?
            _ = Sut<Double>("error").ignoreOutput()
                .sink(receiveCompletion: { completion = $0 },
                      receiveValue: { _ in })

            switch completion {
            case .finished?:
                break
            default:
                XCTFail("ignoreOutput should send 'finished' completion for Once")
            }
        }
    }

    func testMapOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(42).map(String.init).result, .success("42"))
        XCTAssertEqual(Sut<Int>("error").map(String.init).result, .failure("error"))
    }

    func testTryMapOperatorSpecialization() {
        XCTAssertEqual(try Sut<Int>(42).tryMap(String.init).result.get(), "42")
        XCTAssertEqual(try Sut<Int>(42).tryMap(String.init).result.get(), "42")
        assertThrowsError(try Sut<Int>(42).tryMap(throwing).result.get() as Int, "oops")
        assertThrowsError(try Sut<Int>("error").tryMap(throwing).result.get() as Int,
                          "error")
    }

    func testMapErrorOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(42).mapError { _ in TestingError.oops }.result,
                       .success(42))
        XCTAssertEqual(
            Sut<Int>("error")
                .mapError { TestingError(description: $0.description.uppercased()) }
                .result,
            .failure("ERROR")
        )
    }

    func testReplaceErrorOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(1).replaceError(with: 100).result, .success(1))
        XCTAssertEqual(Sut<Int>("error").replaceError(with: 100).result, .success(100))
    }

    func testReplaceEmptyOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(1).replaceEmpty(with: 100).result, .success(1))
        XCTAssertEqual(Sut<Int>("error").replaceEmpty(with: 100).result,
                       .failure("error"))
    }

    func testRetryOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(1).retry(100).result, .success(1))
        XCTAssertEqual(Sut<Int>("error").retry(100).result, .failure("error"))
    }

    func testReduceOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(4).reduce(2, +).result, .success(6))
        XCTAssertEqual(Sut<Int>("error").reduce(2, +).result, .failure("error"))
    }

    func testTryReduceOperatorSpecialization() {
        XCTAssertEqual(try Sut<Int>(4).tryReduce(2, *).result.get(), 8)
        assertThrowsError(try Sut<Int>(4).tryReduce(2, throwing).result.get(), "oops")
        assertThrowsError(try Sut<Int>("error").tryReduce(2, throwing).result.get(),
                          "error")
    }

    func testScanOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(4).scan(2, +).result, .success(6))
        XCTAssertEqual(Sut<Int>("error").scan(2, +).result, .failure("error"))
    }

    func testTryScanOperatorSpecialization() {
        XCTAssertEqual(try Sut<Int>(4).tryScan(2, *).result.get(), 8)
        assertThrowsError(try Sut<Int>(4).tryScan(2, throwing).result.get(), "oops")
        assertThrowsError(try Sut<Int>("error").tryScan(2, throwing).result.get(),
                          "error")
    }

    func testSetFailureTypeOperatorSpecialization() {

        XCTAssertEqual(
            try ResultPublisher<Int, Never>(73)
                .setFailureType(to: TestingError.self)
                .result
                .get(),
            73
        )
    }
}

#if OPENCOMBINE_COMPATIBILITY_TEST || !canImport(Combine)
@available(macOS 10.15, iOS 13.0, *)
typealias ResultPublisher<Output, Failure: Error> =
    Result<Output, Failure>.Publisher

@available(macOS 10.15, iOS 13.0, *)
func makePublisher<Output, Failure: Error>(
    _ result: Result<Output, Failure>
) -> ResultPublisher<Output, Failure> {
    return result.publisher
}
#else
typealias ResultPublisher<Output, Failure: Error> =
    Result<Output, Failure>.OCombine.Publisher

func makePublisher<Output, Failure: Error>(
    _ result: Result<Output, Failure>
) -> ResultPublisher<Output, Failure> {
    return result.ocombine.publisher
}
#endif

@available(macOS 10.15, iOS 13.0, *)
private func makePublisher<Output>(
    _ output: Output
) -> ResultPublisher<Output, TestingError> {
    return makePublisher(.success(output))
}
