#!/bin/bash

# Smart build script that detects project type and runs appropriate build

set -e

echo "🔍 Detecting project type..."

# Check if docker-compose.yml exists (Docker project) - check this FIRST
if [ -f "docker-compose.yml" ]; then
    echo "🐳 Detected Docker project"

    # Check if docker is installed
    if ! command -v docker &> /dev/null; then
        echo "❌ Error: docker is not installed"
        exit 1
    fi

    echo "🔨 Building Docker containers..."
    docker-compose build
    echo "✅ Docker build completed successfully"

# Check if package.json exists (Node.js project)
elif [ -f "package.json" ]; then
    echo "📦 Detected Node.js project"

    # Check if npm is installed
    if ! command -v npm &> /dev/null; then
        echo "❌ Error: npm is not installed"
        exit 1
    fi

    # Check if build script exists in package.json
    if grep -q '"build"' package.json && ! grep -q '"build": "./scripts/build.sh"' package.json; then
        echo "🔨 Running npm build..."
        npm run build
        echo "✅ Node.js build completed successfully"
    else
        echo "⚠️  No build script found in package.json or it would cause recursion"
        exit 1
    fi

# Check if Dockerfile exists
elif [ -f "Dockerfile" ] || [ -f "Dockerfile.monitoring" ]; then
    echo "🐳 Detected Dockerfile"

    # Check if docker is installed
    if ! command -v docker &> /dev/null; then
        echo "❌ Error: docker is not installed"
        exit 1
    fi

    # Find the Dockerfile
    if [ -f "Dockerfile" ]; then
        DOCKERFILE="Dockerfile"
    else
        DOCKERFILE="Dockerfile.monitoring"
    fi

    echo "🔨 Building Docker image from $DOCKERFILE..."
    docker build -f "$DOCKERFILE" -t marketsage-monitoring:latest .
    echo "✅ Docker build completed successfully"

else
    echo "❌ Error: Could not detect project type"
    echo "   No package.json, docker-compose.yml, or Dockerfile found"
    exit 1
fi
