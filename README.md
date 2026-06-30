### lintweak
Simple Linux tweaks mainly written in pure bash 🤤

**This is the repo, where I will share my personal Linux tweaks, I created for convenience**

*NOTE: [Github](https://github.com/ualinuxoid/lintweak) is used only as **mirror**. Please use my [codeberg](https://codeberg.org/ualinuxoid/lintweak) if you need to submit anything*

### 😏 Scripts:
- Linux [privacy hardener](https://codeberg.org/ualinuxoid/lintweak/src/branch/main/scripts/Privacy.sh). Github [mirror](https://github.com/ualinuxoid/lintweak/blob/main/scripts/Privacy.sh)
- Linux [adblocker](https://codeberg.org/ualinuxoid/lintweak/src/branch/main/scripts/adblock.sh). Github [mirror](https://github.com/ualinuxoid/lintweak/blob/main/scripts/adblock.sh)
- Linux Mint [MAT2](https://codeberg.org/ualinuxoid/lintweak/src/branch/main/scripts/Mat2.sh). Github [mirror](https://github.com/ualinuxoid/lintweak/blob/main/scripts/Mat2.sh)
- Linux Mint [media shrinker](https://codeberg.org/ualinuxoid/lintweak/src/branch/main/scripts/Compress.sh). Github [mirror](https://github.com/ualinuxoid/lintweak/blob/main/scripts/Compress.sh)
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

**Adblock installation:**
*This script aims to install hosts based adblock. Hosts lists are **NOT** developed by me, and taken from [well-known maintainer](https://github.com/StevenBlack/hosts)*
```
sudo curl -s https://codeberg.org/ualinuxoid/lintweak/raw/branch/main/scripts/adblock.sh | bash
```

### ⚠️⚠️⚠️ Disclaimer ⚠️⚠️⚠️
Proceed **only** if you know what are you doing! I strongly recommend to **review** my scripts before running them.

This project provided "AS IS". I do not responsible for any malfunction caused (if any) by my scripts. Please, proceed with caution.

### Proudly developed in Ukraine 🇺🇦 
If you want to support me, please, consider donation to [Ukrainian defenders](https://war.ukraine.ua/)