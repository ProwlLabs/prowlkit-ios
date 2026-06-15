class Prowl < Formula
  desc "Terminal network inspector for ProwlKit — live relay, sessions, and export"
  homepage "https://github.com/ProwlKit/prowlkit-ios"
  license "MIT"
  head "https://github.com/ProwlKit/prowlkit-ios.git", branch: "main"

  # Stable releases (update url + sha256 when shipping CLI binaries in a tag).
  # url "https://github.com/ProwlKit/prowlkit-ios/archive/refs/tags/1.1.0.tar.gz"
  # sha256 "REPLACE_ON_RELEASE"

  depends_on xcode: ["15.0", :build]

  def install
    system "swift", "build", "-c", "release", "--product", "prowl", "--disable-sandbox"
    bin.install ".build/release/prowl"
  end

  test do
    assert_match "listen", shell_output("#{bin}/prowl --help")
  end
end
