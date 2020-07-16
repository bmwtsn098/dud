.PHONY: test test-int %-test-cov bench fmt clean tidy loc mocks depgraph hyperfine integration-%

DOCKER = docker run --rm -v '$(shell pwd):/src' go_dev

duc:
	go build -o duc

test: fmt
	go vet ./...
	go test -race -short ./...
	golint ./...

test-all: test
	go test -race -run Integration ./...

bench: test
	go test ./... -benchmem -bench .

%-test-cov: %-test-cov.out
	go tool cover -html=$<

unit-test-cov.out:
	go test -short ./... -coverprofile=$@

int-test-cov.out:
	go test -run Integration ./... -coverprofile=$@

all-test-cov.out:
	go test ./... -coverprofile=$@

integration-image:
	docker build -t duc_integration ./integration/

integration-env: integration-image duc
	docker run \
		--rm \
		-it \
		-v $(shell pwd)/duc:/usr/bin/duc \
		-v $(shell pwd)/integration:/integration \
	duc_integration

integration-tests: integration-image duc
	docker run \
		--rm \
		-v $(shell pwd)/duc:/usr/bin/duc \
		-v $(shell pwd)/integration:/integration \
	duc_integration python /integration/run_tests.py

fmt:
	goimports -w .
	gofmt -s -w .

clean:
	rm -f *.out depgraph.png mockery
	go clean ./...

tidy:
	go mod tidy -v

loc:
	tokei --sort lines
	tokei --sort lines --exclude "*_test.go"

mockery:
	curl -L https://github.com/vektra/mockery/releases/download/v1.1.2/mockery_1.1.2_Linux_x86_64.tar.gz \
		| tar -zxvf - mockery

mocks: mockery
	./mockery -all

depgraph:
	godepgraph -nostdlib $(wildcard **/*.go) | dot -Tpng -o depgraph.png

50mb_random.bin:
	dd if=/dev/urandom of=$@ bs=1M count=50

hyperfine: duc 50mb_random.bin
	hyperfine -L cmd sha1sum,md5sum,sha256sum,b2sum,'./duc checksum' \
		'{cmd} 50mb_random.bin'
	hyperfine -L bufsize 1000,10000,100000,1000000,10000000 \
		'./duc checksum -b{bufsize} 50mb_random.bin'

build-benchmark:
	docker build -t duc:benchmark -f benchmarking/Dockerfile .
