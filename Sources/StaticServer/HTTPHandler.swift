//
//  HTTPHandler.swift
//
//
//  Created by Krzysztof Kostrzewa on 26/11/2020.
//

import Foundation
import NIO
import NIOHTTP1

private func httpResponseHead(request: HTTPRequestHead, status: HTTPResponseStatus, headers: HTTPHeaders = HTTPHeaders()) -> HTTPResponseHead {
    var head = HTTPResponseHead(version: request.version, status: status, headers: headers)
    let connectionHeaders: [String] = head.headers[canonicalForm: "connection"].map { $0.lowercased() }

    if !connectionHeaders.contains("keep-alive"), !connectionHeaders.contains("close") {
        // the user hasn't pre-set either 'keep-alive' or 'close', so we might need to add headers

        switch (request.isKeepAlive, request.version.major, request.version.minor) {
        case (true, 1, 0):
            // HTTP/1.0 and the request has 'Connection: keep-alive', we should mirror that
            head.headers.add(name: "Connection", value: "keep-alive")
        case (false, 1, let n) where n >= 1:
            // HTTP/1.1 (or treated as such) and the request has 'Connection: close', we should mirror that
            head.headers.add(name: "Connection", value: "close")
        default:
            // we should match the default or are dealing with some HTTP that we don't support, let's leave as is
            ()
        }
    }
    return head
}

final class HTTPHandler: ChannelInboundHandler {
    public typealias InboundIn = HTTPServerRequestPart
    public typealias OutboundOut = HTTPServerResponsePart

    private enum State {
        case idle
        case waitingForRequestBody
        case sendingResponse

        mutating func requestReceived() {
            precondition(self == .idle, "Invalid state for request received: \(self)")
            self = .waitingForRequestBody
        }

        mutating func requestComplete() {
            precondition(self == .waitingForRequestBody, "Invalid state for request complete: \(self)")
            self = .sendingResponse
        }

        mutating func responseComplete() {
            precondition(self == .sendingResponse, "Invalid state for response complete: \(self)")
            self = .idle
        }
    }

    private var buffer: ByteBuffer!
    private var keepAlive = false
    private var state = State.idle

    private var handler: ((ChannelHandlerContext, HTTPServerRequestPart) -> Void)?
    private let fileIO: NonBlockingFileIO
    private let htdocsPath: String
    private let spa: Bool

    public init(fileIO: NonBlockingFileIO, htdocsPath: String, spa: Bool = false) {
        self.htdocsPath = htdocsPath.hasSuffix("/") ? htdocsPath : "\(htdocsPath)/"
        self.fileIO = fileIO
        self.spa = spa
    }

    private func handleFile(context: ChannelHandlerContext, request: HTTPServerRequestPart, path: String) {
        buffer.clear()

        func sendErrorResponse(request: HTTPRequestHead, _ error: Error) {
            var body = context.channel.allocator.buffer(capacity: 128)
            let response = { () -> HTTPResponseHead in
                switch error {
                case let e as IOError where e.errnoCode == ENOENT:
                    body.writeStaticString("IOError (not found)\r\n")
                    return httpResponseHead(request: request, status: .notFound)
                case let e as IOError:
                    body.writeStaticString("IOError (other)\r\n")
                    body.writeString(e.description)
                    body.writeStaticString("\r\n")
                    return httpResponseHead(request: request, status: .notFound)
                default:
                    body.writeString("\(type(of: error)) error\r\n")
                    return httpResponseHead(request: request, status: .internalServerError)
                }
            }()
            body.writeString("\(error)")
            body.writeStaticString("\r\n")
            context.write(wrapOutboundOut(.head(response)), promise: nil)
            context.write(wrapOutboundOut(.body(.byteBuffer(body))), promise: nil)
            context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
            context.channel.close(promise: nil)
        }

        func responseHead(request: HTTPRequestHead, fileRegion region: FileRegion, fileType: HTTPMediaType = .plainText) -> HTTPResponseHead {
            var response = httpResponseHead(request: request, status: .ok)
            response.headers.add(name: "Content-Length", value: "\(region.endIndex)")
//            response.headers.add(name: "Content-Type", value: "text/plain; charset=utf-8")
            response.headers.add(name: "Content-Type", value: fileType.description)
            return response
        }

        switch request {
        case let .head(request):
            keepAlive = request.isKeepAlive
            state.requestReceived()

            guard !request.uri.containsDotDot else {
                let response = httpResponseHead(request: request, status: .forbidden)
                context.write(wrapOutboundOut(.head(response)), promise: nil)
                completeResponse(context, trailers: nil, promise: nil)
                return
            }

            var path = htdocsPath + (path.removingPercentEncoding ?? "")
            var isDir: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDir)

            if !spa && !exists {
                sendErrorResponse(request: request, IOError(errnoCode: ENOENT, reason: "not found"))
                return
            }

            if isDir.boolValue { path += "/index.html" }
            
            if spa && (path.hasSuffix(".html") || !exists) { path = "\(htdocsPath)index.html" }

            let fileExtension = path.components(separatedBy: ".").last
            let fileMediaType = HTTPMediaType.fileExtension(fileExtension ?? "txt") ?? .plainText

            let fileHandleAndRegion = fileIO.openFile(path: path, eventLoop: context.eventLoop)

            fileHandleAndRegion.whenFailure { sendErrorResponse(request: request, $0) }

            fileHandleAndRegion.whenSuccess { file, region in
                let response = responseHead(request: request, fileRegion: region, fileType: fileMediaType)

                context.write(self.wrapOutboundOut(.head(response)), promise: nil)

                context.writeAndFlush(self.wrapOutboundOut(.body(.fileRegion(region)))).flatMap {
                    let p = context.eventLoop.makePromise(of: Void.self)
                    self.completeResponse(context, trailers: nil, promise: p)
                    return p.futureResult
                }
                .flatMapError { (_: Error) in
                    context.close()
                }
                .whenComplete { (_: Result<Void, Error>) in
                    _ = try? file.close()
                }
            }

        case .end:
            state.requestComplete()
        default:
            fatalError("oh noes: \(request)")
        }
    }

    private func completeResponse(_ context: ChannelHandlerContext, trailers: HTTPHeaders?, promise: EventLoopPromise<Void>?) {
        state.responseComplete()

        let promise = keepAlive ? promise : (promise ?? context.eventLoop.makePromise())
        if !keepAlive {
            promise!.futureResult.whenComplete { (_: Result<Void, Error>) in context.close(promise: nil) }
        }
        handler = nil

        context.writeAndFlush(wrapOutboundOut(.end(trailers)), promise: promise)
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let reqPart = unwrapInboundIn(data)
        if let handler = self.handler {
            handler(context, reqPart)
            return
        }

        switch reqPart {
        case let .head(request):
            let path = request.uri

            handler = { self.handleFile(context: $0, request: $1, path: path) }
            handler!(context, reqPart)

        case .body:
            break
        case .end:
            state.requestComplete()
            let content = HTTPServerResponsePart.body(.byteBuffer(buffer!.slice()))
            context.write(wrapOutboundOut(content), promise: nil)
            completeResponse(context, trailers: nil, promise: nil)
        }
    }

    func channelReadComplete(context: ChannelHandlerContext) {
        context.flush()
    }

    func handlerAdded(context: ChannelHandlerContext) {
        buffer = context.channel.allocator.buffer(capacity: 0)
    }

    func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        switch event {
        case let evt as ChannelEvent where evt == ChannelEvent.inputClosed:
            // The remote peer half-closed the channel. At this time, any
            // outstanding response will now get the channel closed, and
            // if we are idle or waiting for a request body to finish we
            // will close the channel immediately.
            switch state {
            case .idle, .waitingForRequestBody:
                context.close(promise: nil)
            case .sendingResponse:
                keepAlive = false
            }
        default:
            context.fireUserInboundEventTriggered(event)
        }
    }
}
