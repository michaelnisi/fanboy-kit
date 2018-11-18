# FanboyKit - consume fanboy-http API

The FanboyKit framework provides a client for the [fanboy-http](https://github.com/michaelnisi/fanboy-http) service.

## Example

Querying iTunes for suggestions matching the term `a` limiting the result to 10.

```swift
import Foundation
import Patron
import Fanboy

let session = URLSession(configuration: .default)
let client = Patron(URL: url as URL, session: session)
let fanboy = Fanboy(client: client)

try! fanboy.suggestions(matching: "a", limit: 10) { result, error in
  print(error ?? result)
}
```

Please refer to [fanboy-http](https://github.com/michaelnisi/fanboy-http) for details.

## Dependencies

- [Patron](https://github.com/michaelnisi/patron) JSON HTTP client

## Types

### FanboyError

```swift
enum FanboyError: Error {
  case unexpectedResult(result: AnyObject?)
  case cancelledByUser
  case invalidTerm
}
```

### FanboyService

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

Integrate FanboyKit into your Xcode workspace.

## License

[MIT License](https://github.com/michaelnisi/fanboy-kit/blob/master/LICENSE)
