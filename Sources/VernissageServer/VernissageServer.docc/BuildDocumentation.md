# Build the documentation

This documentation is created by DocC tool.

## Overview

We can two options how to generate and preview the documentation.

### Serve local documentation

```bash
swift package --disable-sandbox preview-documentation \
    --exclude-extended-types \
    --product VernissageServer
```

### Eport for the GitHub Pages

```bash
swift package --allow-writing-to-directory .build/docs \
    generate-documentation --target VernissageServer \
    --disable-indexing \
    --exclude-extended-types \
    --transform-for-static-hosting \
    --output-path .build/docs
```
