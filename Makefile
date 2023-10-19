build: clean ssh-target

clean:
	rm -rf ./bin/

ssh-target:
	GOOS=linux GOARCH=amd64 go build -o ./bin/app ./app

docker:
	docker build --platform linux/amd64 -t ssh-target .
