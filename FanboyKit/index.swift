//
//  index.swift
//  FanboyKit
//
//  Created by Michael Nisi on 22/11/15.
//  Copyright © 2015 Michael Nisi. All rights reserved.
//

// TODO: Document FanboyKit

import Foundation
import Patron

public enum FanboyError: ErrorType {
  case UnexpectedResult(result: AnyObject?)
  case CancelledByUser
  case InvalidTerm
}

/// Make FanboyError types from NSError types.
func retypeError(error: ErrorType?) -> ErrorType? {
  guard error != nil else {
    return nil
  }
  do {
    throw error!
  } catch let error as NSError {
    switch error.code {
    case -999: return FanboyError.CancelledByUser
    default: return error
    }
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
  func version(cb: (ErrorType?, String?) -> Void) throws -> NSURLSessionTask
  func search(term: String, cb: (ErrorType?, [[String:AnyObject]]?) -> Void) throws -> NSURLSessionTask
  func lookup(guids: [String], cb: (ErrorType?, [[String : AnyObject]]?) -> Void) throws -> NSURLSessionTask
  func suggest(term: String, cb: (ErrorType?, [String]?) -> Void) throws -> NSURLSessionTask
}

public final class Fanboy: FanboyService {
  
  let patron: Patron
  let session: NSURLSession

  public init (URL: NSURL, queue: dispatch_queue_t, session: NSURLSession) {
    self.session = session
    self.patron = PatronClient(URL: URL, queue: queue, session: session)
  }
  
  deinit {
    session.invalidateAndCancel()
  }

  func getPath(
    path: String,
    cb: (ErrorType?,
    [[String:AnyObject]]?) -> Void
  ) throws -> NSURLSessionTask {
    return try patron.get(path) { json, response, error in
      if let er = retypeError(error) {
        cb(er, nil)
      } else if let result = json as? [[String:AnyObject]] {
        cb(nil, result)
      } else {
        cb(FanboyError.UnexpectedResult(result: json), nil)
      }
    }
  }
  
  public func lookup(
    guids: [String],
    cb: (ErrorType?,
    [[String:AnyObject]]?) -> Void
  ) throws -> NSURLSessionTask {
    let query = guids.joinWithSeparator(",")
    let path = "/lookup/\(query)"
    return try getPath(path, cb: cb)
  }
  
  public func search(
    term: String,
    cb: (ErrorType?,
    [[String:AnyObject]]?) -> Void
  ) throws -> NSURLSessionTask {
    let t = try encodeTerm(term)
    let path = "/search/\(t)"
    return try getPath(path, cb: cb)
  }
  
  public func suggest(
    term: String,
    cb: (ErrorType?, [String]?) -> Void
  ) throws -> NSURLSessionTask {
    let t = try encodeTerm(term)
    let path = "/suggest/\(t)"
    return try patron.get(path) { json, response, error in
      if let er = retypeError(error) {
        cb(er, nil)
      } else if let result = json as? [String] {
        cb(nil, result)
      } else {
        cb(FanboyError.UnexpectedResult(result: json), nil)
      }
    }
  }
  
  public func version(cb: (ErrorType?, String?) -> Void) throws -> NSURLSessionTask {
    return try patron.get("/") { json, response, error in
      if let er = retypeError(error) {
        cb(er, nil)
      } else if let version = json?["version"] as? String {
        cb(nil, version)
      } else {
        cb(FanboyError.UnexpectedResult(result: json), nil)
      }
    }
  }
}
