# Installing DBLift

## Quick Install

### Docker (Recommended)
```bash
docker pull ghcr.io/dblift/dblift:latest
alias dblift='docker run --rm -v $(pwd):/workspace ghcr.io/dblift/dblift:latest'
dblift --version
```

### Linux
```bash
curl -L -o dblift-linux-x64.tar.gz \
  https://github.com/dblift/dblift/releases/latest/download/dblift-linux-x64.tar.gz
tar xzf dblift-linux-x64.tar.gz
export PATH="$PATH:$(pwd)/dblift-linux-x64"
dblift --version
```

### macOS (Apple Silicon)
```bash
curl -L -o dblift-macos-arm64.tar.gz \
  https://github.com/dblift/dblift/releases/latest/download/dblift-macos-arm64.tar.gz
tar xzf dblift-macos-arm64.tar.gz
export PATH="$PATH:$(pwd)/dblift-macos-arm64"
dblift --version
```

### macOS (Intel)
```bash
curl -L -o dblift-macos-x64.tar.gz \
  https://github.com/dblift/dblift/releases/latest/download/dblift-macos-x64.tar.gz
tar xzf dblift-macos-x64.tar.gz
export PATH="$PATH:$(pwd)/dblift-macos-x64"
dblift --version
```

### Windows
1. Download: https://github.com/dblift/dblift/releases/latest/download/dblift-windows-x64.zip
2. Extract to `C:\dblift`
3. Add `C:\dblift\dblift-windows-x64` to PATH
4. Run: `dblift --version`

## Verification

After installation:
```bash
dblift --version
dblift db list-drivers
```

## Troubleshooting

### "command not found"
Ensure dblift is in your PATH:
```bash
export PATH="$PATH:/path/to/dblift-directory"
```

### Permission denied
```bash
chmod +x dblift-linux-x64/dblift
```

### JDBC issues
```bash
dblift db diagnose-jdbc
```

## More Help

- Documentation: https://github.com/dblift/dblift
- Issues: https://github.com/dblift/dblift/issues
