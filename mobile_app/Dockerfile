# Stage 1: Build Flutter Web application
FROM ghcr.io/cirrusci/flutter:3.24.3 AS builder

WORKDIR /app

# Copy dependency specifications and download dependencies
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copy full application source code
COPY . .

# Build the web bundle in release mode
RUN flutter build web --release

# Stage 2: Serve static files with Nginx
FROM nginx:1.25-alpine AS runner

# Copy built web application from builder stage
COPY --from=builder /app/build/web /usr/share/nginx/html

# Copy custom Nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
