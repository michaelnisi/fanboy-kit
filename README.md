# FanboyKit - fanboy-http client

The FanboyKit framework provides a client for the [fanboy-http](https://github.com/michaelnisi/fanboy-http) service.

## Dependencies

- [Patron](https://github.com/michaelnisi/patron) - JSON HTTP client

## Types

```swift
enum FanboyError: Error {
  case unexpectedResult(result: AnyObject?)
  case cancelledByUser
  case invalidTerm
}
```

```swift
protocol FanboyService {
  var client: JSONService { get }

  @discardableResult func version(
    completionHandler cb: @escaping (_ version: String?, Error?) -> Void
  ) -> URLSessionTask

  @discardableResult func search(
    term: String,
    completionHandler cb: @escaping (
      _ podcasts: [[String : AnyObject]]?, _ error: Error?) -> Void
  ) throws -> URLSessionTask

  @discardableResult func lookup(
    guids: [String],
    completionHandler cb: @escaping (
      _ podcasts: [[String : AnyObject]]?, _ error: Error?) -> Void
  ) -> URLSessionTask

  @discardableResult func suggestions(
    matching: String,
    limit: Int,
    completionHandler cb: @escaping (
      _ terms: [String]?, _ error: Error?) -> Void
  ) throws -> URLSessionTask
}
```

## Installation

Simply integrate this framework into your Xcode workspace.

## License

[MIT License](https://github.com/michaelnisi/fanboy-kit/blob/master/LICENSE)
