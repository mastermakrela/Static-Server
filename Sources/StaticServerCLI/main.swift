import ArgumentParser
import StaticServer

struct StaticServerCLI: ParsableCommand {
    static let configuration = CommandConfiguration(abstract:
        """
        Simple server for serving sttic files from one directory.
        Built with SwifrNIO
        """
    )

    @Option(name: .shortAndLong, help: "Port on which the server should be avaliable")
    var port: Int = 8888

    @Option(name: .shortAndLong, help: "Hostname on which the server should be avaliable")
    var host: String = "::"

    @Option(name: .shortAndLong, help: "Directory which should be served")
    var serverRoot: String = "/dev/null"

    func run() throws {
        let server = try StaticServer(host: host, port: port, root: serverRoot)

        try server.start()
    }
}

StaticServerCLI.main()
