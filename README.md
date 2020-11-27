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
StaticServerCLI [--port <port>] [--host <host>] [--server-root <server-root>]
StaticServerCLI [-p <port>] [-h <host>] [-s <server-root>]
```

After cloning and building it's helpful to copy `StaticServerCLI` to `/usr/local/bin` for direct acces in any directory.

For full help use `StaticServerCLI --help`.

_Disclaimer_ For security reasons the default shared folder is `/dev/null`.

## Instalation

TBA

## Licence

See LICENCE.md file.

## Inspiration and Credits

I've created this simple package when I saw that [Publish](https://github.com/JohnSundell/Publish) has to use python server for devlopement although in Swift there also exist a posibility to serve files very easily.
I've also adopted `HTTPMediaFile` from great full-fledged server [Vapor](https://vapor.codes/), which itself would be an overkill for what is needed in [Publish](https://github.com/JohnSundell/Publish) developement.
