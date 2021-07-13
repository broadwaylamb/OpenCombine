// ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
// ┃                                                                                     ┃
// ┃                   Auto-generated from GYB template. DO NOT EDIT!                    ┃
// ┃                                                                                     ┃
// ┃                                                                                     ┃
// ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
//
//  Publishers.CombineLatest.swift.gyb
//  
//
//  Created by Sergej Jaskiewicz on 10.12.2019.
//

// swiftlint:disable generic_type_name
// swiftlint:disable large_tuple

// MARK: - CombineLatest methods on Publisher

extension Publisher {

    /// Subscribes to an additional publisher and publishes a tuple upon
    /// receiving output from either publisher.
    ///
    /// The combined publisher passes through any requests to *all* upstream publishers.
    /// However, it still obeys the demand-fulfilling rule of only sending the request
    /// amount downstream. If the demand isn’t `.unlimited`, it drops values from upstream
    /// publishers. It implements this by using a buffer size of 1 for each upstream, and
    /// holds the most recent value in each buffer.
    /// All upstream publishers need to finish for this publisher to finsh. If an upstream
    /// publisher never publishes a value, this publisher never finishes.
    /// If any of the combined publishers terminates with a failure, this publisher also
    /// fails.
    ///
    /// - Parameters:
    ///   - other: Another publisher to combine with this one.
    /// - Returns: A publisher that receives and combines elements from this and another
    ///   publisher.
    public func combineLatest<P: Publisher>(
        _ other: P
    ) -> Publishers.CombineLatest<Self, P>
        where Failure == P.Failure
    {
        return .init(self, other)
    }

    /// Subscribes to an additional publisher and invokes a closure
    /// upon receiving output from either publisher.
    ///
    /// The combined publisher passes through any requests to *all* upstream publishers.
    /// However, it still obeys the demand-fulfilling rule of only sending the request
    /// amount downstream. If the demand isn’t `.unlimited`, it drops values from upstream
    /// publishers. It implements this by using a buffer size of 1 for each upstream, and
    /// holds the most recent value in each buffer.
    /// All upstream publishers need to finish for this publisher to finsh. If an upstream
    /// publisher never publishes a value, this publisher never finishes.
    /// If any of the combined publishers terminates with a failure, this publisher also
    /// fails.
    ///
    /// - Parameters:
    ///   - other: Another publisher to combine with this one.
    ///   - transform: A closure that receives the most recent value from each publisher
    ///     and returns a new value to publish.
    /// - Returns: A publisher that receives and combines elements from this and another
    ///   publisher.
    public func combineLatest<P: Publisher, Result>(
        _ other: P,
        _ transform: @escaping (Output, P.Output) -> Result
    ) -> Publishers.Map<Publishers.CombineLatest<Self, P>, Result>
        where Failure == P.Failure
    {
        return Publishers.CombineLatest(self, other).map {
            transform($0, $1)
        }
    }
    /// Subscribes to two additional publishers and publishes a tuple upon
    /// receiving output from either publisher.
    ///
    /// The combined publisher passes through any requests to *all* upstream publishers.
    /// However, it still obeys the demand-fulfilling rule of only sending the request
    /// amount downstream. If the demand isn’t `.unlimited`, it drops values from upstream
    /// publishers. It implements this by using a buffer size of 1 for each upstream, and
    /// holds the most recent value in each buffer.
    /// All upstream publishers need to finish for this publisher to finsh. If an upstream
    /// publisher never publishes a value, this publisher never finishes.
    /// If any of the combined publishers terminates with a failure, this publisher also
    /// fails.
    ///
    /// - Parameters:
    ///   - publisher1: A second publisher to combine with this one.
    ///   - publisher2: A third publisher to combine with this one.
    /// - Returns: A publisher that receives and combines elements from this and another
    ///   publisher.
    public func combineLatest<P: Publisher, Q: Publisher>(
        _ publisher1: P,
        _ publisher2: Q
    ) -> Publishers.CombineLatest3<Self, P, Q>
        where Failure == P.Failure,
              P.Failure == Q.Failure
    {
        return .init(self, publisher1, publisher2)
    }

    /// Subscribes to two additional publishers and invokes a closure
    /// upon receiving output from either publisher.
    ///
    /// The combined publisher passes through any requests to *all* upstream publishers.
    /// However, it still obeys the demand-fulfilling rule of only sending the request
    /// amount downstream. If the demand isn’t `.unlimited`, it drops values from upstream
    /// publishers. It implements this by using a buffer size of 1 for each upstream, and
    /// holds the most recent value in each buffer.
    /// All upstream publishers need to finish for this publisher to finsh. If an upstream
    /// publisher never publishes a value, this publisher never finishes.
    /// If any of the combined publishers terminates with a failure, this publisher also
    /// fails.
    ///
    /// - Parameters:
    ///   - publisher1: A second publisher to combine with this one.
    ///   - publisher2: A third publisher to combine with this one.
    ///   - transform: A closure that receives the most recent value from each publisher
    ///     and returns a new value to publish.
    /// - Returns: A publisher that receives and combines elements from this and another
    ///   publisher.
    public func combineLatest<P: Publisher, Q: Publisher, Result>(
        _ publisher1: P,
        _ publisher2: Q,
        _ transform: @escaping (Output, P.Output, Q.Output) -> Result
    ) -> Publishers.Map<Publishers.CombineLatest3<Self, P, Q>, Result>
        where Failure == P.Failure,
              P.Failure == Q.Failure
    {
        return Publishers.CombineLatest3(self, publisher1, publisher2).map {
            transform($0, $1, $2)
        }
    }
    /// Subscribes to three additional publishers and publishes a tuple upon
    /// receiving output from either publisher.
    ///
    /// The combined publisher passes through any requests to *all* upstream publishers.
    /// However, it still obeys the demand-fulfilling rule of only sending the request
    /// amount downstream. If the demand isn’t `.unlimited`, it drops values from upstream
    /// publishers. It implements this by using a buffer size of 1 for each upstream, and
    /// holds the most recent value in each buffer.
    /// All upstream publishers need to finish for this publisher to finsh. If an upstream
    /// publisher never publishes a value, this publisher never finishes.
    /// If any of the combined publishers terminates with a failure, this publisher also
    /// fails.
    ///
    /// - Parameters:
    ///   - publisher1: A second publisher to combine with this one.
    ///   - publisher2: A third publisher to combine with this one.
    ///   - publisher3: A fourth publisher to combine with this one.
    /// - Returns: A publisher that receives and combines elements from this and another
    ///   publisher.
    public func combineLatest<P: Publisher, Q: Publisher, R: Publisher>(
        _ publisher1: P,
        _ publisher2: Q,
        _ publisher3: R
    ) -> Publishers.CombineLatest4<Self, P, Q, R>
        where Failure == P.Failure,
              P.Failure == Q.Failure,
              Q.Failure == R.Failure
    {
        return .init(self, publisher1, publisher2, publisher3)
    }

    /// Subscribes to three additional publishers and invokes a closure
    /// upon receiving output from either publisher.
    ///
    /// The combined publisher passes through any requests to *all* upstream publishers.
    /// However, it still obeys the demand-fulfilling rule of only sending the request
    /// amount downstream. If the demand isn’t `.unlimited`, it drops values from upstream
    /// publishers. It implements this by using a buffer size of 1 for each upstream, and
    /// holds the most recent value in each buffer.
    /// All upstream publishers need to finish for this publisher to finsh. If an upstream
    /// publisher never publishes a value, this publisher never finishes.
    /// If any of the combined publishers terminates with a failure, this publisher also
    /// fails.
    ///
    /// - Parameters:
    ///   - publisher1: A second publisher to combine with this one.
    ///   - publisher2: A third publisher to combine with this one.
    ///   - publisher3: A fourth publisher to combine with this one.
    ///   - transform: A closure that receives the most recent value from each publisher
    ///     and returns a new value to publish.
    /// - Returns: A publisher that receives and combines elements from this and another
    ///   publisher.
    public func combineLatest<P: Publisher, Q: Publisher, R: Publisher, Result>(
        _ publisher1: P,
        _ publisher2: Q,
        _ publisher3: R,
        _ transform: @escaping (Output, P.Output, Q.Output, R.Output) -> Result
    ) -> Publishers.Map<Publishers.CombineLatest4<Self, P, Q, R>, Result>
        where Failure == P.Failure,
              P.Failure == Q.Failure,
              Q.Failure == R.Failure
    {
        return Publishers.CombineLatest4(self, publisher1, publisher2, publisher3).map {
            transform($0, $1, $2, $3)
        }
    }
}

// MARK: - CombineLatest publishers

extension Publishers {

    /// A publisher that receives and combines the latest elements from two
    /// publishers.
    public struct CombineLatest<A: Publisher, B: Publisher>
        : Publisher
        where A.Failure == B.Failure
    {
        public typealias Output = (A.Output, B.Output)

        public typealias Failure = A.Failure

        public let a: A

        public let b: B

        public init(
            _ a: A,
            _ b: B
        ) {
            self.a = a
            self.b = b
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Downstream.Failure == Failure,
                  Downstream.Input == Output
        {
            typealias Inner = CombineLatest2Inner<A.Output,
                                                  B.Output,
                                                  Failure,
                                                  Downstream>
            let inner = Inner(downstream: subscriber, upstreamCount: 2)
            a.subscribe(Inner.Side(index: 0, combiner: inner))
            b.subscribe(Inner.Side(index: 1, combiner: inner))
            subscriber.receive(subscription: inner)
        }
    }

    /// A publisher that receives and combines the latest elements from three
    /// publishers.
    public struct CombineLatest3<A: Publisher, B: Publisher, C: Publisher>
        : Publisher
        where A.Failure == B.Failure,
              B.Failure == C.Failure
    {
        public typealias Output = (A.Output, B.Output, C.Output)

        public typealias Failure = A.Failure

        public let a: A

        public let b: B

        public let c: C

        public init(
            _ a: A,
            _ b: B,
            _ c: C
        ) {
            self.a = a
            self.b = b
            self.c = c
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Downstream.Failure == Failure,
                  Downstream.Input == Output
        {
            typealias Inner = CombineLatest3Inner<A.Output,
                                                  B.Output,
                                                  C.Output,
                                                  Failure,
                                                  Downstream>
            let inner = Inner(downstream: subscriber, upstreamCount: 3)
            a.subscribe(Inner.Side(index: 0, combiner: inner))
            b.subscribe(Inner.Side(index: 1, combiner: inner))
            c.subscribe(Inner.Side(index: 2, combiner: inner))
            subscriber.receive(subscription: inner)
        }
    }

    /// A publisher that receives and combines the latest elements from four
    /// publishers.
    public struct CombineLatest4<A: Publisher, B: Publisher, C: Publisher, D: Publisher>
        : Publisher
        where A.Failure == B.Failure,
              B.Failure == C.Failure,
              C.Failure == D.Failure
    {
        public typealias Output = (A.Output, B.Output, C.Output, D.Output)

        public typealias Failure = A.Failure

        public let a: A

        public let b: B

        public let c: C

        public let d: D

        public init(
            _ a: A,
            _ b: B,
            _ c: C,
            _ d: D
        ) {
            self.a = a
            self.b = b
            self.c = c
            self.d = d
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Downstream.Failure == Failure,
                  Downstream.Input == Output
        {
            typealias Inner = CombineLatest4Inner<A.Output,
                                                  B.Output,
                                                  C.Output,
                                                  D.Output,
                                                  Failure,
                                                  Downstream>
            let inner = Inner(downstream: subscriber, upstreamCount: 4)
            a.subscribe(Inner.Side(index: 0, combiner: inner))
            b.subscribe(Inner.Side(index: 1, combiner: inner))
            c.subscribe(Inner.Side(index: 2, combiner: inner))
            d.subscribe(Inner.Side(index: 3, combiner: inner))
            subscriber.receive(subscription: inner)
        }
    }
}

// MARK: - Equatable conformances

extension Publishers.CombineLatest: Equatable
    where
        A: Equatable,
        B: Equatable {}

extension Publishers.CombineLatest3: Equatable
    where
        A: Equatable,
        B: Equatable,
        C: Equatable {}

extension Publishers.CombineLatest4: Equatable
    where
        A: Equatable,
        B: Equatable,
        C: Equatable,
        D: Equatable {}

// MARK: - Inners

private final class CombineLatest2Inner<Input0,
                                        Input1,
                                        Failure,
                                        Downstream: Subscriber>
    : AbstractCombineLatest<(Input0, Input1), Failure, Downstream>
    where Downstream.Input == (Input0, Input1),
          Downstream.Failure == Failure
{
    override func convert(values: [Any?]) -> (Input0, Input1) {
        return (values[0] as! Input0,
                values[1] as! Input1)
    }
}

private final class CombineLatest3Inner<Input0,
                                        Input1,
                                        Input2,
                                        Failure,
                                        Downstream: Subscriber>
    : AbstractCombineLatest<(Input0, Input1, Input2), Failure, Downstream>
    where Downstream.Input == (Input0, Input1, Input2),
          Downstream.Failure == Failure
{
    override func convert(values: [Any?]) -> (Input0, Input1, Input2) {
        return (values[0] as! Input0,
                values[1] as! Input1,
                values[2] as! Input2)
    }
}

private final class CombineLatest4Inner<Input0,
                                        Input1,
                                        Input2,
                                        Input3,
                                        Failure,
                                        Downstream: Subscriber>
    : AbstractCombineLatest<(Input0, Input1, Input2, Input3), Failure, Downstream>
    where Downstream.Input == (Input0, Input1, Input2, Input3),
          Downstream.Failure == Failure
{
    override func convert(values: [Any?]) -> (Input0, Input1, Input2, Input3) {
        return (values[0] as! Input0,
                values[1] as! Input1,
                values[2] as! Input2,
                values[3] as! Input3)
    }
}
