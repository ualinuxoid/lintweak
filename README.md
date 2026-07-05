### Welcome to lintweak 👋 
Simple Linux tweaks mainly written in pure bash 🤤

**This is the repo, where I will share my personal Linux tweaks, I created for convenience**

*NOTE: [Github](https://github.com/ualinuxoid/lintweak) is used only as **mirror**. Please use my [codeberg](https://codeberg.org/ualinuxoid/lintweak) if you need to submit anything*

### 😏 Scripts:
- Linux [privacy hardener](https://codeberg.org/ualinuxoid/lintweak/src/branch/main/scripts/Privacy.sh). Github [mirror](https://github.com/ualinuxoid/lintweak/blob/main/scripts/Privacy.sh)
- Linux [adblocker](https://codeberg.org/ualinuxoid/lintweak/src/branch/main/scripts/adblock.sh). Github [mirror](https://github.com/ualinuxoid/lintweak/blob/main/scripts/adblock.sh)
- Linux Mint [MAT2](https://codeberg.org/ualinuxoid/lintweak/src/branch/main/scripts/Mat2.sh). Github [mirror](https://github.com/ualinuxoid/lintweak/blob/main/scripts/Mat2.sh)
- Linux Mint [media shrinker](https://codeberg.org/ualinuxoid/lintweak/src/branch/main/scripts/Compress.sh). Github [mirror](https://github.com/ualinuxoid/lintweak/blob/main/scripts/Compress.sh)
- [YT-DLP GUI](https://codeberg.org/ualinuxoid/lintweak/src/branch/main/scripts/yt-dlp.sh) (extremely lightweight!). Github [mirror](https://github.com/ualinuxoid/lintweak/blob/main/scripts/yt-dlp.sh)
- **And my [rublock](https://codeberg.org/ualinuxoid/lintweak/src/branch/main/misc/rublock.txt) hosts file. Github [mirror](https://github.com/ualinuxoid/lintweak/blob/main/misc/rublock.txt)**

*To run my scripts, simply download preferred .sh file and run `sudo chmod +x /path/to/downloaded/script && sudo bash /path/to/downloaded/script`.*

While you can use direct piping to bash, I strongly recommend you to download and run scripts manually.

If you are feeling risky, you can run:

**Privacy hardener:**
*This script trying to enchance your privacy via applying multiple cosmetic tweaks, such as MAC randomization, NTS setup, DOT setup etc...*
```
sudo curl -s https://codeberg.org/ualinuxoid/lintweak/raw/branch/main/scripts/Privacy.sh | bash
```

**MAT2 installation:**
*This script aims to install [MAT2](https://github.com/jvoisin/mat2) and add convenient `nemo_action` to make it easier to run metadata removal just in right click on file*
```
sudo curl -s https://codeberg.org/ualinuxoid/lintweak/raw/branch/main/scripts/Mat2.sh | bash
```

**Shrink installation:**
*This script aims to install ffmpeg based media compression util as convenient `nemo_action` to make easier to run compress your media just in right click on file*
```
sudo curl -s https://codeberg.org/ualinuxoid/lintweak/raw/branch/main/scripts/Compress.sh | bash
```

**yt-dlp installation:**
*This script aims to install yt-dlp and add extremely lightweight (zenity based) GUI. Desktop shortcut included. Tested on Linux Mint, but it should work on any Ubuntu or Debian based distro (including Pop!OS, Zorin etc) :)*
```
sudo curl -s https://codeberg.org/ualinuxoid/lintweak/raw/branch/main/scripts/yt-dlp.sh | bash
```

**Adblock installation:**
*This script aims to install hosts based adblock. Hosts lists are **NOT** developed by me, and taken from [well-known maintainer](https://github.com/StevenBlack/hosts)*
```
sudo curl -s https://codeberg.org/ualinuxoid/lintweak/raw/branch/main/scripts/adblock.sh | bash
```

### 🧪 Experimental section
**WARNING!** *Experimental section is not tested, and should NOT be used on critical installations! If you consider to use them, always make **FULL** backup befor running anything from this section!*

[Hosts file generator](https://codeberg.org/ualinuxoid/lintweak/raw/branch/main/scripts/crapblock.sh), that blocks most popular .ru and .su domains. [Github mirror.](https://github.com/ualinuxoid/lintweak/blob/main/scripts/crapblock.sh)

[GPG GUI](https://codeberg.org/ualinuxoid/lintweak/raw/branch/main/scripts/crypt.sh), that uses GPG, zenity and pure bash to create lightweight and easy-to-use encryption solution for Linux Mint. [Github mirror](https://github.com/ualinuxoid/lintweak/blob/main/scripts/crypt.sh)

### ℹ️ Info:
Scripts here written in pure bash on purpose. I am trying to make them easily verifiable, even if you are not computer programmer. Transparency is the most important thing, when it is about trust. So I will to avoid other languages as much as possible.

### ⚠️ Disclaimer ⚠️
Proceed **only** if you know what are you doing! I strongly recommend to **review** my scripts before running them.

This project provided "AS IS". I do not responsible for any malfunction caused (if any) by my scripts. You **MUST** make full backups. Please, proceed with caution.

### Proudly developed in Ukraine 🇺🇦 
If you want to support me, please, consider donation to [Ukrainian defenders](https://war.ukraine.ua/)

### Contact info:
enrich-zit-icon@duck.com