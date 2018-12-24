import Foundation

public class Response: Message, CustomStringConvertible {
    
    var httpVersion: HTTPVersion = .http1_1
    public var status: ResponseStatus = .ok
    var cookies: [Cookie] = [Cookie]()
    var customeHeaders: [String] = [String]()
    public var contentType: ContentType = .none
    public var location: String?
    public var lastModifiedDate: Date?
    public var omitBody: Bool = false

    weak private var socket: ClientSocket?
    
    init(clientSocket: ClientSocket? = nil) {
        socket = clientSocket
    }
    
    public func add(cookie: Cookie) {
        cookies.append(cookie)
    }
    
    public func addCustomHeader(_ line: String) {
        customeHeaders.append(line.filterNewlines)
    }
    
    public func setBodyJSON<T: Encodable>(object: T, append: Bool = false) {
        if let json = try? JSONEncoder().encode(object) {
            if append { body += json }
            else { body = json }
        }
    }
    
    public func complete() {
        if let socket = socket { socket.sendResponse(self) }
        socket = nil
    }
    
    public var headerString: String {
        var string = httpVersion.description + " " + status.description + "\r\n"
        
        if let location = location { string += Header.locationHeader + location + "\r\n" }
        for cookie in cookies { string += cookie.description + "\r\n" }
        string += Header.hstsHeader + "\r\n"
        if let date = lastModifiedDate { string += Header.lastModifiedHeader + Header.httpDateFormater.string(from: date) + "\r\n" }
        for customHeader in customeHeaders { string += customHeader + "\r\n" }
        
        switch contentType {
        case .none: ()
        default: string += contentType.description + "\r\n"
        }
        
        string += "Content-Length: \(!omitBody ? body.count : 0)\r\n\r\n"
        return string
    }
    
    public var responseData: Data {
        return Data(headerString.utf8) + body
    }
    
    public var description: String {
        var string = headerString
        
        if !omitBody { string += bodyString }
        
        return string
    }
}
