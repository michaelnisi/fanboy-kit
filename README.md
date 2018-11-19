# FanboyKit

Search iTunes with FanboyKit. The framework provides a client for [fanboy-http](https://github.com/michaelnisi/fanboy-http), a caching proxy for the [iTunes Search API](https://affiliate.itunes.apple.com/resources/documentation/itunes-store-web-service-search-api/). FanboyKit is used in the [Podest](https://github.com/michaelnisi/podest) podcast app.

## Example

Querying for suggestions matching the term `"crook"` limiting the result to 10.

```swift
import Foundation
import Patron
import Fanboy

let url = URL(string: "https://your.endpoint")!
let s = URLSession(configuration: .default)
let p = Patron(URL: url, session: s)
let svc = Fanboy(client: p)

try! svc.suggestions(matching: "crook", limit: 10) { result, error in
  print(error ?? result)
}
```

Please refer to [fanboy-http](https://github.com/michaelnisi/fanboy-http) for details.

## Dependencies

- [Patron](https://github.com/michaelnisi/patron), JSON HTTP client

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

#### client

```swift
var client: JSONService { get }
```

The client property of the `FanboyService` object gives access to the underlying [Patron](https://github.com/michaelnisi/patron)) client, providing hostname and status of the remote service.

## Installation

Integrate FanboyKit into your Xcode workspace.

## License

[MIT License](https://github.com/michaelnisi/fanboy-kit/blob/master/LICENSE)
