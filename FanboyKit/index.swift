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
  case CancelledByUser
  case NoData
  case OlaInitializationFailed
  case InvalidTerm
}

func retypeError(error: ErrorType?) -> ErrorType? {
  guard error != nil else {
    return nil
  }
  do {
    throw error!
  } catch PatronError.CancelledByUser {
    return FanboyError.CancelledByUser
  } catch PatronError.NoData {
    return FanboyError.NoData
  } catch PatronError.OlaInitializationFailed {
    return FanboyError.OlaInitializationFailed
  } catch {
    return error
  }
}

func encodeTerm(term: String) throws -> String {
  let trimmed = term.stringByTrimmingCharactersInSet(
    NSCharacterSet.whitespaceCharacterSet())
  guard trimmed != "" else {
    throw FanboyError.InvalidTerm
  }
  guard let t = trimmed.stringByAddingPercentEncodingWithAllowedCharacters(
    NSCharacterSet.URLHostAllowedCharacterSet()) else {
    throw FanboyError.InvalidTerm
  }
  return t
}

public protocol FanboyService {
  func version(cb: (ErrorType?, String?) -> Void) throws -> NSOperation
  func search(term: String, cb: (ErrorType?, [[String:AnyObject]]?) -> Void) throws -> NSOperation
  func lookup(guids: [String], cb: (ErrorType?, [[String : AnyObject]]?) -> Void) throws -> NSOperation
  func suggest(term: String, cb: (ErrorType?, [String]?) -> Void) throws -> NSOperation
}

public class Fanboy: FanboyService {
  let baseURL: NSURL
  let queue: NSOperationQueue
  let session: NSURLSession

  public init(baseURL: NSURL, queue: NSOperationQueue, session: NSURLSession) {
    self.baseURL = baseURL
    self.queue = queue
    self.session = session
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
      if let er = retypeError(op.error) {
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
    let t = try encodeTerm(term)
    let req = requestWithPath("/search/\(t)")
    let op = operationWithRequest(req)
    addOperation(op, withCallback: cb)
    return op
  }
  
  public func suggest(term: String, cb: (ErrorType?, [String]?) -> Void) throws -> NSOperation {
    let t = try encodeTerm(term)
    let req = requestWithPath("/suggest/\(t)")
    let op = operationWithRequest(req)
    op.completionBlock = { [unowned op] in
      if let er = retypeError(op.error) {
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
      if let er = retypeError(op.error) {
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
