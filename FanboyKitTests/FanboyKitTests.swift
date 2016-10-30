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

private func delay(_ ms: Int64 = Int64(arc4random_uniform(10)), cb: @escaping () -> Void) {
  let delta = ms * Int64(NSEC_PER_MSEC)
  let when = DispatchTime.now() + Double(delta) / Double(NSEC_PER_SEC)
  DispatchQueue.main.asyncAfter(deadline: when, execute: cb)
}

private func freshSession() -> URLSession {
  let conf = URLSessionConfiguration.default
  conf.httpShouldUsePipelining = true
  conf.requestCachePolicy = .reloadIgnoringLocalCacheData
  return URLSession(configuration: conf)
}

private func freshFanboy(_ url: NSURL) -> Fanboy {
  let target = DispatchQueue.main
  let session = freshSession()
  let client = Patron(URL: url as URL, session: session, target: target)
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
    for (i, wantedTerm) in wanted.enumerated() {
      let foundTerm = found[i]
      XCTAssertEqual(foundTerm, wantedTerm)
    }
  }
}

final class FanboyFailureTests: XCTestCase {
  
  var svc: FanboyService!
  
  override func setUp() {
    super.setUp()
    
    let url = URL(string: "http://localhost:8385")!
    svc = freshFanboy(url as NSURL)
  }
  
  override func tearDown() {
    super.tearDown()
  }

  func callbackWithExpression (_ exp: XCTestExpectation) -> (Error?, Any?) -> Void {
    func cb (_ error: Error?, result: Any?)-> Void {
      let er = error as! NSError
      XCTAssertEqual(er.code, -1004)
      XCTAssertNil(result)
      
      let (code, _) = svc.client.status!
      XCTAssertEqual(code, er.code)
      
      exp.fulfill()
    }
    return cb
  }
  
  func testSuggest() {
    let exp = self.expectation(description: "suggest")
    let cb = callbackWithExpression(exp)
    try! svc.suggest("f", cb: cb)
    self.waitForExpectations(timeout: 10) { er in
      XCTAssertNil(er)
    }
  }
  
  func testLookup() {
    let exp = self.expectation(description: "lookup")
    let cb = callbackWithExpression(exp)
    svc.lookup(["528458508", "974240842"], cb: cb)
    self.waitForExpectations(timeout: 10) { er in
      XCTAssertNil(er)
    }
  }
  
  func testSearch() {
    let exp = self.expectation(description: "search")
    let cb = callbackWithExpression(exp)
    try! svc.search("fireball", cb: cb)
    self.waitForExpectations(timeout: 10) { er in
      XCTAssertNil(er)
    }
  }
  
  func testVersion() {
    let exp = self.expectation(description: "version")
    let cb = callbackWithExpression(exp)
    svc.version(cb)
    self.waitForExpectations(timeout: 10) { er in
      XCTAssertNil(er)
    }
  }
}

class FanboySuccessTests: XCTestCase {
  
  var svc: FanboyService!
  
  override func setUp() {
    super.setUp()

    let url = URL(string: "http://localhost:8383")!
    svc = freshFanboy(url as NSURL)
  }
  
  override func tearDown() {
    svc = nil
    super.tearDown()
  }
  
  func testHost() {
    XCTAssertEqual(svc.client.host, "localhost")
  }
  
  func testSuggest() {
    let exp = self.expectation(description: "suggest")
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
    self.waitForExpectations(timeout: 10) { er in
      XCTAssertNil(er)
    }
  }
  
  func testSuggestWithInvalidQuery() {
    let queries = ["", " "]
    var count = 0
    queries.forEach() { q in
      do {
        try svc.suggest(q) { _, _ in }
      } catch FanboyError.invalidTerm {
        count += 1
      } catch {
        XCTFail("should not throw unexpected error")
      }
    }
    XCTAssertEqual(count, queries.count)
  }
  
  func testSuggestCancel () {
    let svc = self.svc!
    let exp = self.expectation(description: "suggest")
    let term = "f"
    try! svc.suggest(term) { error, terms in
      do {
        throw error!
      } catch FanboyError.cancelledByUser {
      } catch {
        XCTFail("should be expected error")
      }
      XCTAssertNil(terms)
      exp.fulfill()
      }.cancel()
    self.waitForExpectations(timeout: 10) { er in
      XCTAssertNil(er)
    }
  }
  
  let names = ["author", "title", "img100", "guid", "img30", "img60", "img600", "updated"]
  
  func testLookup() {
    let exp = self.expectation(description: "lookup")
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
    self.waitForExpectations(timeout: 10) { er in
      XCTAssertNil(er)
    }
  }
  
  func testLookupCancel() {
    let svc = self.svc!
    let exp = self.expectation(description: "lookup")
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
      } catch FanboyError.cancelledByUser {
      } catch {
        XCTFail("should be expected error")
      }
    }
    delay() {
      op.cancel()
    }
    self.waitForExpectations(timeout: 10) { er in
      XCTAssertNil(er)
    }
  }
  
  func testSearch() {
    let names = self.names
    let exp = self.expectation(description: "search")
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
    self.waitForExpectations(timeout: 10) { er in
      XCTAssertNil(er)
    }
  }
  
  func testSearchtWithInvalidQuery() {
    let queries = ["", " "]
    var count = 0
    queries.forEach() { query in
      do {
        try svc.search(query) { _, _ in }
      } catch FanboyError.invalidTerm {
        count += 1
      } catch {
        XCTFail("should not throw unexpected error")
      }
    }
    XCTAssertEqual(count, queries.count)
  }
  
  func testSearchCancel () {
    let svc = self.svc!
    let exp = self.expectation(description: "search")
    let op = try! svc.search("fireball") { error, feeds in
      defer {
        exp.fulfill()
      }
      guard feeds == nil else {
        return
      }
      do {
        throw error!
      } catch FanboyError.cancelledByUser {
      } catch {
        XCTFail("should be expected error")
      }
    }
    delay() {
      op.cancel()
    }
    self.waitForExpectations(timeout: 10) { er in
      XCTAssertNil(er)
    }
  }
  
  func testVersion() {
    let exp = self.expectation(description: "version")
    svc.version { error, version in
      XCTAssertNil(error)
      XCTAssertEqual(version, "2.0.6")
      exp.fulfill()
    }
    self.waitForExpectations(timeout: 10) { er in
      XCTAssertNil(er)
    }
  }
  
  func testVersionCancel() {
    let svc = self.svc!
    let exp = self.expectation(description: "version")
    let op = svc.version { error, version in
      do {
        throw error!
      } catch FanboyError.cancelledByUser {
      } catch {
        XCTFail("should not be unexpected error")
      }
      XCTAssertNil(version)
      exp.fulfill()
    }
    op.cancel()
    self.waitForExpectations(timeout: 10) { er in
      XCTAssertNil(er)
    }
  }
}
