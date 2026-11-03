# Build Stage
FROM golang:1.23-alpine AS builder

WORKDIR /app

RUN apk add --no-cache gcc musl-dev git

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o server main.go

# Production Stage
FROM alpine:3.19

WORKDIR /app

RUN apk --no-cache add ca-certificates tzdata ffmpeg

COPY --from=builder /app/server .

# Ensure storage directories exist
RUN mkdir -p /app/data/masters /app/data/hls /app/data/thumbnails /app/data/logos /app/logs

EXPOSE 2085

CMD ["./server"]
