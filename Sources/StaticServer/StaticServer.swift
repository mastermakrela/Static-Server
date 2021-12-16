//
//  Server.swift
//
//
//  Created by Krzysztof Kostrzewa on 26/11/2020.
//

import Foundation
import NIO
import NIOHTTP1

public enum ServerError: Error {
    case ServerRootDoesNotExist
    case FileIOMissing
    case ServerBootstrapMissing
    case AddressAlreadyInUse
}

public final class StaticServer {
    private let host: String
    private let port: Int
    private let root: String
    private let silent: Bool
    private let spa: Bool

    private let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    private let threadPool = NIOThreadPool(numberOfThreads: 6)

    private var fileIO: NonBlockingFileIO?
    private var socketBootstrap: ServerBootstrap?

    // MARK: - Initializer

    public init(host: String = "::", port: Int = 8888, root: String = "/dev/null", silent: Bool = false, spa: Bool = false) throws {
        if !FileManager.default.fileExists(atPath: root) {
            throw ServerError.ServerRootDoesNotExist
        }

        self.host = host
        self.port = port
        self.root = root
        self.silent = silent
        self.spa = spa

        threadPool.start()
    }

    // MARK: - Helpunctions

    private func prepareFileIO() {
        threadPool.start()
        fileIO = NonBlockingFileIO(threadPool: threadPool)
    }

    private func prepareBootstrap() throws {
        guard let fileIO = fileIO else { throw ServerError.FileIOMissing }

        func childChannelInitializer(channel: Channel) -> EventLoopFuture<Void> {
            channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).flatMap {
                channel.pipeline.addHandler(HTTPHandler(fileIO: fileIO, htdocsPath: self.root, spa: self.spa))
            }
        }

        socketBootstrap = ServerBootstrap(group: group)
            // Specify backlog and enable SO_REUSEADDR for the server itself
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)

            // Set the handlers that are applied to the accepted Channels
            .childChannelInitializer(childChannelInitializer(channel:))

            // Enable SO_REUSEADDR for the accepted Channels
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
    }

    // MARK: Public Interface

    public func start() throws {
        prepareFileIO()
        try prepareBootstrap()

        guard fileIO != nil else { throw ServerError.FileIOMissing }
        guard let socketBootstrap = socketBootstrap else { throw ServerError.ServerBootstrapMissing }

        if !silent { print("Server root folder: \(root)") }

        do {
            let channel = try socketBootstrap.bind(host: host, port: port).wait()

            guard let channelLocalAddress = channel.localAddress else {
                throw NIO.IOError(errnoCode: 48, reason: "Address was unable to bind. Please check that the socket was not closed or that the address family was understood.")
            }

            if !silent { print("Server started and listening on \(channelLocalAddress), serving files from \(root)") }

            try channel.closeFuture.wait()

        } catch let error as NIO.IOError where error.errnoCode == 48 {
            throw ServerError.AddressAlreadyInUse
        } catch {
            throw error
        }

        if !silent { print("Server closed") }
    }

    public func stop() {
        try! group.syncShutdownGracefully()
        try! threadPool.syncShutdownGracefully()
    }

    deinit {
        stop()
    }
}
