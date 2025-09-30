# DialDesk Docker Setup

This project includes Docker configuration for easy development and deployment.

## Prerequisites

- Docker
- Docker Compose

## Quick Start

### Build and Run Release APK
```bash
# Build the Flutter APK
docker-compose --profile build up dialdesk-build

# The APK will be available at: ./build/app/outputs/flutter-apk/app-release.apk
```

### Development Mode
```bash
# Run in development mode with hot reload
docker-compose --profile dev up dialdesk-dev

# Access the app at: http://localhost:8080
```

### Production Mode
```bash
# Run in production mode
docker-compose up dialdesk-app

# Access the app at: http://localhost:8080
```

## Docker Commands

### Build the image
```bash
docker build -t dialdesk .
```

### Run container
```bash
# Run with volume mounting for development
docker run -v $(pwd):/app -p 8080:8080 dialdesk

# Run built APK
docker run -v $(pwd)/build:/app/build dialdesk
```

### Clean up
```bash
# Remove containers
docker-compose down

# Remove images
docker rmi dialdesk
```

## Features

- Multi-stage build for optimized image size
- Android SDK and Flutter pre-installed
- Volume mounting for development
- Support for both debug and release builds
- Web server support for testing

## Notes

- The Docker setup is primarily for building APKs and web deployment
- For mobile device testing, you'll still need to install the APK on your device
- Web version may have limited functionality due to mobile-specific features
