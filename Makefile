install:
	swift build -c release
	install .build/release/static-server-cli /usr/local/bin/static-server
