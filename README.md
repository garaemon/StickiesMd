# StickiesMd

## Development

### Formatter

This project uses `swift-format`.
CI checks for formatting, and it will fail if any violations are found.

#### Installation

```bash
brew install swift-format
```

#### Usage

Run the following command to format the code for the entire project:

```bash
swift-format --in-place --recursive .
```

### Testing

Run the following command to execute tests via CLI:

```bash
xcodebuild test -scheme StickiesMd -destination 'platform=macOS'
```