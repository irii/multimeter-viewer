# Third-party notices

Multimeter Viewer is released under the MIT license (see `LICENSE`).
It builds on the following third-party work. The full license texts are
also shown in the app under *About → Open-source licenses*.

## Protocol knowledge

The binary layouts of the memory commands (`qsls`, `qemap`, `qrsi`, `qsrr`,
`qmmsi`, `qpsi`, `qsmr`) in `lib/fluke/fluke_memory.dart` follow the
reverse-engineered descriptions of these projects. The test data in
`test/fluke_memory_test.dart` was captured by dmm_util.

- **dmm_util** – © 2011 Fredrik Valeur – MIT –
  https://github.com/fvaleur/dmm_util (`assets/licenses/dmm_util-MIT.txt`)
- **fluke-28x-dmm-util** – © 2019 N0ury – MIT –
  https://github.com/N0ury/dmm_util
  (`assets/licenses/fluke-28x-dmm-util-MIT.txt`)

## libusb (native builds)

The macOS build bundles libusb 1.0.30 as a shared library
(`Contents/Frameworks/libusb-1.0.0.dylib`). The Android build compiles the
unmodified libusb 1.0.30 sources in `android/app/src/main/cpp/libusb-1.0.30`
(with their `COPYING`) into `libusb-1.0.so` inside the APK. Windows users place
`libusb-1.0.dll` next to the app; Linux uses the system library.

- **libusb** – GNU Lesser General Public License 2.1 –
  https://libusb.info – unmodified source:
  https://github.com/libusb/libusb/releases/tag/v1.0.30
  (`assets/licenses/libusb-LGPL-2.1.txt`)

libusb is loaded dynamically and can be replaced by any compatible build
(e.g. set `LIBUSB_DYLIB` for `macos/embed_libusb.sh`).

## Platform libraries

- **Material Icons** font, bundled by Flutter into every build – © Google LLC
  – Apache License 2.0 (`assets/licenses/Apache-2.0.txt`)
- **AndroidX** – © The Android Open Source Project – Apache License 2.0
  (Android build)
- **Kotlin Standard Library** – © JetBrains s.r.o. and Kotlin Programming
  Language contributors – Apache License 2.0 (Android build)

The app's license page shows the entries for the platform it runs on.

## Dart and Flutter packages

All runtime dependencies use permissive licenses (BSD-3-Clause, MIT,
Apache-2.0); their notices are collected automatically by Flutter and shown
on the license page. Notable ones: Flutter (BSD), flutter_bloc/bloc (MIT),
go_router (BSD), fl_chart (MIT), window_manager (MIT), unified_usb (MIT),
file_selector, shared_preferences, url_launcher, intl (BSD).
