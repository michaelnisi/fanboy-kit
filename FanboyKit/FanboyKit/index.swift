//
//  index.swift
//  FanboyKit
//
//  Created by Michael Nisi on 22/11/15.
//  Copyright © 2015 Michael Nisi. All rights reserved.
//

import Foundation
import Patron

public enum FanboyError: ErrorType {
  case UnexpectedResult(result: AnyObject?)
}

public protocol FanboyService {
  func version(cb: (ErrorType?, String?) -> Void) throws -> NSOperation
  func search(term: String, cb: (ErrorType?, [[String:AnyObject]]?) -> Void) throws -> NSOperation
  func lookup(guids: [String], cb: (ErrorType?, [[String : AnyObject]]?) -> Void) throws -> NSOperation
  func suggest(term: String, cb: (ErrorType?, [String]?) -> Void) throws -> NSOperation
}

func defaultSession(scheme: String) throws -> NSURLSession {
  let conf = NSURLSessionConfiguration.defaultSessionConfiguration()
  conf.HTTPShouldUsePipelining = true
  let sess = NSURLSession(configuration: conf)
  return sess
}

public class Fanboy: FanboyService {
  let baseURL: NSURL
  let queue: NSOperationQueue
  
  lazy var session: NSURLSession = {
    return try! defaultSession("http")
  }()

  public init(baseURL: NSURL, queue: NSOperationQueue) {
    self.baseURL = baseURL
    self.queue = queue
  }
  
  func operationWithRequest(req: NSURLRequest) -> PatronOperation {
    let q = dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)
    return PatronOperation(session: session, request: req, queue: q)
  }
  
  func urlWithPath(path: String) -> NSURL {
    return NSURL(string: path, relativeToURL: baseURL)!
  }
  
  func requestWithPath(path: String) -> NSURLRequest {
    let url = urlWithPath(path)
    return NSURLRequest(URL: url)
  }
  
  func addOperation(op: PatronOperation, withCallback cb: (ErrorType?, [[String : AnyObject]]?) -> Void) {
    op.completionBlock = { [unowned op] in
      if let er = op.error {
        cb(er, nil)
      } else if let result = op.result as? [[String : AnyObject]] {
        cb(nil, result)
      } else {
        cb(FanboyError.UnexpectedResult(result: op.result), nil)
      }
    }
    queue.addOperation(op)
  }
  
  public func lookup(guids: [String], cb: (ErrorType?, [[String : AnyObject]]?) -> Void) throws -> NSOperation {
    let query = guids.joinWithSeparator(",")
    let req = requestWithPath("/lookup/\(query)")
    let op = operationWithRequest(req)
    addOperation(op, withCallback: cb)
    return op
  }
  
  public func search(term: String, cb: (ErrorType?, [[String : AnyObject]]?) -> Void) throws -> NSOperation {
    let req = requestWithPath("/search/\(term)")
    let op = operationWithRequest(req)
    addOperation(op, withCallback: cb)
    return op
  }
  
  public func suggest(term: String, cb: (ErrorType?, [String]?) -> Void) throws -> NSOperation {
    let req = requestWithPath("/suggest/\(term)")
    let op = operationWithRequest(req)
    op.completionBlock = { [unowned op] in
      if let er = op.error {
        cb(er, nil)
      } else if let suggestions = op.result as? [String] {
        cb(nil, suggestions)
      } else {
        cb(FanboyError.UnexpectedResult(result: op.result), nil)
      }
    }
    queue.addOperation(op)
    return op
  }

  public func version(cb: (ErrorType?, String?) -> Void) throws -> NSOperation {
    let req = requestWithPath("/")
    let op = operationWithRequest(req)
    op.completionBlock = { [unowned op] in
      if let er = op.error {
        cb(er, nil)
      } else if let version = op.result?["version"] as? String {
        cb(nil, version)
      } else {
        cb(FanboyError.UnexpectedResult(result: op.result), nil)
      }
    }
    queue.addOperation(op)
    return op
  }
}
