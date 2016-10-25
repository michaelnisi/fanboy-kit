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

public enum FanboyError: Error {
  case unexpectedResult(result: AnyObject?)
  case cancelledByUser
  case invalidTerm
}

/// Defines the fanboy remote service API.
public protocol FanboyService {
  var host: String { get }
  var status: (Int, TimeInterval)? { get }
  
  @discardableResult func version(
    _ cb: @escaping (Error?, String?) -> Void
  ) -> URLSessionTask
  
  @discardableResult func search(
    _ term: String,
    cb: @escaping (Error?, [[String : AnyObject]]?) -> Void
  ) throws -> URLSessionTask
  
  @discardableResult func lookup(
    _ guids: [String],
    cb: @escaping (Error?, [[String : AnyObject]]?) -> Void
  ) -> URLSessionTask
  
  @discardableResult func suggest(
    _ term: String,
    cb: @escaping (Error?, [String]?) -> Void
  ) throws -> URLSessionTask
}

// MARK: -

/// Transform errors.
private func retypeError(_ error: Error?) -> Error? {
  guard let er = error as? NSError else {
    return error
  }
  switch er.code {
  case -999: return FanboyError.cancelledByUser
  default: return er
  }
}

/// Removes whitespace at the beginning and end of the specified term, and
/// returns URL encoded term. Note that inner whitespace is left unmodified.
///
/// - parameter term: The term to encode.
///
/// - throws: `FanboyError.InvalidTerm`
func encodeTerm(_ term: String) throws -> String {
  let ws = CharacterSet.whitespaces
  let trimmed = term.trimmingCharacters(in: ws)
  guard !trimmed.isEmpty else {
    throw FanboyError.invalidTerm
  }
  let url = CharacterSet.urlHostAllowed
  return trimmed.addingPercentEncoding(withAllowedCharacters: url)!
}

public final class Fanboy: FanboyService {
  
  let client: JSONService

  /// The host of the remote server.
  public var host: String {
    get { return client.host }
  }
  
  /// The latest status of the service.
  public var status: (Int, TimeInterval)? {
    get { return client.status }
  }

  /// Creates a `Fanboy` object with the specified client.
  ///
  /// - parameter client: The remote service to use.
  public init(client: JSONService) {
    self.client = client
  }
  
  fileprivate func request(
    _ path: String,
    cb: @escaping (Error?,
    [[String:AnyObject]]?) -> Void
  ) -> URLSessionTask {
    return client.get(path: path) { json, response, error in
      if let er = retypeError(error) {
        cb(er, nil)
      } else if let result = json as? [[String:AnyObject]] {
        cb(nil, result)
      } else {
        cb(FanboyError.unexpectedResult(result: json), nil)
      }
    }
  }
  
  /// Lookup specific podcast feeds by their iTunes GUIDs.
  ///
  /// - parameter guids: The GUIDs of the feeds to fetch.
  /// - parameter cb: The callback to handle error and results.
  public func lookup(
    _ guids: [String],
    cb: @escaping (Error?, [[String : AnyObject]]?) -> Void
  ) -> URLSessionTask {
    let query = guids.joined(separator: ",")
    let path = "/lookup/\(query)"
    return request(path, cb: cb)
  }
  
  /// Search feeds matching the specified `term`.
  ///
  /// - parameter term: The search term, a space separated list of words, to
  /// search for.
  /// - parameter cb: The callback to handle error and results.
  public func search(
    _ term: String,
    cb: @escaping (Error?, [[String : AnyObject]]?) -> Void
  ) throws -> URLSessionTask {
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
    _ term: String,
    cb: @escaping (Error?, [String]?) -> Void
  ) throws -> URLSessionTask {
    let t = try encodeTerm(term)
    let path = "/suggest/\(t)"
    return client.get(path: path) { json, response, error in
      if let er = retypeError(error) {
        cb(er, nil)
      } else if let result = json as? [String] {
        cb(nil, result)
      } else {
        cb(FanboyError.unexpectedResult(result: json), nil)
      }
    }
  }
  
  /// Request the version of the remote service.
  ///
  /// - parameter cb: The callback receiving error and version string.
  public func version(_ cb: @escaping (Error?, String?) -> Void) -> URLSessionTask {
    return client.get(path: "/") { json, response, error in
      if let er = retypeError(error) {
        cb(er, nil)
      } else if let version = json?["version"] as? String {
        cb(nil, version)
      } else {
        cb(FanboyError.unexpectedResult(result: json), nil)
      }
    }
  }
}
