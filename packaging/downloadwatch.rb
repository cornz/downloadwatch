class Downloadwatch < Formula
  desc "Copy completed downloads to the macOS clipboard as native file references"
  homepage "https://github.com/cornz/downloadwatch"
  url "https://github.com/cornz/downloadwatch/releases/download/v0.1.0/downloadwatch-0.1.0-macos-arm64.zip"
  sha256 "96de8b335c4f3186ffcd1101f262bacaca6e974d01818cf1b5085e5497c72dcb"
  license "MIT"

  depends_on arch: :arm64
  depends_on macos: :ventura

  # Preserve the Developer ID signature. Do not strip or patch this executable.
  skip_clean "bin/downloadwatch"

  def install
    bin.install "downloadwatch"
  end

  service do
    run [opt_bin/"downloadwatch"]
    keep_alive false
    run_at_load true
    require_root false
    process_type :background
    log_path var/"log/downloadwatch.log"
    error_log_path var/"log/downloadwatch.log"
  end

  test do
    assert_equal "downloadwatch #{version}", shell_output("#{bin}/downloadwatch --version").strip
    assert_match "Usage: downloadwatch", shell_output("#{bin}/downloadwatch --help")
    system "/usr/bin/codesign", "--verify", "--strict", bin/"downloadwatch"
  end
end
