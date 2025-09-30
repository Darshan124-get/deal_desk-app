# Multi-stage build for Flutter app
FROM ubuntu:20.04 as base

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    openjdk-8-jdk \
    && rm -rf /var/lib/apt/lists/*

# Set up Android SDK
ENV ANDROID_SDK_ROOT /opt/android-sdk
ENV ANDROID_HOME /opt/android-sdk
ENV PATH $PATH:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools

RUN mkdir -p $ANDROID_SDK_ROOT && \
    cd $ANDROID_SDK_ROOT && \
    curl -o sdk-tools.zip https://dl.google.com/android/repository/commandlinetools-linux-9477386_latest.zip && \
    unzip sdk-tools.zip && \
    rm sdk-tools.zip && \
    mkdir -p cmdline-tools/latest && \
    mv cmdline-tools/* cmdline-tools/latest/ 2>/dev/null || true

# Accept Android licenses
RUN yes | sdkmanager --licenses || true

# Install Flutter
RUN git clone https://github.com/flutter/flutter.git /opt/flutter
ENV PATH $PATH:/opt/flutter/bin

# Set up Flutter
RUN flutter config --no-analytics && \
    flutter doctor

# Set working directory
WORKDIR /app

# Copy pubspec files
COPY pubspec.yaml pubspec.lock ./

# Get dependencies
RUN flutter pub get

# Copy source code
COPY . .

# Build APK
RUN flutter build apk --release

# Runtime stage
FROM ubuntu:20.04

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    openjdk-8-jdk \
    && rm -rf /var/lib/apt/lists/*

# Copy built APK
COPY --from=base /app/build/app/outputs/flutter-apk/app-release.apk /app/app-release.apk

# Set working directory
WORKDIR /app

# Expose port (if needed for web version)
EXPOSE 8080

# Default command
CMD ["ls", "-la", "/app"]
