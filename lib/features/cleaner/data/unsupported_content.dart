/// Thrown by a handler when it *recognises* the file but knows it cannot clean
/// it safely (encrypted PDF, RAW/DNG…). Reported as `unsupported` — never as a
/// generic failure, and never with a half-cleaned output.
class UnsupportedContent extends FormatException {
  const UnsupportedContent(super.message);
}
