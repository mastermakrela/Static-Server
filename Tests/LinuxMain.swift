import XCTest

import StaticServerTests

var tests = [XCTestCaseEntry]()
tests += StaticServerTests.allTests()
XCTMain(tests)
