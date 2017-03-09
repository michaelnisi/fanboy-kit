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

/// A client for the fanboy-http, a caching proxy of the iTunes Search API.
public protocol FanboyService {
  var client: JSONService { get }

  @discardableResult func version(
    completionHandler cb: @escaping (_ version: String?, Error?) -> Void
  ) -> URLSessionTask

  @discardableResult func search(
    term: String,
    completionHandler cb: @escaping (_ podcasts: [[String : AnyObject]]?, _ error: Error?) -> Void
  ) throws -> URLSessionTask

  @discardableResult func lookup(
    guids: [String],
    completionHandler cb: @escaping (_ podcasts: [[String : AnyObject]]?, _ error: Error?) -> Void
  ) -> URLSessionTask

  @discardableResult func suggestions(
    matching: String,
    limit: Int,
    completionHandler cb: @escaping (_ terms: [String]?, _ error: Error?) -> Void
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
/// - returns: URL encoded search term.
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

  /// The underlying JSON service client.
  public let client: JSONService

  /// Creates a `Fanboy` object with the specified client.
  ///
  /// - parameter client: The remote service to use.
  public init(client: JSONService) {
    self.client = client
  }

  private func request(
    _ path: String,
    cb: @escaping ([[String : AnyObject]]?, Error?) -> Void
  ) -> URLSessionTask {
    return client.get(path: path) { json, response, error in
      if let er = retypeError(error) {
        cb(nil, er)
      } else if let result = json as? [[String : AnyObject]] {
        cb(result, nil)
      } else {
        let er = FanboyError.unexpectedResult(result: json)
        cb(nil, er)
      }
    }
  }

  /// Lookup specific podcast feeds by their iTunes GUIDs.
  ///
  /// - parameter guids: The GUIDs of the podcasts to lookup in iTunes.
  /// - parameter completionHandler: A block with following parameters:
  /// - parameter error: An error object, or nil.
  /// - parameter podcasts: The podcasts with the requested `guids`.
  ///
  /// - returns: Returns the according URL session task.
  public func lookup(
    guids: [String],
    completionHandler cb: @escaping (_ podcasts: [[String : AnyObject]]?, _ error: Error?) -> Void
  ) -> URLSessionTask {
    let query = guids.joined(separator: ",")
    let path = "/lookup/\(query)"
    return request(path, cb: cb)
  }

  /// Search feeds matching the specified `term`.
  ///
  /// - parameter term: The search term, a space separated list of words, to
  /// search for.
  /// - parameter completionHandler: A block with following parameters:
  /// - parameter error: An error object, or nil.
  /// - parameter podcasts: The podcasts matching `term` in iTunes.
  ///
  /// - returns: Returns the according URL session task.
  public func search(
    term: String,
    completionHandler cb: @escaping (_ podcasts: [[String : AnyObject]]?, _ error: Error?) -> Void
  ) throws -> URLSessionTask {
    let t = try encodeTerm(term)
    let path = "/search?q=\(t)"
    return request(path, cb: cb)
  }

  /// Request suggestions for a given search term or fragment thereof.
  ///
  /// - parameter term: The term to find suggestions for, it has to be a single
  /// space separated list of lowercase words. But usually you'd pass fragments:
  /// leading characters of eventual search terms.
  /// - parameter limit: The maximum number of suggestions to receive.
  /// - parameter completionHandler: A block with following parameters:
  /// - parameter error: An error object, or nil.
  /// - parameter terms: The suggestions.
  ///
  /// - returns: Returns the according URL session task.
  ///
  /// - throws: Throws if `term ` could not be encoded to a valid search term.
  public func suggestions(
    matching term: String,
    limit: Int,
    completionHandler cb: @escaping (_ terms: [String]?, _ error: Error?) -> Void
  ) throws -> URLSessionTask {
    let t = try encodeTerm(term)
    let path = "/suggest?q=\(t)&max=\(limit)"
    return client.get(path: path) { json, response, error in
      if let er = retypeError(error) {
        cb(nil, er)
      } else if let result = json as? [String] {
        cb(result, nil)
      } else {
        let er = FanboyError.unexpectedResult(result: json)
        cb(nil, er)
      }
    }
  }

  /// Request the version of the remote service.
  ///
  /// - parameter completionHandler: A block with following parameters:
  /// - parameter error: An error object, or nil.
  /// - parameter version: The version of the remote service.
  ///
  /// - returns: Returns the according URL session task.
  public func version(
    completionHandler cb: @escaping (_ version: String?, _ error: Error?) -> Void
  ) -> URLSessionTask {
    return client.get(path: "/") { json, response, error in
      if let er = retypeError(error) {
        cb(nil, er)
      } else if let version = json?["version"] as? String {
        cb(version, nil)
      } else {
        let er = FanboyError.unexpectedResult(result: json)
        cb(nil, er)
      }
    }
  }
}
