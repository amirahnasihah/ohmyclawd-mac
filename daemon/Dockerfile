FROM golang:latest AS builder
WORKDIR /app
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags='-s -w' -o ohmyclawd-daemon .

FROM alpine:3.19
RUN apk add --no-cache ca-certificates
WORKDIR /app
COPY --from=builder /app/ohmyclawd-daemon .
EXPOSE 8787
CMD ["./ohmyclawd-daemon"]
