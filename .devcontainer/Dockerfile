FROM ubuntu:22.04

# Install required system dependencies
RUN apt-get update && \
    apt-get install -y curl git unzip xz-utils zip libglu1-mesa ripgrep && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Clone the master branch shallowly
RUN git clone https://github.com/flutter/flutter.git -b 3.44.9 --depth 1 /flutter

# Set environment paths for Flutter and Dart
ENV PATH="/flutter/bin:/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Pre-download Flutter dependencies and run doctor
RUN flutter doctor

# Disable Dart analytics
RUN dart --disable-analytics