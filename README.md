### Welcome to lintweak 👋 
Simple Linux tweaks mainly written in pure bash 🤤

**This is the repo, where I will share my personal Linux tweaks, I created for convenience**

*NOTE: [Github](https://github.com/ualinuxoid/lintweak) is used only as **mirror**. Please use my [codeberg](https://codeberg.org/ualinuxoid/lintweak) if you need to submit anything*

### 🌐 My [website](https://ualinuxoid.github.io/)
***I recommend you to read docs exactly via website for convenience***

### 😏 Scripts:

| Script | Description | Type |
|--------|-------------|------|
| [tor.sh](https://codeberg.org/ualinuxoid/lintweak/src/branch/main/scripts/tor.sh) | Tor as system-wide "VPN" (full traffic through Tor) | Installer |
| [wguard.sh](https://codeberg.org/ualinuxoid/lintweak/src/branch/main/scripts/wguard.sh) | Identity hiding: random MAC, OUI spoof, temporary hostname + GUI | Installer |
| [noru.sh](https://codeberg.org/ualinuxoid/lintweak/src/branch/main/scripts/noru.sh) | Aggressive Runet blocker (normal / aggressive / extreme modes) | Installer |
| [Privacy.sh](https://codeberg.org/ualinuxoid/lintweak/src/branch/main/scripts/Privacy.sh) | Light privacy tweaks (MAC randomization, NTS, DoT etc.) | Installer |
| [adblock.sh](https://codeberg.org/ualinuxoid/lintweak/src/branch/main/scripts/adblock.sh) | Hosts-based adblocker (StevenBlack lists + optional categories) | Installer |
| [ssdshield.sh](https://codeberg.org/ualinuxoid/lintweak/src/branch/main/scripts/ssdshield.sh) | SSD lifespan optimizations (trim, scheduler, mount options) | Installer |
| [rbak.sh](https://codeberg.org/ualinuxoid/lintweak/src/branch/main/scripts/rbak.sh) | Portable rsync backup (only new/changed files) + zenity GUI | Portable |
| [sbak.sh](https://codeberg.org/ualinuxoid/lintweak/src/branch/main/scripts/sbak.sh) | Portable 7z backup/restore with optional AES-256 + split for Telegram | Portable |
| [Mat2.sh](https://codeberg.org/ualinuxoid/lintweak/src/branch/main/scripts/Mat2.sh) | Install MAT2 + Nemo action for metadata removal | Installer |
| [Compress.sh](https://codeberg.org/ualinuxoid/lintweak/src/branch/main/scripts/Compress.sh) | ffmpeg media compression as Nemo action | Installer |
| [yt-dlp.sh](https://codeberg.org/ualinuxoid/lintweak/src/branch/main/scripts/yt-dlp.sh) | yt-dlp + very lightweight zenity GUI | Installer |
| [setup.sh](https://codeberg.org/ualinuxoid/lintweak/src/branch/main/scripts/setup.sh) | First-time helper for newbies (Debian/Ubuntu/Mint) | Installer |
| [wg-rnd.sh](https://codeberg.org/ualinuxoid/lintweak/src/branch/main/scripts/wg-rnd.sh) | Quick WireGuard config switcher via hotkey | Utility |

<details>
<summary>GitHub mirror:</summary>

| Script | Description | Type |
|--------|-------------|------|
| [tor.sh](https://github.com/ualinuxoid/lintweak/blob/main/scripts/tor.sh) | Tor as system-wide "VPN" | Installer |
| [wguard.sh](https://github.com/ualinuxoid/lintweak/blob/main/scripts/wguard.sh) | Identity hiding (MAC, OUI, hostname) + GUI | Installer |
| [noru.sh](https://github.com/ualinuxoid/lintweak/blob/main/scripts/noru.sh) | Aggressive Runet blocker | Installer |
| [Privacy.sh](https://github.com/ualinuxoid/lintweak/blob/main/scripts/Privacy.sh) | Light privacy tweaks (MAC, NTS, DoT) | Installer |
| [adblock.sh](https://github.com/ualinuxoid/lintweak/blob/main/scripts/adblock.sh) | Hosts-based adblocker (StevenBlack) | Installer |
| [ssdshield.sh](https://github.com/ualinuxoid/lintweak/blob/main/scripts/ssdshield.sh) | SSD lifespan optimizations | Installer |
| [rbak.sh](https://github.com/ualinuxoid/lintweak/blob/main/scripts/rbak.sh) | Portable rsync backup (new/changed only) | Portable |
| [sbak.sh](https://github.com/ualinuxoid/lintweak/blob/main/scripts/sbak.sh) | Portable 7z backup + split for Telegram | Portable |
| [Mat2.sh](https://github.com/ualinuxoid/lintweak/blob/main/scripts/Mat2.sh) | MAT2 + Nemo action | Installer |
| [Compress.sh](https://github.com/ualinuxoid/lintweak/blob/main/scripts/Compress.sh) | ffmpeg media compression (Nemo) | Installer |
| [yt-dlp.sh](https://github.com/ualinuxoid/lintweak/blob/main/scripts/yt-dlp.sh) | yt-dlp + lightweight zenity GUI | Installer |
| [setup.sh](https://github.com/ualinuxoid/lintweak/blob/main/scripts/setup.sh) | First-time helper for newbies | Installer |
| [wg-rnd.sh](https://github.com/ualinuxoid/lintweak/blob/main/scripts/wg-rnd.sh) | Quick WireGuard config switcher | Utility |

</details>

### 🕶 Usage

*To run my scripts, simply download preferred .sh file and run `sudo chmod +x /path/to/downloaded/script && sudo bash /path/to/downloaded/script` or see link to run tips below*

**See usage documentation:**
[Codeberg](https://codeberg.org/ualinuxoid/lintweak/src/branch/main/docs/quick-start.md) or [Github](https://github.com/ualinuxoid/lintweak/blob/main/docs/quick-start.md)


### 🧹 Ublock filters:

I have [filters](https://codeberg.org/ualinuxoid/lintweak/src/branch/main/misc/ubo.txt), designed for UBlock Origin. Currently focused only on youtube to prevent autodubbing from working (enforce original audio). [Github mirror](https://github.com/ualinuxoid/lintweak/blob/main/misc/ubo.txt)

**Info**: to make them work, tick "trust custom filters" box (translation can vary with your locale).

### ⭕️ Miscellaneous section:
[wg-rnd.sh](https://codeberg.org/ualinuxoid/lintweak/src/branch/main/scripts/wg-rnd.sh). Created to avoid installing ovrbloated or paid-demanding VPN clients. Uses native WireGuard support and .conf files and easily change them via hotkey.
***Be sure to edit path with vpn .conf files and set correct permissions, so random apps will not be able to see your private key from your wireguard files!*** [Github mirror](https://github.com/ualinuxoid/lintweak/blob/main/scripts/wg-rnd.sh) of wg-rnd.sh.

*NOTE: wg-rnd.sh tested only on Linux Mint, but should work on many other systems like Ubuntu*

**And my [rublock](https://codeberg.org/ualinuxoid/lintweak/src/branch/main/misc/rublock.txt) hosts file. Github [mirror](https://github.com/ualinuxoid/lintweak/blob/main/misc/rublock.txt)**

**🧪 I also have few experimental scripts.** You can see them [here](https://codeberg.org/ualinuxoid/lintweak/src/branch/main/docs/experimental.md) (or on [Github](https://github.com/ualinuxoid/lintweak/blob/main/docs/experimental.md))

### ℹ️ Info:
Scripts here written in pure bash on purpose. I am trying to make them easily verifiable, even if you are not computer programmer. Transparency is the most important thing, when it is about trust. So I will to avoid other languages as much as possible.

### ⚠️ Disclaimer ⚠️
Proceed **only** if you know what are you doing! I strongly recommend to **review** my scripts before running them.

This project provided "AS IS". I do not responsible for any malfunction caused (if any) by my scripts. You **MUST** make full backups. Please, proceed with caution.

### 🙏 Help needed:
*I will bereally glad, if some of you will report problems and provide fixes or improvements for "experimental section".*

### Proudly created in Ukraine 🇺🇦 
**If you can, please donate to Ukrainian defenders:**

*https://war.ukraine.ua or https://savelife.in.ua*

**Glory to Ukraine! Stop the war!**

*Contact info can be found on [Codeberg](https://codeberg.org/ualinuxoid/me) or on [Github](https://github.com/ualinuxoid/me)*

<p align="center">
License: GPLv2-or-later
</p>