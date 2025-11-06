# Docker Image Known Issues

## Current Status: JVM Crash in Docker

The DBLift Docker images are experiencing a JVM crash (SIGSEGV) when running migrations. We're actively working on fixing this.

### Error Message
```
SIGSEGV (0xb) at pc=0x000076d12a4c3000
JRE version: OpenJDK Runtime Environment (21.0.9+10)
Problematic frame: java.lang.String.<init>
```

### Root Cause
JPype (Python-Java bridge) is having compatibility issues with OpenJDK 21 in the Docker container environment.

## Workaround: Use Local Installation

Until the Docker images are fixed, please install DBLift locally:

### Option 1: Install from Source (Recommended)

```bash
# Clone the main repository
git clone https://github.com/dblift/dblift.git
cd dblift

# Install dependencies
pip install -r requirements.txt

# Install DBLift
pip install -e .

# Verify installation
dblift --version
```

### Option 2: Download Pre-built Binary (Coming Soon)

Pre-built binaries will be available at:
- https://github.com/dblift/dblift/releases

## What We're Doing to Fix It

1. **Testing JPype alternatives** - Investigating py4j and other Java bridges
2. **Different JDK versions** - Testing with OpenJDK 17, 11
3. **JVM options** - Adding flags for better Docker compatibility
4. **Native compilation** - Exploring GraalVM native images

## Timeline

Expected fix: **TBD**

## Updates

Follow progress:
- GitHub Issues: https://github.com/dblift/dblift/issues
- Discussions: https://github.com/dblift/dblift/discussions

## For CI/CD

The **validation-only image** might work since it doesn't require JDBC:
```bash
docker run --rm \
  -v $(pwd):/workspace \
  ghcr.io/dblift/dblift:validation-latest \
  migrations/ --dialect postgresql
```

This is lightweight and suitable for PR validation workflows.

