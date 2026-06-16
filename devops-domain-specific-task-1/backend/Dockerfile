
    FROM golang:1.26-alpine AS builder
    
    WORKDIR /app
    
   
    COPY go.mod go.sum ./
    RUN go mod download
    
    
    COPY . .
    
   
    RUN CGO_ENABLED=0 GOOS=linux go build -o server ./cmd/server/main.go
    
   
    FROM alpine:3.19
    
    WORKDIR /app
    
    RUN apk add --no-cache ca-certificates
    
    
    COPY --from=builder /app/server .
    COPY --from=builder /app/migrations ./migrations
    
    EXPOSE 8080
    
    CMD ["./server"]