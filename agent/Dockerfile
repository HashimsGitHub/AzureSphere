FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY go.mod ./
RUN go mod download
COPY main.go ./
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o agent .

FROM alpine:3.19
# iputils: ping, ca-certificates: TLS, docker-cli: exec into traceroute sidecar
RUN apk add --no-cache iputils ca-certificates tzdata docker-cli
WORKDIR /app
COPY --from=builder /app/agent .
EXPOSE 8080
CMD ["./agent"]
