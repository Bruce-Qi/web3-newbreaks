import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    // 默认窗口 1100x760，居中显示；最小 420x600
    self.setContentSize(NSSize(width: 1100, height: 760))
    self.minSize = NSSize(width: 420, height: 600)
    self.title = "Web3 资讯"
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
