//
//  FanboyKitTests.swift
//  FanboyKitTests
//
//  Created by Michael Nisi on 22/11/15.
//  Copyright © 2015 Michael Nisi. All rights reserved.
//

import XCTest
@testable import FanboyKit

class FanboyTests: XCTestCase {
  var queue: NSOperationQueue!
  var svc: FanboyService!
  var baseURL: NSURL = NSURL(string: "http://localhost:8383")!
  
  override func setUp() {
    super.setUp()
    queue = NSOperationQueue()
    svc = Fanboy(baseURL: baseURL, queue: queue)
  }
  
  override func tearDown() {
    queue.cancelAllOperations()
    svc = nil
    super.tearDown()
  }
}

class FanboyFailureTests: FanboyTests {
  override func setUp() {
    baseURL = NSURL(string: "http://localhost:8385")!
    super.setUp()
  }
  
  func testSuggest() {
    let exp = self.expectationWithDescription("suggest")
    try! svc.suggest("f") { error, terms in
      let er = error as! NSError
      XCTAssertEqual(er.code, -1004)
      XCTAssertNil(terms)
      exp.fulfill()
    }
    self.waitForExpectationsWithTimeout(10) { er in
      XCTAssertNil(er)
    }
  }
  
  func testLookup() {
    let exp = self.expectationWithDescription("lookup")
    try! svc.lookup(["528458508", "974240842"]) { error, feeds in
      let er = error as! NSError
      XCTAssertEqual(er.code, -1004)
      XCTAssertNil(feeds)
      exp.fulfill()
    }
    self.waitForExpectationsWithTimeout(10) { er in
      XCTAssertNil(er)
    }
  }
  
  func testSearch() {
    let exp = self.expectationWithDescription("search")
    try! svc.search("fireball") { error, feeds in
      let er = error as! NSError
      XCTAssertEqual(er.code, -1004)
      XCTAssertNil(feeds)
      exp.fulfill()
    }
    self.waitForExpectationsWithTimeout(10) { er in
      XCTAssertNil(er)
    }
  }
  
  func testVersion() {
    let exp = self.expectationWithDescription("version")
    try! svc.version() { error, version in
      let er = error as! NSError
      XCTAssertEqual(er.code, -1004)
      XCTAssertNil(version)
      exp.fulfill()
    }
    self.waitForExpectationsWithTimeout(10) { er in
      XCTAssertNil(er)
    }
  }
}

class FanboySuccessTests: FanboyTests {
  func testSuggest() {
    let exp = self.expectationWithDescription("suggest")
    func next() {
      try! svc.suggest("f") { error, terms in
        XCTAssertNil(error)
        XCTAssertEqual(terms!, ["fireball"])
        exp.fulfill()
      }
    }
    try! svc.search("fireball") { error, feeds in
      XCTAssertNil(error)
      next()
    }
    self.waitForExpectationsWithTimeout(10) { er in
      XCTAssertNil(er)
    }
  }
  
  let names = ["author", "title", "img100", "guid", "img30", "img60", "img600", "updated"]
  
  func testLookup() {
    let exp = self.expectationWithDescription("lookup")
    let names = self.names
    try! svc.lookup(["528458508", "974240842"]) { error, feeds in
      XCTAssertNil(error)
      XCTAssertEqual(feeds!.count, 2)
      feeds!.forEach() { feed in
        names.forEach() { name in
          XCTAssertNotNil(feed[name])
        }
      }
      exp.fulfill()
    }
    self.waitForExpectationsWithTimeout(10) { er in
      XCTAssertNil(er)
    }
  }
  
  func testSearch() {
    let names = self.names
    let exp = self.expectationWithDescription("search")
    try! svc.search("fireball") { error, feeds in
      XCTAssertNil(error)
      feeds!.forEach() { feed in
        names.forEach() { name in
          XCTAssertNotNil(feed[name])
        }
      }
      exp.fulfill()
    }
    self.waitForExpectationsWithTimeout(10) { er in
      XCTAssertNil(er)
    }
  }
  
  func testVersion() {
    let exp = self.expectationWithDescription("version")
    try! svc.version() { error, version in
      XCTAssertNil(error)
      XCTAssertEqual(version, "2.0.1")
      exp.fulfill()
    }
    self.waitForExpectationsWithTimeout(10) { er in
      XCTAssertNil(er)
    }
  }
}
