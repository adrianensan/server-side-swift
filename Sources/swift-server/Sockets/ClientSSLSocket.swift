import Foundation
import COpenSSL

func cb( _ sslSocket: UnsafeMutablePointer<SSL>?,
               _ out: UnsafeMutablePointer<UnsafePointer<UInt8>?>?,
            _ outlen: UnsafeMutablePointer<UInt8>?,
_ supportedProtocols: UnsafePointer<UInt8>?,
             _ inlen: UInt32,
               _ arg: UnsafeMutableRawPointer?) -> Int32 {
    if let supportedProtocols = supportedProtocols {
        var data = [UInt8]()
        for i in 0..<inlen {
            data.append(supportedProtocols.advanced(by: Int(i)).pointee)
        }
        if let string = String(bytes: data, encoding: .utf8) {
            if let desired = string.range(of: "http/1.1") {
                let offset = string.distance(from: string.startIndex, to: desired.lowerBound)
                out?.initialize(to: supportedProtocols.advanced(by: offset))
                outlen?.initialize(to: 8)
                return SSL_TLSEXT_ERR_OK
            }
            return SSL_TLSEXT_ERR_ALERT_FATAL
        }
    }
    return SSL_TLSEXT_ERR_NOACK
}

class ClientSSLSocket: ClientSocket {
    
    static var sslContext: UnsafeMutablePointer<SSL_CTX>?
    
    static func initSSLContext(certificateFile: String, privateKeyFile: String) {
        SSL_load_error_strings();
        SSL_library_init();
        OpenSSL_add_all_digests();
        ClientSSLSocket.sslContext = SSL_CTX_new(TLSv1_2_server_method())
        SSL_CTX_set_alpn_select_cb(sslContext, cb, nil)
        if SSL_CTX_use_certificate_file(ClientSSLSocket.sslContext, certificateFile , SSL_FILETYPE_PEM) != 1 {
            fatalError("Failed to use provided certificate file")
        }
        if SSL_CTX_use_PrivateKey_file(ClientSSLSocket.sslContext, privateKeyFile, SSL_FILETYPE_PEM) != 1 {
            fatalError("Failed to use provided preivate key file")
        }
    }
    
    var sslSocket: UnsafeMutablePointer<SSL>
    
    override init(socketFD: Int32) {
        sslSocket = SSL_new(ClientSSLSocket.sslContext!);
        super.init(socketFD: socketFD)
        
        SSL_set_fd(sslSocket, socketFileDescriptor);
        let ssl_err = SSL_accept(sslSocket);
        if ssl_err <= 0 { close(socketFileDescriptor) }
    }
    
    override func sendData(data: [UInt8]) {
        var bytesToSend = data.count
        repeat {
            let bytesSent = SSL_write(sslSocket, data, Int32(bytesToSend));
            if bytesSent <= 0 { return }
            bytesToSend -= Int(bytesSent)
        } while bytesToSend > 0
    }
    
    override func acceptRequest() -> Request? {
        var requestBuffer: [UInt8] = [UInt8](repeating: 0, count: Socket.bufferSize)
        var requestLength: Int = 0
        while true {
            let bytesRead = SSL_read(sslSocket, &requestBuffer[requestLength], Int32(Socket.bufferSize - requestLength));
            guard bytesRead > 0 else { return nil }
            requestLength += Int(bytesRead)
            if let requestString = String(bytes: requestBuffer[..<requestLength].filter{$0 != 13}, encoding: .utf8) {
                return Request.parse(string: requestString);
            }
        }
    }
    
}
