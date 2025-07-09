<<<<<<< HEAD
# bluestacks-air-oneclick-root
Easily root bluestacks air for macos with one command
=======
# Root BlueStacks Air on macOS

A simple tool to root BlueStacks Air on macOS using Kitsune Magisk.

![Screenshot](/images/bluestacks-air-root-magisk.png)

## Compatibility

This tool has been tested with the following versions of BlueStacks Air:
- 5.21.680.7532
- 5.21.695.7506
- 5.21.700.7523
- 5.21.705.7515
- 5.21.712.7503
- 5.21.715.7538
- 5.21.720.7530

...and with Kitsune Magisk `v27.2-kitsune-4`.

## Prerequisites

1.  **Install [BlueStacks Air](https://www.bluestacks.com/mac).**
2.  **‼️ IMPORTANT ‼️** Open BlueStacks Air at least once to let it initialize, then close it completely.
3.  **Download [Kitsune Magisk](https://github.com/1q23lyc45/KitsuneMagisk/releases).** Download the APK file from the latest release.
4.  **Download this repository.** You can either clone it or download the ZIP and extract it.
5.  **Place the Magisk APK** inside the downloaded repository folder.

## Understanding System Integrity Protection (SIP)

System Integrity Protection (SIP) is a security feature in macOS. The rooting method depends on whether SIP is enabled or disabled on your system.

To check your SIP status, open **Terminal** and run:
```bash
csrutil status
```
The output will tell you if SIP is `enabled` or `disabled`.

---

## 🚀 One-Liner Quick Start

Paste **one** command into Terminal and let the script do the rest.

### Most Macs (SIP ENABLED — manual copy step)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Jordan231111/bluestacks-air-oneclick-root/main/installer.sh)" manual
```

What happens:
1. Repo is cloned to a temporary folder.
2. Latest Kitsune Magisk is auto-downloaded.
3. A patched `initrd_hvf.img.patched` is generated.
4. Terminal prints the file path – just copy it into `/Applications/BlueStacks.app/Contents/img/` (replace the original) and start BlueStacks.

### Advanced (SIP DISABLED — fully automatic)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Jordan231111/bluestacks-air-oneclick-root/main/installer.sh)" root
```

Everything (patch + replacement + BlueStacks launch) is handled automatically.

---

### Buy me a coffee

If you found this tool helpful, consider buying me a coffee!

[![](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://ko-fi.com/yejordan)
>>>>>>> 63e5a8c (Initial version for rooting Bluestacks Air for MacOS.)
