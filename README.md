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

### Golden Tests

We use golden tests (snapshot tests) to verify the rendering of markdown files.
The reference image is located at `StickiesMdUITests/ReferenceImages/sample.png`.

#### Running Golden Tests

Golden tests are included in the standard test suite. You can run them with `xcodebuild` as shown above.

#### Updating Golden Images

If the golden test fails due to intentional changes in rendering, you need to update the golden image.
Run the following script to regenerate the reference image:

```bash
./scripts/generate-golden.sh
```

This script builds the application in Debug configuration and uses the CLI to generate a new screenshot.

