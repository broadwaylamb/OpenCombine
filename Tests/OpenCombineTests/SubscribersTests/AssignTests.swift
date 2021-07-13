//
//  AssignTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 15.06.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class AssignTests: XCTestCase {

    private typealias Sut<Root> = Subscribers.Assign<Root, Int>

    private final class TestObject {

        var value: Int = 0

        init() {}
    }

    func testDescription() {
        let object = TestObject()
        let assign = Sut(object: object, keyPath: \.value)

        XCTAssertEqual(assign.description, "Assign TestObject.")
        XCTAssertEqual(assign.playgroundDescription as? String, "Assign TestObject.")
    }

    func testReflection() {
        let object = TestObject()
        let assign = Sut(object: object, keyPath: \.value)

        let children = Array(assign.customMirror.children)

        XCTAssertEqual(children.count, 3)

        guard children.count == 3 else { return }

        XCTAssertEqual(children[0].label, "object")
        XCTAssert(children[0].value as? TestObject === object)

        XCTAssertEqual(children[1].label, "keyPath")
        XCTAssertEqual(children[1].value as? ReferenceWritableKeyPath<TestObject, Int>,
                       \.value)

        XCTAssertEqual(children[2].label, "status")
        XCTAssertNotNil(children[2].value)
    }

    func testSubscription() {

        let object = TestObject()
        let assign = Sut(object: object, keyPath: \.value)

        let subscription1 = CustomSubscription()
        assign.receive(subscription: subscription1)
        XCTAssertEqual(subscription1.history, [.requested(.unlimited)])
        XCTAssertFalse(subscription1.cancelled)

        let subscription2 = CustomSubscription()
        assign.receive(subscription: subscription2)
        XCTAssertFalse(subscription1.cancelled)
        XCTAssertTrue(subscription2.cancelled)

        assign.receive(subscription: subscription1)
        XCTAssertTrue(subscription1.cancelled)

        subscription1.cancelled = false
        assign.receive(completion: .finished)
        XCTAssertFalse(subscription1.cancelled)

        let subscription3 = CustomSubscription()
        assign.receive(subscription: subscription3)
        XCTAssertEqual(subscription3.history, [.cancelled])
        XCTAssertTrue(subscription3.cancelled)

        subscription1.cancelled = false
        assign.cancel()
        XCTAssertFalse(subscription1.cancelled)
    }

    func testReceiveValue() {
        let object = TestObject()
        let assign = Sut(object: object, keyPath: \.value)

        let subscription = CustomSubscription()
        let publisher = CustomPublisherBase<Int, Never>(subscription: subscription)

        XCTAssertEqual(assign.receive(12), .none)
        XCTAssertEqual(object.value, 0)

        publisher.subscribe(assign)
        XCTAssertEqual(publisher.send(42), .none)
        XCTAssertEqual(object.value, 42)

        publisher.send(completion: .finished)
        XCTAssertEqual(object.value, 42)

        XCTAssertEqual(subscription.history, [.requested(.unlimited)])

        XCTAssertEqual(assign.receive(100), .none)
        XCTAssertEqual(object.value, 42)

        publisher.subscribe(assign)
        XCTAssertEqual(publisher.send(1000000), .none)
        XCTAssertEqual(object.value, 42)

        XCTAssertEqual(subscription.history, [.requested(.unlimited),
                                              .cancelled])
    }

    func testPublisherOperator() {
        let object = TestObject()
        let publisher = PassthroughSubject<Int, Never>()

        let cancelable = publisher.assign(to: \.value, on: object)
        XCTAssertEqual(object.value, 0)

        publisher.send(42)
        XCTAssertEqual(object.value, 42)

        cancelable.cancel()
        publisher.send(1)
        XCTAssertEqual(object.value, 42)

        do {
            _ = publisher.assign(to: \.value, on: object)
        }

        publisher.send(100)
        XCTAssertEqual(object.value, 42)
    }

    func testReceiveCompletionWhileCancelling() {
        let cancellable: AnyCancellable

        do {
            let object = ObjectToModify()
            cancellable = object.autofinish.assign(to: \.value, on: object)
        }

        // autofinish is deallocated here, a completion is sent to the sink
        cancellable.cancel()
    }

    func testReceiveCompletionWhileCompleting() {
        let cancellable: AnyCancellable

        let finish: () -> Void

        do {
            let object = ObjectToModify()
            cancellable = object.autofinish.assign(to: \.value, on: object)

            let underlyingPublisher = object.autofinish.publisher

            finish = { underlyingPublisher.send(completion: .finished) }
        }

        finish() // autofinish is deallocated here, a completion is sent to the sink

        cancellable.cancel()
    }
}

final class ObjectToModify {
    let autofinish = AutomaticallyFinish<Int, Never>()
    var value = 0
}
