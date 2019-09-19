//
//  Publishers.Sequence.swift
//  
//
//  Created by Sergej Jaskiewicz on 19.06.2019.
//

extension Publishers {

    /// A publisher that publishes a given sequence of elements.
    ///
    /// When the publisher exhausts the elements in the sequence, the next request
    /// causes the publisher to finish.
    public struct Sequence<Elements: Swift.Sequence, Failure: Error>: Publisher {

        public typealias Output = Elements.Element

        /// The sequence of elements to publish.
        public let sequence: Elements

        /// Creates a publisher for a sequence of elements.
        ///
        /// - Parameter sequence: The sequence of elements to publish.
        public init(sequence: Elements) {
            self.sequence = sequence
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Failure == Downstream.Failure,
                  Elements.Element == Downstream.Input
        {
            if let inner = Inner(downstream: subscriber, sequence: sequence) {
                subscriber.receive(subscription: inner)
            } else {
                subscriber.receive(subscription: Subscriptions.empty)
                subscriber.receive(completion: .finished)
            }
        }
    }
}

extension Publishers.Sequence {

    private final class Inner<Downstream: Subscriber, Elements: Sequence, Failure>
        : Subscription,
          CustomStringConvertible,
          CustomReflectable
        where Downstream.Input == Elements.Element,
              Downstream.Failure == Failure
    {
        typealias Iterator = Elements.Iterator
        typealias Element = Elements.Element

        private var _downstream: Downstream?
        private var _sequence: Elements?
        private var _iterator: Iterator?
        private var _nextValue: Element?

        init?(downstream: Downstream, sequence: Elements) {

            // Early exit if the sequence is empty
            var iterator = sequence.makeIterator()
            guard iterator.next() != nil else { return nil }

            _downstream = downstream
            _sequence = sequence
            _iterator = sequence.makeIterator()
            _nextValue = _iterator?.next()
        }

        var description: String {
            return _sequence.map(String.init(describing:)) ?? "Sequence"
        }

        var customMirror: Mirror {
            let children: CollectionOfOne<(label: String?, value: Any)> =
                .init(("sequence", _sequence ?? [Element]()))
            return Mirror(self, children: children)
        }

        func request(_ demand: Subscribers.Demand) {

            guard let downstream = _downstream else { return }

            var demand = demand

            while demand > 0 {
                if let nextValue = _nextValue {
                    demand += downstream.receive(nextValue)
                    demand -= 1
                }

                _nextValue = _iterator?.next()

                if _nextValue == nil {
                    _downstream?.receive(completion: .finished)
                    cancel()
                    break
                }
            }
        }

        func cancel() {
            _downstream = nil
            _iterator   = nil
            _sequence   = nil
        }
    }
}

extension Publishers.Sequence: Equatable where Elements: Equatable {}

extension Publishers.Sequence where Failure == Never {

    public func min(
        by areInIncreasingOrder: (Elements.Element, Elements.Element) -> Bool
    ) -> Optional<Elements.Element>.OCombine.Publisher {
        return .init(sequence.min(by: areInIncreasingOrder))
    }

    public func max(
        by areInIncreasingOrder: (Elements.Element, Elements.Element) -> Bool
    ) -> Optional<Elements.Element>.OCombine.Publisher {
        return .init(sequence.max(by: areInIncreasingOrder))
    }

    public func first(
        where predicate: (Elements.Element) -> Bool
    ) -> Optional<Elements.Element>.OCombine.Publisher {
        return .init(sequence.first(where: predicate))
    }
}

extension Publishers.Sequence {

    public func allSatisfy(
        _ predicate: (Elements.Element) -> Bool
    ) -> Result<Bool, Failure>.OCombine.Publisher {
        return .init(sequence.allSatisfy(predicate))
    }

    public func tryAllSatisfy(
        _ predicate: (Elements.Element) throws -> Bool
    ) -> Result<Bool, Error>.OCombine.Publisher {
        return .init(Result { try sequence.allSatisfy(predicate) })
    }

    public func collect() -> Result<[Elements.Element], Failure>.OCombine.Publisher {
        return .init(Array(sequence))
    }

    public func compactMap<ElementOfResult>(
        _ transform: (Elements.Element) -> ElementOfResult?
    ) -> Publishers.Sequence<[ElementOfResult], Failure> {
        return .init(sequence: sequence.compactMap(transform))
    }

    public func contains(
        where predicate: (Elements.Element) -> Bool
    ) -> Result<Bool, Failure>.OCombine.Publisher {
        return .init(sequence.contains(where: predicate))
    }

    public func tryContains(
        where predicate: (Elements.Element) throws -> Bool
    ) -> Result<Bool, Error>.OCombine.Publisher {
        return .init(Result { try sequence.contains(where: predicate) })
    }

    public func drop(
        while predicate: (Elements.Element) -> Bool
    ) -> Publishers.Sequence<DropWhileSequence<Elements>, Failure> {
        return .init(sequence: sequence.drop(while: predicate))
    }

    public func dropFirst(
        _ count: Int = 1
    ) -> Publishers.Sequence<DropFirstSequence<Elements>, Failure> {
        return .init(sequence: sequence.dropFirst(count))
    }

    public func filter(
        _ isIncluded: (Elements.Element) -> Bool
    ) -> Publishers.Sequence<[Elements.Element], Failure> {
        return .init(sequence: sequence.filter(isIncluded))
    }

    public func ignoreOutput() -> Empty<Elements.Element, Failure> {
        return .init()
    }

    public func map<ElementOfResult>(
        _ transform: (Elements.Element) -> ElementOfResult
    ) -> Publishers.Sequence<[ElementOfResult], Failure> {
        return .init(sequence: sequence.map(transform))
    }

    public func prefix(
        _ maxLength: Int
    ) -> Publishers.Sequence<PrefixSequence<Elements>, Failure> {
        return .init(sequence: sequence.prefix(maxLength))
    }

    public func prefix(
        while predicate: (Elements.Element) -> Bool
    ) -> Publishers.Sequence<[Elements.Element], Failure> {
        return .init(sequence: sequence.prefix(while: predicate))
    }

    public func reduce<Accumulator>(
        _ initialResult: Accumulator,
        _ nextPartialResult: @escaping (Accumulator, Elements.Element) -> Accumulator
    ) -> Result<Accumulator, Failure>.OCombine.Publisher {
        return .init(sequence.reduce(initialResult, nextPartialResult))
    }

    public func tryReduce<Accumulator>(
        _ initialResult: Accumulator,
        _ nextPartialResult:
            @escaping (Accumulator, Elements.Element) throws -> Accumulator
    ) -> Result<Accumulator, Error>.OCombine.Publisher {
        return .init(Result { try sequence.reduce(initialResult, nextPartialResult) })
    }

    public func replaceNil<ElementOfResult>(
        with output: ElementOfResult
    ) -> Publishers.Sequence<[Elements.Element], Failure>
        where Elements.Element == ElementOfResult?
    {
        return .init(sequence: sequence.map { $0 ?? output })
    }

    public func scan<ElementOfResult>(
        _ initialResult: ElementOfResult,
        _ nextPartialResult:
            @escaping (ElementOfResult, Elements.Element) -> ElementOfResult
    ) -> Publishers.Sequence<[ElementOfResult], Failure> {
        var accumulator = initialResult
        return .init(sequence: sequence.map {
            accumulator = nextPartialResult(accumulator, $0)
            return accumulator
        })
    }

    public func setFailureType<NewFailure: Error>(
        to error: NewFailure.Type
    ) -> Publishers.Sequence<Elements, NewFailure> {
        return .init(sequence: sequence)
    }
}

extension Publishers.Sequence where Elements.Element: Equatable {

    public func removeDuplicates() -> Publishers.Sequence<[Elements.Element], Failure> {
        var previous: Elements.Element?
        var result = [Elements.Element]()
        for element in sequence where element != previous {
            result.append(element)
            previous = element
        }
        return .init(sequence: result)
    }

    public func contains(
        _ output: Elements.Element
    ) -> Result<Bool, Failure>.OCombine.Publisher {
        return .init(sequence.contains(output))
    }
}

extension Publishers.Sequence where Failure == Never, Elements.Element: Comparable {

    public func min() -> Optional<Elements.Element>.OCombine.Publisher {
        return .init(sequence.min())
    }

    public func max() -> Optional<Elements.Element>.OCombine.Publisher {
        return .init(sequence.max())
    }
}

extension Publishers.Sequence where Elements: Collection, Failure == Never {

    public func first() -> Optional<Elements.Element>.OCombine.Publisher {
        return .init(sequence.first)
    }

    public func output(
        at index: Elements.Index
    ) -> Optional<Elements.Element>.OCombine.Publisher {
        return .init(sequence.indices.contains(index) ? sequence[index] : nil)
    }
}

extension Publishers.Sequence where Elements: Collection {

    public func count() -> Result<Int, Failure>.OCombine.Publisher {
        return .init(sequence.count)
    }

    public func output(
        in range: Range<Elements.Index>
    ) -> Publishers.Sequence<[Elements.Element], Failure> {
        return .init(sequence: Array(sequence[range]))
    }
}

extension Publishers.Sequence where Elements: BidirectionalCollection, Failure == Never {

    public func last() -> Optional<Elements.Element>.OCombine.Publisher {
        return .init(sequence.last)
    }

    public func last(
        where predicate: (Elements.Element) -> Bool
    ) -> Optional<Elements.Element>.OCombine.Publisher {
        return .init(sequence.last(where: predicate))
    }
}

extension Publishers.Sequence where Elements: RandomAccessCollection, Failure == Never {

    public func output(
        at index: Elements.Index
    ) -> Optional<Elements.Element>.OCombine.Publisher {
        return .init(sequence.indices.contains(index) ? sequence[index] : nil)
    }

    public func count() -> Just<Int> {
        return .init(sequence.count)
    }
}

extension Publishers.Sequence where Elements: RandomAccessCollection {

    public func output(
        in range: Range<Elements.Index>
    ) -> Publishers.Sequence<[Elements.Element], Failure> {
        return .init(sequence: Array(sequence[range]))
    }

    public func count() -> Result<Int, Failure>.OCombine.Publisher {
        return .init(sequence.count)
    }
}

extension Publishers.Sequence where Elements: RangeReplaceableCollection {

    public func prepend(
        _ elements: Elements.Element...
    ) -> Publishers.Sequence<Elements, Failure> {
        return prepend(elements)
    }

    public func prepend<OtherSequence: Sequence>(
        _ elements: OtherSequence
    ) -> Publishers.Sequence<Elements, Failure>
        where OtherSequence.Element == Elements.Element
    {
        var result = Elements()
        result.reserveCapacity(
            sequence.count + elements.underestimatedCount
        )
        result.append(contentsOf: elements)
        result.append(contentsOf: sequence)
        return .init(sequence: result)
    }

    public func prepend(
        _ publisher: Publishers.Sequence<Elements, Failure>
    ) -> Publishers.Sequence<Elements, Failure> {
        var result = publisher.sequence
        result.append(contentsOf: sequence)
        return .init(sequence: result)
    }

    public func append(
        _ elements: Elements.Element...
    ) -> Publishers.Sequence<Elements, Failure> {
        return append(elements)
    }

    public func append<OtherSequence: Sequence>(
        _ elements: OtherSequence
    ) -> Publishers.Sequence<Elements, Failure>
        where OtherSequence.Element == Elements.Element
    {
        var result = sequence
        result.append(contentsOf: elements)
        return .init(sequence: result)
    }

    public func append(
        _ publisher: Publishers.Sequence<Elements, Failure>
    ) -> Publishers.Sequence<Elements, Failure> {
        return append(publisher.sequence)
    }
}

extension Sequence {

    public var publisher: Publishers.Sequence<Self, Never> {
        return .init(sequence: self)
    }
}
