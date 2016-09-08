//
//  index.swift
//  FanboyKit
//
//  Created by Michael Nisi on 22/11/15.
//  Copyright © 2015 Michael Nisi. All rights reserved.
//

import Foundation
import Patron

// MARK: API

public enum FanboyError: ErrorType {
  case UnexpectedResult(result: AnyObject?)
  case CancelledByUser
  case InvalidTerm
}

// TODO: Consider putting errors last

/// Defines the fanboy remote service API.
public protocol FanboyService {
  var host: String { get }
  var status: (Int, NSTimeInterval)? { get }
  
  func version(cb: (ErrorType?, String?) -> Void) -> NSURLSessionTask
  
  func search(
    term: String,
    cb: (ErrorType?, [[String : AnyObject]]?) -> Void
  ) throws -> NSURLSessionTask
  
  func lookup(
    guids: [String],
    cb: (ErrorType?, [[String : AnyObject]]?) -> Void
  ) -> NSURLSessionTask
  
  func suggest(
    term: String,
    cb: (ErrorType?, [String]?) -> Void
  ) throws -> NSURLSessionTask
}

// MARK: -

/// Transform errors.
private func retypeError(error: ErrorType?) -> ErrorType? {
  guard let er = error as? NSError else {
    return error
  }
  switch er.code {
  case -999: return FanboyError.CancelledByUser
  default: return er
  }
}

/// Removes whitespace at the beginning and end of the specified term, and
/// returns URL encoded term. Note that inner whitespace is left unmodified.
///
/// - parameter term: The term to encode.
///
/// - throws: `FanboyError.InvalidTerm`
func encodeTerm(term: String) throws -> String {
  let ws = NSCharacterSet.whitespaceCharacterSet()
  let trimmed = term.stringByTrimmingCharactersInSet(ws)
  guard !trimmed.isEmpty else {
    throw FanboyError.InvalidTerm
  }
  let url = NSCharacterSet.URLHostAllowedCharacterSet()
  return trimmed.stringByAddingPercentEncodingWithAllowedCharacters(url)!
}

public final class Fanboy: FanboyService {
  
  let client: JSONService

  /// The host of the remote server.
  public var host: String {
    get { return client.host }
  }
  
  /// The latest status of the service.
  public var status: (Int, NSTimeInterval)? {
    get { return client.status }
  }

  /// Creates a `Fanboy` object with the specified client.
  ///
  /// - parameter client: The remote service to use.
  public init(client: JSONService) {
    self.client = client
  }
  
  private func request(
    path: String,
    cb: (ErrorType?,
    [[String:AnyObject]]?) -> Void
  ) -> NSURLSessionTask {
    return client.get(path) { json, response, error in
      if let er = retypeError(error) {
        cb(er, nil)
      } else if let result = json as? [[String:AnyObject]] {
        cb(nil, result)
      } else {
        cb(FanboyError.UnexpectedResult(result: json), nil)
      }
    }
  }
  
  /// Lookup specific podcast feeds by their iTunes GUIDs.
  ///
  /// - parameter guids: The GUIDs of the feeds to fetch.
  /// - parameter cb: The callback to handle error and results.
  public func lookup(
    guids: [String],
    cb: (ErrorType?, [[String : AnyObject]]?) -> Void
  ) -> NSURLSessionTask {
    let query = guids.joinWithSeparator(",")
    let path = "/lookup/\(query)"
    return request(path, cb: cb)
  }
  
  /// Search feeds matching the specified `term`.
  ///
  /// - parameter term: The search term, a space separated list of words, to
  /// search for.
  /// - parameter cb: The callback to handle error and results.
  public func search(
    term: String,
    cb: (ErrorType?, [[String : AnyObject]]?) -> Void
  ) throws -> NSURLSessionTask {
    let t = try encodeTerm(term)
    let path = "/search/\(t)"
    return request(path, cb: cb)
  }
  
  /// Request suggestions for a given search term or fragment thereof.
  ///
  /// - parameter term: The term to find suggestions for, it has to be a single
  /// space separated list of lowercase words. But usually you'd pass fragments:
  /// leading characters of eventual search terms.
  /// - parameter cb: The callback block gets dispatched once.
  ///
  /// - throws: Throws if `term ` could not be encoded to a valid search term.
  public func suggest(
    term: String,
    cb: (ErrorType?, [String]?) -> Void
  ) throws -> NSURLSessionTask {
    let t = try encodeTerm(term)
    let path = "/suggest/\(t)"
    return client.get(path) { json, response, error in
      if let er = retypeError(error) {
        cb(er, nil)
      } else if let result = json as? [String] {
        cb(nil, result)
      } else {
        cb(FanboyError.UnexpectedResult(result: json), nil)
      }
    }
  }
  
  /// Request the version of the remote service.
  ///
  /// - parameter cb: The callback receiving error and version string.
  public func version(cb: (ErrorType?, String?) -> Void) -> NSURLSessionTask {
    return client.get("/") { json, response, error in
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
