{
  stdenv,
  swift,
  apple-sdk,
  darwin,
  writeText,
}:
let
  infoPlist = writeText "paneru-preview-Info.plist" ''
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>CFBundleIdentifier</key>
      <string>com.github.inogai.paneru-preview</string>
      <key>CFBundleExecutable</key>
      <string>paneru-preview</string>
      <key>CFBundleName</key>
      <string>paneru-preview</string>
      <key>CFBundlePackageType</key>
      <string>APPL</string>
      <key>LSUIElement</key>
      <true/>
      <key>NSHighResolutionCapable</key>
      <true/>
      <key>NSScreenCaptureUsageDescription</key>
      <string>paneru-preview shows the strip columns in the bar.</string>
    </dict>
    </plist>
  '';
in
stdenv.mkDerivation {
  pname = "paneru-preview";
  version = "0.1.0";
  src = ./.;

  nativeBuildInputs = [ swift ];
  buildInputs = [ apple-sdk ];

  dontConfigure = true;
  dontStrip = true;
  darwinDontCodeSign = true;

  buildPhase = ''
    mkdir -p $out/Contents/MacOS
    swiftc -O -parse-as-library -sdk "$SDKROOT" \
      -o $out/Contents/MacOS/paneru-preview \
      Sources/Layout.swift Sources/App.swift \
      -framework AppKit -framework CoreGraphics
    cp ${infoPlist} $out/Contents/Info.plist
    CODESIGN_ALLOCATE="${darwin.cctools}/bin/${darwin.cctools.targetPrefix}codesign_allocate" \
      ${darwin.sigtool}/bin/codesign -f -s - -i com.github.inogai.paneru-preview \
      $out/Contents/MacOS/paneru-preview
  '';

  doCheck = true;
  checkPhase = ''
    swiftc -parse-as-library -sdk "$SDKROOT" -o layout-tests \
      Sources/Layout.swift Sources/LayoutTests.swift
    ./layout-tests
  '';

  installPhase = "true";
}
