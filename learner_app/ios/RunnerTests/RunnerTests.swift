import Flutter
import UIKit
import XCTest

class RunnerTests: XCTestCase {

  func testExample() {
    // If you add code to the Runner application, consider adding tests here.
    // See https://developer.apple.com/documentation/xctest for more information about using XCTest.
  }

  /// Requirement 2.3 / tasks 2.1, 2.4: `loadModel` validates `modelPath` before file I/O.
  func testNativeLlmPlugin_source_loadModelBadArgsAndCloseAllOrdering() throws {
    let source = try Self.nativePluginSwiftSource()
    XCTAssertTrue(source.contains("case \"loadModel\":"))
    XCTAssertTrue(
      source.contains("code: \"bad_args\"") && source.contains("missing or invalid modelPath"),
    )
    let loadModelDecl = try XCTUnwrap(source.range(of: "private static func loadModel"))
    let tail = source[loadModelDecl.lowerBound...]
    let closeR = try XCTUnwrap(tail.range(of: "closeAll()"))
    let existsR = try XCTUnwrap(tail.range(of: "fileExists(atPath:"))
    XCTAssertLessThan(closeR.lowerBound, existsR.lowerBound)
  }

  /// Requirements 4.4: streaming task is cancelled from `onCancel`.
  func testNativeLlmPlugin_source_streamOnCancelCancelsTask() throws {
    let source = try Self.nativePluginSwiftSource()
    XCTAssertTrue(source.contains("func onCancel(withArguments"))
    XCTAssertTrue(source.contains("streamingTask?.cancel()"))
  }

  /// Requirements 4.2 — iOS stream ends with [FlutterEndOfEventStream].
  func testNativeLlmPlugin_source_iOSEmitsEndOfStream() throws {
    let source = try Self.nativePluginSwiftSource()
    XCTAssertTrue(source.contains("FlutterEndOfEventStream"))
    XCTAssertTrue(source.contains("Task.checkCancellation()"))
  }

  private static func nativePluginSwiftSource() throws -> String {
    let url = URL(fileURLWithPath: #file, isDirectory: false)
      .deletingLastPathComponent()
      .appendingPathComponent("../Runner/NativeLlmPlugin.swift")
    return try String(contentsOf: url, encoding: .utf8)
  }
}
