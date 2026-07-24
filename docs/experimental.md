### 🧪 Experimental section
**WARNING!** *Experimental section is not tested, and should NOT be used on critical installations! If you consider to use them, always make **FULL** backup befor running anything from this section!*

[Hosts file generator](https://codeberg.org/ualinuxoid/lintweak/raw/branch/main/scripts/crapblock.sh), that blocks most popular .ru and .su domains. [Github mirror.](https://github.com/ualinuxoid/lintweak/blob/main/scripts/crapblock.sh)

[GPG GUI](https://codeberg.org/ualinuxoid/lintweak/raw/branch/main/scripts/crypt.sh), that uses GPG, zenity and pure bash to create lightweight and easy-to-use encryption solution for Linux Mint. [Github mirror](https://github.com/ualinuxoid/lintweak/blob/main/scripts/crypt.sh)

[Email alias GUI](https://codeberg.org/ualinuxoid/lintweak/src/branch/main/scripts/aliaser.sh). Based on curl and zenity. You need an already registered `@duck.com` account to use it. [Github mirror](https://github.com/ualinuxoid/lintweak/blob/main/scripts/aliaser.sh). WARNING! Aliaser is experimental, not tested carefully, and wrote in midnight, it should NOT be used as your only alias solution; fixes and bug reports are welcome though.

To use `Aliaser`, you should first register a `@duck.com` account, then install dependencies via `sudo apt update && sudo apt install curl jq zenity xclip`

`Aliaser` logic was taken from [this](https://github.com/Lanshuns/Qwacky) awesome project.

[Windata](https://codeberg.org/ualinuxoid/lintweak/src/branch/main/scripts/windata.sh). Should help you to extract your personal files from Windows machine. Designed to run from live Debian-based Linux. *Experimental tool*. [Github mirror](https://github.com/ualinuxoid/lintweak/blob/main/scripts/windata.sh)

[Reed-Solomon](https://codeberg.org/ualinuxoid/lintweak/src/branch/main/scripts/reed-solomon.sh) file protector. Aims to help you not to loose or damage your data on partially faulty storage systems. In short - this will try to prevent data corruption. ***WARNING: I am NOT python developer!** I respect my users and will NOT put this tool in main section untill it passes someone's review.* **USE ON OWN RISK** [Github mirror](https://github.com/ualinuxoid/lintweak/blob/main/scripts/reed-solomon.sh)