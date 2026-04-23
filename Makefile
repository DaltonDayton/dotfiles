BIN := ./bin/quill

.PHONY: all build test fmt clean

all: build

build:
	go build -o $(BIN) ./cmd/quill

test:
	go test ./...

fmt:
	gofmt -w .

clean:
	rm -rf bin/
