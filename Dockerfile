FROM golang:1.21.3-alpine3.18 AS builder

WORKDIR /

COPY go.mod go.mod
COPY go.sum go.sum
RUN go mod download

COPY app /app

RUN GOOS=linux GOARCH=amd64 go build -o ./bin/app ./app

FROM scratch

WORKDIR /
COPY --from=builder /bin/app app

EXPOSE 23234
CMD ["./app"]