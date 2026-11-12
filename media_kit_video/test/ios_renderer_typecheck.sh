#!/bin/bash
# Typecheck the real renderer with Apple's SDK and the pinned mpv C headers.
# Flutter's minimal texture protocol is the only substitute; this is not an IPA
# build or a driver/runtime test.
set -euo pipefail
package_dir="$(cd "$(dirname "$0")/.." && pwd)"
scratch_dir="$(mktemp -d)"
trap 'rm -rf "$scratch_dir"' EXIT
sdk_path="$(xcrun --sdk iphoneos --show-sdk-path)"
target=arm64-apple-ios15.0
make -C "$package_dir/common/darwin" HEADERS_DESTDIR="$scratch_dir/Headers"
cat > "$scratch_dir/Flutter.swift" <<'SWIFT'
import CoreVideo
import Foundation
public protocol FlutterTexture: AnyObject {
  func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>?
}
public protocol FlutterTextureRegistry: AnyObject {
  func register(_ texture: FlutterTexture) -> Int64
  func unregisterTexture(_ textureId: Int64)
  func textureFrameAvailable(_ textureId: Int64)
}
public protocol FlutterPlugin {}
public protocol FlutterPluginRegistrar {
  func messenger() -> Int
  func textures() -> FlutterTextureRegistry
  func addMethodCallDelegate(_ plugin: FlutterPlugin, channel: FlutterMethodChannel)
}
public typealias FlutterResult = (Any?) -> Void
public struct FlutterMethodCall {
  public let method: String
  public let arguments: Any?
}
public let FlutterMethodNotImplemented = "not-implemented"
public final class FlutterMethodChannel {
  public init(name: String, binaryMessenger: Int) {}
  public func invokeMethod(_ method: String, arguments: Any?) {}
}
SWIFT
xcrun swiftc -sdk "$sdk_path" -target "$target" -swift-version 5 \
  -emit-module -module-name Flutter "$scratch_dir/Flutter.swift" \
  -emit-module-path "$scratch_dir/Flutter.swiftmodule"
cat > "$scratch_dir/bridging.h" <<'HEADER'
#include "mpv/client.h"
#include "mpv/render.h"
#include "mpv/render_gl.h"
HEADER
plugin="$package_dir/ios/media_kit_video/Sources/media_kit_video/plugin"
common="$package_dir/common/darwin/Classes/plugin"
xcrun swiftc -typecheck -sdk "$sdk_path" -target "$target" -swift-version 5 \
  -I "$scratch_dir" -I "$scratch_dir/Headers" -import-objc-header "$scratch_dir/bridging.h" \
  "$common/ResizableTextureProtocol.swift" "$common/SwappableObjectManager.swift" \
  "$common/MPVHelpers.swift" "$common/MPVVideoOutParams.swift" \
  "$common/Worker.swift" "$common/SafeResizableTexture.swift" \
  "$common/TextureSWContext.swift" "$common/TextureSW.swift" \
  "$common/VideoOutputConfiguration.swift" "$common/VideoOutput.swift" \
  "$common/VideoOutputManager.swift" \
  "$common/UtilsProtocol.swift" "$common/MediaKitVideoPlugin.swift" \
  "$plugin/gles/OpenGLESHelpers.swift" "$plugin/gles/TextureGLESContext.swift" \
  "$plugin/TextureHW.swift"
echo 'iOS arm64 renderer typecheck passed with Apple SDK and pinned mpv headers'
