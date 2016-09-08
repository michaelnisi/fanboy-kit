//
//  FanboyKitTests.swift
//  FanboyKitTests
//
//  Created by Michael Nisi on 22/11/15.
//  Copyright © 2015 Michael Nisi. All rights reserved.
//

import XCTest
import Patron
@testable import FanboyKit

private func delay(ms: Int64 = Int64(arc4random_uniform(10)), cb: () -> Void) {
  let delta = ms * Int64(NSEC_PER_MSEC)
  let when = dispatch_time(DISPATCH_TIME_NOW, delta)
  dispatch_after(when, dispatch_get_main_queue(), cb)
}

private func freshSession() -> NSURLSession {
  let conf = NSURLSessionConfiguration.defaultSessionConfiguration()
  conf.HTTPShouldUsePipelining = true
  conf.requestCachePolicy = .ReloadIgnoringLocalCacheData
  return NSURLSession(configuration: conf)
}

private func freshFanboy(url: NSURL) -> Fanboy {
  let target = dispatch_get_main_queue()
  let session = freshSession()
  let client = Patron(URL: url, session: session, target: target)
  return Fanboy(client: client)
}

final class InternalTests: XCTestCase {
  func testEncodeTerm() {
    let wanted = [
      "abc",
      "abc",
      "abc",
      "abc%20def",
      "abc%20%20def" // TODO: Should inner whitespace be removed here
    ]
    let found = [
      "abc",
      " abc",
      " abc ",
      " abc def ",
      " abc  def"
      ].map {
      try! encodeTerm($0)
    }
    for (i, wantedTerm) in wanted.enumerate() {
      let foundTerm = found[i]
      XCTAssertEqual(foundTerm, wantedTerm)
    }
  }
}

final class FanboyFailureTests: XCTestCase {
  
  var svc: FanboyService!
  
  override func setUp() {
    super.setUp()
    
    let url = NSURL(string: "http://localhost:8385")!
    svc = freshFanboy(url)
  }
  
  override func tearDown() {
    super.tearDown()
  }

  func callbackWithExpression (exp: XCTestExpectation) -> (ErrorType?, Any?) -> Void {
    func cb (error: ErrorType?, result: Any?)-> Void {
      let er = error as! NSError
      XCTAssertEqual(er.code, -1004)
      XCTAssertNil(result)
      
      let (code, _) = svc.status!
      XCTAssertEqual(code, er.code)
      
      exp.fulfill()
    }
    return cb
  }
  
  func testSuggest() {
    let exp = self.expectationWithDescription("suggest")
    let cb = callbackWithExpression(exp)
    try! svc.suggest("f", cb: cb)
    self.waitForExpectationsWithTimeout(10) { er in
      XCTAssertNil(er)
    }
  }
  
  func testLookup() {
    let exp = self.expectationWithDescription("lookup")
    let cb = callbackWithExpression(exp)
    svc.lookup(["528458508", "974240842"], cb: cb)
    self.waitForExpectationsWithTimeout(10) { er in
      XCTAssertNil(er)
    }
  }
  
  func testSearch() {
    let exp = self.expectationWithDescription("search")
    let cb = callbackWithExpression(exp)
    try! svc.search("fireball", cb: cb)
    self.waitForExpectationsWithTimeout(10) { er in
      XCTAssertNil(er)
    }
  }
  
  func testVersion() {
    let exp = self.expectationWithDescription("version")
    let cb = callbackWithExpression(exp)
    svc.version(cb)
    self.waitForExpectationsWithTimeout(10) { er in
      XCTAssertNil(er)
    }
  }
}

class FanboySuccessTests: XCTestCase {
  
  var svc: FanboyService!
  
  override func setUp() {
    super.setUp()

    let url = NSURL(string: "http://localhost:8383")!
    svc = freshFanboy(url)
  }
  
  override func tearDown() {
    svc = nil
    super.tearDown()
  }
  
  func testHost() {
    XCTAssertEqual(svc.host, "localhost")
  }
  
  func testSuggest() {
    let exp = self.expectationWithDescription("suggest")
    func next() {
      try! svc.suggest("f") { error, terms in
        XCTAssertNil(error)
        XCTAssert(terms!.contains("fireball"))
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
  
  func testSuggestWithInvalidQuery() {
    let queries = ["", " "]
    var count = 0
    queries.forEach() { q in
      do {
        try svc.suggest(q) { _, _ in }
      } catch FanboyError.InvalidTerm {
        count += 1
      } catch {
        XCTFail("should not throw unexpected error")
      }
    }
    XCTAssertEqual(count, queries.count)
  }
  
  func testSuggestCancel () {
    let svc = self.svc!
    let exp = self.expectationWithDescription("suggest")
    let term = "f"
    try! svc.suggest(term) { error, terms in
      do {
        throw error!
      } catch FanboyError.CancelledByUser {
      } catch {
        XCTFail("should be expected error")
      }
      XCTAssertNil(terms)
      exp.fulfill()
      }.cancel()
    self.waitForExpectationsWithTimeout(10) { er in
      XCTAssertNil(er)
    }
  }
  
  let names = ["author", "title", "img100", "guid", "img30", "img60", "img600", "updated"]
  
  func testLookup() {
    let exp = self.expectationWithDescription("lookup")
    let names = self.names
    let guids = ["528458508", "974240842"]
    
    // These get cached rather agressively.
    
    svc.lookup(guids) { error, feeds in
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
  
  func testLookupCancel() {
    let svc = self.svc!
    let exp = self.expectationWithDescription("lookup")
    let guids = ["528458508", "974240842"]
    let op = svc.lookup(guids) { error, feeds in
      defer {
        exp.fulfill()
      }
      guard feeds == nil else {
        return
      }
      do {
        throw error!
      } catch FanboyError.CancelledByUser {
      } catch {
        XCTFail("should be expected error")
      }
    }
    delay() {
      op.cancel()
    }
    self.waitForExpectationsWithTimeout(10) { er in
      XCTAssertNil(er)
    }
  }
  
  func testSearch() {
    let names = self.names
    let exp = self.expectationWithDescription("search")
    let term = "fireball"
    try! svc.search(term) { error, feeds in
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
  
  func testSearchtWithInvalidQuery() {
    let queries = ["", " "]
    var count = 0
    queries.forEach() { query in
      do {
        try svc.search(query) { _, _ in }
      } catch FanboyError.InvalidTerm {
        count += 1
      } catch {
        XCTFail("should not throw unexpected error")
      }
    }
    XCTAssertEqual(count, queries.count)
  }
  
  func testSearchCancel () {
    let svc = self.svc!
    let exp = self.expectationWithDescription("search")
    let op = try! svc.search("fireball") { error, feeds in
      defer {
        exp.fulfill()
      }
      guard feeds == nil else {
        return
      }
      do {
        throw error!
      } catch FanboyError.CancelledByUser {
      } catch {
        XCTFail("should be expected error")
      }
    }
    delay() {
      op.cancel()
    }
    self.waitForExpectationsWithTimeout(10) { er in
      XCTAssertNil(er)
    }
  }
  
  func testVersion() {
    let exp = self.expectationWithDescription("version")
    svc.version { error, version in
      XCTAssertNil(error)
      XCTAssertEqual(version, "2.0.6")
      exp.fulfill()
    }
    self.waitForExpectationsWithTimeout(10) { er in
      XCTAssertNil(er)
    }
  }
  
  func testVersionCancel() {
    let svc = self.svc!
    let exp = self.expectationWithDescription("version")
    let op = svc.version { error, version in
      do {
        throw error!
      } catch FanboyError.CancelledByUser {
      } catch {
        XCTFail("should not be unexpected error")
      }
      XCTAssertNil(version)
      exp.fulfill()
    }
    op.cancel()
    self.waitForExpectationsWithTimeout(10) { er in
      XCTAssertNil(er)
    }
  }
}
