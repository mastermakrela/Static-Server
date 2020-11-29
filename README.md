# StaticServer

Welcome to _StaticServer_, a barebones server that serves static files.
If as a web developer you sometimes just want to see some website in browser without any setup - this is the tool for you.
Whole thing is written in Swift unsing SwiftNIO, so it's extremely fast and small.

# What's in the Box?

## StaticServer Library

This is the heart of this project, that just serves your files.

### Usage

#### Basic

The simplest way to use it is to create instance of `StaticServer` and tell it which directory to serve.

```swift
let server = try StaticServer(root: "directory/to/serve/here")

try server.start()
```

#### Advanced

You can also specify the `hostname` and/or `port` on which your directory should be avlaiabe.

```swift
let host = "localhost"
let port = 1337
let server = try StaticServer(host: host, port: port, root: serverRoot)

try server.start()
```

## StaticServerCLI

Basic command line tool that uses StaticSrver library to serve files.

### Usage

```zsh
static-server [--port <port>] [--host <host>] [--server-root <server-root>]
static-server [-p <port>] [-h <host>] [-s <server-root>]
```

For full help use `StaticServerCLI --help`.

_Disclaimer_ For security reasons the default shared folder is `/dev/null`.

## Instalation

### Library

StaticServer is distributed using the [Swift Package Manager](https://swift.org/package-manager).
To use the library just add it to your `Package.swift`:

```swift
let package = Package(
    ...
    dependencies: [
        .package(url: "https://github.com/Mastermakrela/Static-Server.git", from: "0.0.1")
    ],
    ...
)
```

Then don't forget to import it:

```swift

import StaticServer

```

### CLI

If you just want the CLI tool, clone this repository and run the `Makefile`.

The executable will be added to your `/user/local/bin/` and then you can use it anywhere on your mashine.

```swift
git clone https://github.com/Mastermakrela/Static-Server.git
cd StaticServer
make
```



## Licence

See [LICENCE.md](https://github.com/Mastermakrela/Static-Server/blob/main/LICENSE.md) file.

## Inspiration and Credits

I've created this simple package when I saw that [Publish](https://github.com/JohnSundell/Publish) has to use python server for devlopement although in Swift there also exist a posibility to serve files very easily.
I've also adopted `HTTPMediaFile` from great full-fledged server [Vapor](https://vapor.codes/), which itself would be an overkill for what is needed in [Publish](https://github.com/JohnSundell/Publish) developement.
