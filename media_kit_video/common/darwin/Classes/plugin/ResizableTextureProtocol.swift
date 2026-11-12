import CoreGraphics

#if canImport(Flutter)
  import Flutter
#elseif canImport(FlutterMacOS)
  import FlutterMacOS
#endif

public protocol ResizableTextureProtocol: NSObject, FlutterTexture {
  func resize(_ size: CGSize)
  func render(_ size: CGSize)
  // Release mpv while the owning worker is still alive, even when Flutter
  // retains the texture wrapper or a completed pixel buffer beyond close.
  func dispose()
}
