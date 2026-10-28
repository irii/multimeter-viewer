/// Font family for measured values.
///
/// `monospace` is only a real font on Linux and the web; macOS and Windows
/// would fall back to the proportional system font. The fallbacks make sure
/// digits, `-` and the blank sign column all have the same width everywhere.
const monoFontFamily = 'monospace';

const monoFontFamilyFallback = [
  'Menlo', // macOS
  'SF Mono',
  'Consolas', // Windows
  'Cascadia Mono',
  'DejaVu Sans Mono', // Linux
  'Liberation Mono',
  'Courier New',
];
