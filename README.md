# OpenCombine
[![OpenCombine](https://circleci.com/gh/OpenCombine/OpenCombine.svg?style=svg)](https://circleci.com/gh/OpenCombine/OpenCombine)
[![codecov](https://codecov.io/gh/OpenCombine/OpenCombine/branch/master/graph/badge.svg)](https://codecov.io/gh/OpenCombine/OpenCombine)
![Language](https://img.shields.io/badge/Swift-5.0-orange.svg)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20iOS%20%7C%20watchOS%20%7C%20tvOS%20%7C%20Wasm-lightgrey.svg)
![Cocoapods](https://img.shields.io/cocoapods/v/OpenCombine?color=blue)
[<img src="https://img.shields.io/badge/slack-OpenCombine-yellow.svg?logo=slack">](https://join.slack.com/t/opencombine/shared_invite/enQtNzE2MjE5NzkxODI0LTYxMjkzNDUxZWViZWI1Njc2YjBhODgxNjRjOTdkZTcxOGU2ZjJjZjYxMGI3NWZkN2RkNGFmZTUzNmU3MGE2ZWM)

Open-source implementation of Apple's [Combine](https://developer.apple.com/documentation/combine) framework for processing values over time.

The main goal of this project is to provide a compatible, reliable and efficient implementation which can be used on Apple's operating systems before macOS 10.15 and iOS 13, as well as Linux and WebAssembly.

### Installation
`OpenCombine` contains three public targets: `OpenCombine`, `OpenCombineFoundation` and `OpenCombineDispatch` (the fourth one, `COpenCombineHelpers`, is considered private. Don't import it in your projects).

OpenCombine itself does not have any dependencies. Not even Foundation or Dispatch. If you want to use OpenCombine with Dispatch (for example for using `DispatchQueue` as `Scheduler` for operators like `debounce`, `receive(on:)` etc.), you will need to import both `OpenCombine` and `OpenCombineDispatch`. The same applies to Foundation: if you want to use, for instance, `NotificationCenter` or `URLSession` publishers, you'll need to also import `OpenCombineFoundation`.

If you develop code for multiple platforms, you may find it more convenient to import the
`OpenCombineShim` module instead. It conditionally re-exports Combine on Apple platforms (if
available), and all OpenCombine modules on other platforms. You can import `OpenCombineShim` only
when using SwiftPM. It is not currently available for CocoaPods.

##### Swift Package Manager
###### Swift Package
To add `OpenCombine` to your [SwiftPM](https://swift.org/package-manager/) package, add the `OpenCombine` package to the list of package and target dependencies in your `Package.swift` file. `OpenCombineDispatch` and `OpenCombineFoundation` products are currently not supported on WebAssembly. If your project targets WebAssembly exclusively, you should omit them from the list of your dependencies. If it targets multiple platforms including WebAssembly, depend on them only on non-WebAssembly platforms with [conditional target dependencies](https://github.com/apple/swift-evolution/blob/main/proposals/0273-swiftpm-conditional-target-dependencies.md).

```swift
dependencies: [
    .package(url: "https://github.com/OpenCombine/OpenCombine.git", from: "0.12.0")
],
targets: [
    .target(
        name: "MyAwesomePackage",
        dependencies: [
            "OpenCombine",
            .product(name: "OpenCombineFoundation", package: "OpenCombine"),
            .product(name: "OpenCombineDispatch", package: "OpenCombine")
        ]
    ),
]
```

###### Xcode
`OpenCombine` can also be added as a SwiftPM dependency directly in your Xcode project *(requires Xcode 11 upwards)*.

To do so, open Xcode, use **File** → **Swift Packages** → **Add Package Dependency…**, enter the [repository URL](https://github.com/OpenCombine/OpenCombine.git), choose the latest available version, and activate the checkboxes:

<p align="center">
<img alt="Select the OpenCombine and OpenCombineDispatch targets" 
	src="https://user-images.githubusercontent.com/16309982/67618468-bd379f80-f7f8-11e9-917f-e76e878a1aee.png" width="70%">
</p>

##### CocoaPods
To add `OpenCombine` to a project using [CocoaPods](https://cocoapods.org/), add `OpenCombine` and `OpenCombineDispatch` to the list of target dependencies in your `Podfile`. 

```ruby
pod 'OpenCombine', '~> 0.12.0'
pod 'OpenCombineDispatch', '~> 0.12.0'
pod 'OpenCombineFoundation', '~> 0.12.0'
```

##### Carthage
For [Carthage](https://github.com/Carthage/Carthage), add the following to your `Cartfile`:

```ogdl
github "OpenCombine/OpenCombine" ~> 0.10
```

### Contributing

In order to work on this project you will need Xcode 10.2 and Swift 5.0 or later.

Please refer to the [issue #1](https://github.com/OpenCombine/OpenCombine/issues/1) for the list of operators that remain unimplemented, as well as the [RemainingCombineInterface.swift](https://github.com/OpenCombine/OpenCombine/blob/master/RemainingCombineInterface.swift) file. The latter contains the generated interface of Apple's Combine from the latest Xcode 11 version. When the functionality is implemented in OpenCombine, it should be removed from the RemainingCombineInterface.swift file.

You can refer to [this repo](https://github.com/OpenCombine/combine-interfaces) to observe Apple's Combine API and documentation changes between different Xcode (beta) versions.

You can run compatibility tests against Apple's Combine. In order to do that you will need either macOS 10.14 with iOS 13 simulator installed (since the only way we can get Apple's Combine on macOS 10.14 is using the simulator), or macOS 10.15 (Apple's Combine is bundled with the OS). Execute the following command from the root of the package:

```
$ make test-compatibility
```

Or enable the `-DOPENCOMBINE_COMPATIBILITY_TEST` compiler flag in Xcode's build settings. Note that on iOS only the latter will work.

> NOTE: Before starting to work on some feature, please consult the [GitHub project](https://github.com/OpenCombine/OpenCombine/projects/2) to make sure that nobody's already making progress on the same feature! If not, then please create a draft PR to indicate that you're beginning your work.

#### Releasing a new version

1. Create a new branch from master and call it `release/<major>.<minor>.<patch>`.
1. Replace the usages of the old version in `README.md` with the new version (make sure to check the [Swift Package Manager](#swift-package-manager) and [CocoaPods](#cocoapods) sections).
1. Bump the version in `OpenCombine.podspec`, `OpenCombineDispatch.podspec` and `OpenCombineFoundation.podspec`. In the latter two you will also need to set the `spec.dependency "OpenCombine"` property to the **previous** version. Why? Because otherwise the `pod lib lint` command that we run on our regular CI will fail when validating the `OpenCombineDispatch` and `OpenCombineFoundation` podspecs, since the dependencies are not yet in the trunk. If we set the dependencies to the previous version (which is already in the trunk), everything will be fine. This is purely to make the CI work. The clients will not experience any issues, since the version is specified as `>=`.
1. Create a pull request to master for the release branch and make sure the CI passes.
1. Merge the pull request.
1. In the GitHub web interface on the [releases](https://github.com/OpenCombine/OpenCombine/releases) page, click the **Draft a new release** button.
1. The **Tag version** and **Release title** fields should be filled with the version number.
1. The description of the release should be consistent with the previous releases. It is a good practice to divide the description into several sections: additions, bugfixes, known issues etc. Also, be sure to mention the nicknames of the contributors of the new release.
1. Publish the release.
1. Switch to the master branch and pull the changes.
1. Push the release to CocoaPods trunk. For that, execute the following commands:

    ```
    pod trunk push OpenCombine.podspec --verbose --allow-warnings
    pod trunk push OpenCombineDispatch.podspec --verbose --allow-warnings
    pod trunk push OpenCombineFoundation.podspec --verbose --allow-warnings
    ```
   
   Note that you need to be one of the owners of the pod for that.

#### GYB

Some publishers in OpenCombine (like `Publishers.MapKeyPath`, `Publishers.Merge`) exist in several
different flavors in order to support several arities. For example, there are also `Publishers.MapKeyPath2`
and `Publishers.MapKeyPath3`, which are very similar but different enough that Swift's type system
can't help us here (because there's no support for variadic generics). Maintaining multiple instances of
those generic types is tedious and error-prone (they can get out of sync), so we use the GYB tool for
generating those instances from a template.

GYB is a Python script that evaluates Python code written inside a template file, so it's very flexible —
templates can be arbitrarily complex. There is a good article about GYB on
[NSHipster](https://nshipster.com/swift-gyb/).

GYB is part of the [Swift Open Source Project](https://github.com/apple/swift/blob/master/utils/gyb.py)
and can be distributed under the same license as Swift itself.

GYB template files have the `.gyb` extension. Run `make gyb` to generate Swift code from those
templates. The generated files are prefixed with `GENERATED-`  and are checked into source control. Those
files should never be edited directly. Instead, the `.gyb` template should be edited, and after that the files
should be regenerated using `make gyb`.

#### Debugger Support

The file `opencombine_lldb.py`  defines some `lldb` type summaries for easier debugging. These type summaries improve the way `lldb` and Xcode display some OpenCombine values.

To use `opencombine_lldb.py`, figure out its full path. Let's say the full path is `~/projects/OpenCombine/opencombine_lldb.py`. Then the following statement to your `~/.lldbinit` file:

    command script import ~/projects/OpenCombine/opencombine_lldb.py

Currently, `opencombine_lldb.py` defines type summaries for these types:

- `Subscribers.Demand`
- That's all for now.
