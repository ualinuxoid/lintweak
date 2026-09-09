#!/bin/bash
# ==============================================================================
# dehasher.sh v3.0 — Media Sanitizer & Anti-Forensic Tool
# ==============================================================================
# Modes: safe | normal | aggressive | extreme
#   extreme — Poisoning, micro-lines, channel shift, temporal pulsing,
#             frame-bordering, and psychovisual noise warfare.
#             Moderate visible distortion is ACCEPTABLE.
#
# WARNING: For privacy protection only. Do not use for any illict activity
# By using this script, you agree, that ualinuxoid (or any other person hosting
# this script) NOT responsible for your actions.
#
# Motivation: Break AI crawlers, Google photo search, Meta photo profiling etc,
# so your media stays yours, preventing you from being doxxed via OSINT
# ==============================================================================
# Usage examples:
# ==============================================================================
# One file (extreme)
# ./dehasher.sh -m extreme photo.jpg
# Batch with progress bar
# ./dehasher.sh -m extreme -f *.mp4 *.jpg
# Verbose
# ./dehasher.sh -v -m extreme video.mp4
# help
# ./dehasher.sh --help
# =============================================================================
# Proudly created in Ukraine!
# =============================================================================
# If you can, please donate to Ukrainian defenders:
# https://war.ukraine.ua or https://savelife.in.ua
# =============================================================================
# Glory to Ukraine! Stop the war!
# =============================================================================


set -euo pipefail

readonly VERSION="3.0"
readonly SCRIPT_NAME=$(basename "$0")

if [[ -t 1 ]]; then
    readonly C_R='\033[0;31m' C_G='\033[0;32m' C_Y='\033[1;33m'
    readonly C_B='\033[0;34m' C_C='\033[0;36m' C_N='\033[0m'
else
    readonly C_R='' C_G='' C_Y='' C_B='' C_C='' C_N=''
fi

VERBOSE=0
QUIET=0
FORCE=0
KEEP_META=0
MODE="aggressive"
OUTPUT=""
TOTAL=0
DONE=0

MAGICK_CMD="convert"
if command -v magick &>/dev/null; then
    MAGICK_CMD="magick"
fi

draw_progress() {
    local current=$1 total=$2
    local pct=$(( current * 100 / total ))
    local width=35
    local filled=$(( width * current / total ))
    local empty=$(( width - filled ))
    printf "\r\033[K${C_B}["
    printf "%${filled}s" | tr ' ' '='
    printf "%${empty}s" | tr ' ' ' '
    printf "]${C_N} ${C_G}%3d%%${C_N} ${C_C}(%d/%d)${C_N}" "$pct" "$current" "$total"
}

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS] <file1> [file2 ...]

Options:
  -o <path>    Output file or directory (default: <name>_dehashed.<ext>)
  -m <mode>    Processing mode: safe | normal | aggressive | extreme
               (default: aggressive)
  -k           Keep metadata (NOT recommended for privacy)
  -f           Force overwrite existing files
  -q           Quiet mode
  -v           Verbose mode (shows exact random parameters)
  -h, --help   Show this help

Modes:
  safe       — Minimal changes, highest fidelity. Defeats file-hash & metadata.
  normal     — Moderate perturbation. Defeats basic perceptual hashes.
  aggressive — Strong perturbation. Defeats pHash/dHash/Neural Hash.
  extreme    — MAXIMUM WARFARE. Poisoning, micro-lines, channel shift,
               temporal pulsing, psychovisual noise. Moderate distortion
               is ACCEPTABLE. Use when Google still finds your media.

Examples:
  $SCRIPT_NAME photo.jpg
  $SCRIPT_NAME -m extreme -o ./clean/ video.mp4
  $SCRIPT_NAME -f -m extreme *.jpg *.png
  $SCRIPT_NAME --help
  
==========================================================
Proudly created in Ukraine!
==========================================================
If you can, please donate to Ukrainian defenders:
https://war.ukraine.ua or https://savelife.in.ua
==========================================================
Glory to Ukraine! Stop the war!
==========================================================
EOF
}

error() { echo -e "${C_R}[ERROR]${C_N} $*" >&2; exit 1; }
warn()  { echo -e "${C_Y}[WARN]${C_N}  $*" >&2; }
info()  { [[ "$QUIET" -eq 0 ]] && echo -e "${C_G}[INFO]${C_N}  $*"; }
verbose() { [[ "$VERBOSE" -eq 1 ]] && echo -e "${C_C}[DBG]${C_N}   $*"; }

check_deps() {
    local missing=()
    if ! command -v "$MAGICK_CMD" &>/dev/null; then
        missing+=("ImageMagick (convert or magick)")
    fi
    if ! command -v ffmpeg &>/dev/null; then
        missing+=("ffmpeg")
    fi
    if ! command -v ffprobe &>/dev/null; then
        missing+=("ffprobe")
    fi
    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing dependencies: ${missing[*]}\nInstall:\n  apt:  sudo apt install imagemagick ffmpeg\n  dnf:  sudo dnf install ImageMagick ffmpeg\n  pacman: sudo pacman -S imagemagick ffmpeg"
    fi
}

random_int() {
    local min=$1 max=$2
    local seed
    seed=$(od -An -N4 -tu4 /dev/urandom | tr -d ' \n')
    echo "$(( min + (seed % (max - min + 1)) ))"
}

random_float() {
    local min=$1 max=$2 prec=${3:-4}
    if command -v python3 &>/dev/null; then
        python3 -c "
import random, struct
seed = struct.unpack('I', open('/dev/urandom','rb').read(4))[0]
random.seed(seed)
print(f'{random.uniform($min, $max):.{prec}f}')
"
    else
        local seed
        seed=$(od -An -N4 -tu4 /dev/urandom | tr -d ' \n')
        awk -v min="$min" -v max="$max" -v prec="$prec" -v seed="$seed" '
        BEGIN{srand(seed); fmt="%."prec"f"; printf fmt, min+rand()*(max-min)}'
    fi
}

random_choice() {
    local arr=("$@")
    local idx
    idx=$(random_int 0 $(( ${#arr[@]} - 1 )))
    echo "${arr[$idx]}"
}

process_image() {
    local input=$1 output=$2
    local w h rot scale bright sat hue noise blur sharp stretch qual dither sample dct_method interlace
    local spread wave_amp wave_len swirl implode posterize border_w crop_x crop_y
    local channel_shift_r channel_shift_g channel_shift_b micro_lines colorize

    w=$($MAGICK_CMD identify -format "%w" "$input" 2>/dev/null) || error "Cannot identify image: $input"
    h=$($MAGICK_CMD identify -format "%h" "$input" 2>/dev/null)

    case "$MODE" in
        safe)
            rot=$(random_float -0.05 0.05 2)
            scale=$(random_float 99.95 100.05 2)
            bright=$(random_float 99.5 100.5 1)
            sat=$(random_float 99.5 100.5 1)
            hue=$(random_float -0.5 0.5 2)
            noise=$(random_float 0.15 0.35 2)
            blur=$(random_float 0.05 0.15 2)
            sharp=$(random_float 0.05 0.15 2)
            stretch=$(random_float 0.1 0.4 2)
            qual=$(random_int 92 96)
            ;;
        normal)
            rot=$(random_float -0.25 0.25 2)
            scale=$(random_float 99.8 100.2 2)
            bright=$(random_float 98.5 101.5 1)
            sat=$(random_float 98 102 1)
            hue=$(random_float -1.5 1.5 2)
            noise=$(random_float 0.3 0.7 2)
            blur=$(random_float 0.1 0.3 2)
            sharp=$(random_float 0.1 0.3 2)
            stretch=$(random_float 0.3 1.0 2)
            qual=$(random_int 87 93)
            ;;
        aggressive)
            rot=$(random_float -0.6 0.6 2)
            scale=$(random_float 99.6 100.4 2)
            bright=$(random_float 97.5 102.5 1)
            sat=$(random_float 97 103 1)
            hue=$(random_float -2.5 2.5 2)
            noise=$(random_float 0.5 1.2 2)
            blur=$(random_float 0.15 0.4 2)
            sharp=$(random_float 0.15 0.4 2)
            stretch=$(random_float 0.5 1.8 2)
            qual=$(random_int 84 90)
            ;;
        extreme)
            rot=$(random_float -2.0 2.0 2)
            scale=$(random_float 98.5 101.5 2)
            bright=$(random_float 94 106 1)
            sat=$(random_float 92 108 1)
            hue=$(random_float -8.0 8.0 2)
            noise=$(random_float 1.5 3.5 2)
            blur=$(random_float 0.3 0.8 2)
            sharp=$(random_float 0.3 0.8 2)
            stretch=$(random_float 1.5 4.0 2)
            qual=$(random_int 72 82)
            spread=$(random_int 1 2)
            wave_amp=$(random_float 0.5 2.5 2)
            wave_len=$(( w / 50 + 1 ))
            swirl=$(random_float -1.0 1.0 2)
            implode=$(random_float 0.97 1.03 3)
            posterize=$(random_int 5 7)
            border_w=$(random_int 1 3)
            channel_shift_r=$(random_float -3 3 2)
            channel_shift_g=$(random_float -3 3 2)
            channel_shift_b=$(random_float -3 3 2)
            micro_lines=$(random_int 5 12)
            colorize=$(random_float 1 4 2)
            crop_x=$(random_int 0 2)
            crop_y=$(random_int 0 2)
            ;;
    esac

    dither=$(random_int 2 4)
    sample=$(random_choice "4:2:0" "4:2:2" "4:4:4")
    dct_method=$(random_choice "integer" "float")
    interlace=$(random_choice "None" "Plane" "Partition")

    verbose "Image mode=$MODE rot=${rot}° scale=${scale}% bright=${bright}% sat=${sat}% hue=${hue}° noise=${noise}%"

    local args=()

    # Metadata annihilation
    if [[ "$KEEP_META" -eq 0 ]]; then
        args+=(-strip +profile "*" -set comment "" -units PixelsPerInch -density 72)
    fi

    if [[ "$MODE" == "extreme" ]]; then
        # Build poison draw commands (micro-lines + dead pixels)
        local draw_cmds=""
        for ((i=0; i<micro_lines; i++)); do
            local x1=$((RANDOM % w)) y1=$((RANDOM % h))
            local x2=$((RANDOM % w)) y2=$((RANDOM % h))
            draw_cmds+="line $x1,$y1 $x2,$y2 "
        done
        local poison_dots=$((RANDOM % 11 + 10))
        for ((i=0; i<poison_dots; i++)); do
            local px=$((RANDOM % w)) py=$((RANDOM % h))
            local pr=$((RANDOM % 40 + 100))
            local pg=$((RANDOM % 40 + 100))
            local pb=$((RANDOM % 40 + 100))
            draw_cmds+="fill rgb($pr,$pg,$pb) rectangle $px,$py $((px+1)),$((py+1)) "
        done

        args+=(
            -colorspace sRGB -depth 8
            # 1. Geometric annihilation
            -virtual-pixel Edge
            -distort SRT "$rot"
            +repage
            -crop "$((w-crop_x*2))x$((h-crop_y*2))+${crop_x}+${crop_y}"
            +repage
            -background "rgb($(random_int 0 15),$(random_int 0 15),$(random_int 0 15))"
            -gravity center
            -extent "${w}x${h}"
            -resize "${scale}%x${scale}%"
            -spread "${spread}"
            -wave "${wave_amp}x${wave_len}"
            -swirl "$swirl"
            -implode "$implode"
            # 2. Color channel destruction
            -channel R -evaluate Add "${channel_shift_r}%" +channel
            -channel G -evaluate Add "${channel_shift_g}%" +channel
            -channel B -evaluate Add "${channel_shift_b}%" +channel
            +channel
            -modulate "${bright},${sat}"
            -hue-shift "${hue}"
            -contrast-stretch "${stretch}%x${stretch}%"
            -posterize "$posterize"
            # 3. Noise & texture war
            -evaluate Gaussian-noise "${noise}%"
            -adaptive-blur "${blur}x${blur}"
            -adaptive-sharpen "${sharp}x${sharp}"
            -ordered-dither "threshold,8x8"
            # 4. Poisoning (invisible micro-perturbations)
            -fill "rgba(128,128,128,0.06)"
            -stroke "rgba(128,128,128,0.04)"
            -strokewidth 1
            -draw "$draw_cmds"
            # 5. Border & finalize
            -bordercolor "rgb($(random_int 0 20),$(random_int 0 20),$(random_int 0 20))"
            -border "${border_w}x${border_w}"
            -colorize "${colorize}%"
            # 6. Compression fingerprint randomization
            -sampling-factor "$(random_choice "4:2:0" "4:2:2")"
            -quality "$qual"
            -define "jpeg:dct-method=$(random_choice integer float)"
            -define jpeg:optimize-coding=on
            -interlace "$(random_choice None Plane Partition)"
        )
    else
        args+=(
            -colorspace sRGB -depth 8
            -virtual-pixel Edge
            -distort SRT "$rot"
            +repage
            -crop "${w}x${h}+0+0"
            +repage
            -resize "${scale}%x${scale}%"
            -modulate "${bright},${sat}"
            -hue-shift "${hue}"
            -contrast-stretch "${stretch}%x${stretch}%"
            -evaluate Gaussian-noise "${noise}%"
            -adaptive-blur "${blur}x${blur}"
            -adaptive-sharpen "${sharp}x${sharp}"
        )
        if [[ "$MODE" != "safe" ]]; then
            args+=(-ordered-dither "threshold,${dither}x${dither}")
        fi
        args+=(
            -sampling-factor "${sample}"
            -quality "${qual}"
            -define "jpeg:dct-method=${dct_method}"
            -define jpeg:optimize-coding=on
            -interlace "${interlace}"
        )
    fi

    $MAGICK_CMD "$input" "${args[@]}" "$output"
}

process_video() {
    local input=$1 output=$2
    local crf preset tune keyint bf refs deblock trellis aq_mode aq_strength rc_lookahead psy_rd psy_trellis mbtree
    local pix_fmt fps abitrate asr vol scale bright cont sat hue noise_y noise_uv unsharp speed eq_pulse eq_freq hue_pulse border_w vignette_angle

    local orig_fps
    orig_fps=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=noprint_wrappers=1:nokey=1 "$input" 2>/dev/null | head -n 1) || true
    [[ -z "$orig_fps" ]] && orig_fps="30/1"

    case "$MODE" in
        safe)
            crf=$(random_int 19 21)
            scale=$(random_float 99.9 100.1 2)
            bright=$(random_float -0.015 0.015 4)
            cont=$(random_float 0.985 1.015 4)
            sat=$(random_float 0.985 1.015 4)
            hue=$(random_float -0.02 0.02 4)
            noise_y=$(random_float 0.1 0.25 2)
            noise_uv=$(random_float 0.05 0.12 2)
            unsharp=$(random_float 0.3 0.6 2)
            preset="medium"; tune="film"
            keyint=60; bf=2; refs=3; deblock=0; trellis=1; aq_mode=2
            rc_lookahead=40; aq_strength=1.0; psy_rd=1.0; psy_trellis=0.0; mbtree="true"
            pix_fmt="yuv420p"; abitrate=192; asr=48000; vol=1.0
            ;;
        normal)
            crf=$(random_int 21 24)
            scale=$(random_float 99.7 100.3 2)
            bright=$(random_float -0.03 0.03 4)
            cont=$(random_float 0.97 1.03 4)
            sat=$(random_float 0.97 1.03 4)
            hue=$(random_float -0.05 0.05 4)
            noise_y=$(random_float 0.2 0.5 2)
            noise_uv=$(random_float 0.1 0.25 2)
            unsharp=$(random_float 0.5 1.0 2)
            preset=$(random_choice "medium" "slow")
            tune=$(random_choice "film" "grain")
            keyint=$(random_int 48 90); bf=$(random_int 2 4); refs=$(random_int 2 5)
            deblock=$(random_int -2 2); trellis=$(random_int 1 2); aq_mode=$(random_int 1 3)
            rc_lookahead=$(random_int 30 60); aq_strength=$(random_float 0.8 1.5 2)
            psy_rd=$(random_float 0.8 1.5 2); psy_trellis=$(random_float 0.0 0.5 2); mbtree="true"
            pix_fmt=$(random_choice "yuv420p" "yuv422p"); abitrate=$(random_int 128 256)
            asr=$(random_choice 44100 48000); vol=$(random_float 0.98 1.02 3)
            ;;
        aggressive)
            crf=$(random_int 23 26)
            scale=$(random_float 99.4 100.6 2)
            bright=$(random_float -0.05 0.05 4)
            cont=$(random_float 0.95 1.05 4)
            sat=$(random_float 0.95 1.05 4)
            hue=$(random_float -0.08 0.08 4)
            noise_y=$(random_float 0.4 0.9 2)
            noise_uv=$(random_float 0.2 0.45 2)
            unsharp=$(random_float 0.7 1.3 2)
            preset=$(random_choice "medium" "slow" "slower")
            tune=$(random_choice "film" "grain" "fastdecode")
            keyint=$(random_int 48 120); bf=$(random_int 2 5); refs=$(random_int 2 6)
            deblock=$(random_int -3 3); trellis=$(random_int 1 2); aq_mode=$(random_int 1 3)
            rc_lookahead=$(random_int 30 80); aq_strength=$(random_float 0.6 1.8 2)
            psy_rd=$(random_float 0.6 1.8 2); psy_trellis=$(random_float 0.0 0.8 2); mbtree=$(random_choice "true" "false")
            pix_fmt=$(random_choice "yuv420p" "yuv422p"); abitrate=$(random_int 128 256)
            asr=$(random_choice 44100 48000); vol=$(random_float 0.98 1.02 3)
            ;;
        extreme)
            crf=$(random_int 27 33)
            scale=$(random_float 98.0 102.0 2)
            bright=$(random_float -0.12 0.12 4)
            cont=$(random_float 0.88 1.12 4)
            sat=$(random_float 0.88 1.12 4)
            hue=$(random_float -0.25 0.25 4)
            noise_y=$(random_float 1.2 2.5 2)
            noise_uv=$(random_float 0.6 1.2 2)
            unsharp=$(random_float 1.2 2.0 2)
            speed=$(random_float 0.97 1.03 3)
            eq_pulse=$(random_float 0.03 0.08 3)
            eq_freq=$(random_float 2 5 1)
            hue_pulse=$(random_float 3 8 1)
            border_w=$(random_int 2 4)
            vignette_angle=$(random_float 0.5 1.0 2)

            preset=$(random_choice "slow" "slower" "veryslow")
            tune=$(random_choice "film" "grain" "stillimage" "fastdecode")
            keyint=$(random_int 24 250)
            bf=$(random_int 0 8)
            refs=$(random_int 1 6)
            deblock=$(random_int -6 6)
            trellis=$(random_int 0 2)
            aq_mode=$(random_int 0 3)
            aq_strength=$(random_float 0.5 2.5 2)
            rc_lookahead=$(random_int 20 120)
            psy_rd=$(random_float 0.5 2.0 2)
            psy_trellis=$(random_float 0.0 1.0 2)
            mbtree=$(random_choice "true" "false")
            pix_fmt=$(random_choice "yuv420p" "yuv422p")
            abitrate=$(random_int 96 192)
            asr=$(random_choice 44100 48000)
            vol=$(random_float 0.95 1.05 3)
            ;;
    esac

    if [[ "$orig_fps" == */* ]]; then
        local num=${orig_fps%/*} den=${orig_fps#*/} perturb
        perturb=$(random_int -3 3)
        [[ "$perturb" -eq 0 ]] && perturb=1
        fps=$(awk -v n="$num" -v d="$den" -v p="$perturb" 'BEGIN{printf "%.4f", (n+p)/d}')
    else
        local seed
        seed=$(od -An -N4 -tu4 /dev/urandom | tr -d ' \n')
        fps=$(awk -v fps="$orig_fps" -v seed="$seed" 'BEGIN{srand(seed); printf "%.4f", fps * (1 + (rand()-0.5)*0.005)}')
    fi

    verbose "Video mode=$MODE crf=${crf} preset=${preset} scale=${scale}% fps=${fps} speed=${speed}x"

    local ffmpeg_args=(-y)
    if [[ "$KEEP_META" -eq 0 ]]; then
        ffmpeg_args+=(-map_metadata -1 -map_chapters -1 -fflags +bitexact)
    fi
    ffmpeg_args+=(-i "$input")

    local vf=""
    if [[ "$MODE" == "extreme" ]]; then
        vf="format=${pix_fmt},noise=c0s=${noise_y}:c0f=t+u:c1s=${noise_uv}:c1f=t+u:c2s=${noise_uv}:c2f=t+u,scale=iw*${scale}/100:ih*${scale}/100:flags=lanczos,eq=brightness=${bright}+${eq_pulse}*sin(T*${eq_freq}):contrast=${cont}:saturation=${sat},hue=H=${hue}+${hue_pulse}*sin(T*1.5),unsharp=7:7:${unsharp}:7:7:${unsharp},vignette=PI*${vignette_angle},colorchannelmixer=rr=0.94:rg=0.04:rb=0.02:gr=0.03:gg=0.94:gb=0.03:br=0.02:bg=0.04:bb=0.94,pad=iw+${border_w}*2:ih+${border_w}*2:${border_w}:${border_w}:black,fps=${fps},setpts=PTS/${speed}"
    else
        vf="format=${pix_fmt},noise=c0s=${noise_y}:c0f=t+u:c1s=${noise_uv}:c1f=t+u:c2s=${noise_uv}:c2f=t+u,scale=iw*${scale}/100:ih*${scale}/100:flags=lanczos,eq=brightness=${bright}:contrast=${cont}:saturation=${sat}:hue=${hue},unsharp=3:3:${unsharp}:3:3:${unsharp},fps=${fps}"
    fi

    ffmpeg_args+=(
        -vf "$vf"
        -c:v libx264
        -crf "$crf"
        -preset "$preset"
        -tune "$tune"
        -g "$keyint"
        -keyint_min "$((keyint / 2))"
        -sc_threshold 0
        -bf "$bf"
        -refs "$refs"
        -deblock "$deblock:$deblock"
        -trellis "$trellis"
        -aq-mode "$aq_mode"
        -x264opts "rc-lookahead=${rc_lookahead}:aq-strength=${aq_strength}:psy-rd=${psy_rd}:psy-trellis=${psy_trellis}:mbtree=${mbtree}"
        -pix_fmt "$pix_fmt"
        -c:a aac
        -b:a "${abitrate}k"
        -ar "$asr"
        -movflags +faststart
    )

    if [[ "$MODE" == "extreme" ]]; then
        ffmpeg_args+=(-af "atempo=${speed},volume=${vol},highpass=f=20,lowpass=f=20000")
    else
        ffmpeg_args+=(-af "volume=${vol},highpass=f=20,lowpass=f=20000")
    fi

    ffmpeg_args+=("$output")

    if [[ "$VERBOSE" -eq 1 ]]; then
        ffmpeg "${ffmpeg_args[@]}"
    else
        ffmpeg "${ffmpeg_args[@]}" 2>/dev/null
    fi
}

main() {
    check_deps

    [[ $# -eq 0 ]] && { usage; exit 1; }

    TOTAL=$#
    local input

    for input in "$@"; do
        ((DONE++))

        if [[ ! -f "$input" ]]; then
            warn "File not found: $input"
            draw_progress "$DONE" "$TOTAL"
            printf "\n"
            continue
        fi

        local dir base name ext ext_lower
        dir=$(dirname "$input")
        base=$(basename "$input")
        name="${base%.*}"
        ext="${base##*.}"
        ext_lower=$(echo "$ext" | tr '[:upper:]' '[:lower:]')

        local out
        if [[ -n "$OUTPUT" ]]; then
            if [[ -d "$OUTPUT" ]]; then
                out="${OUTPUT}/${name}_dehashed.${ext}"
            else
                out="$OUTPUT"
            fi
        else
            out="${dir}/${name}_dehashed.${ext}"
        fi

        if [[ "$(realpath "$out" 2>/dev/null || echo "$out")" == "$(realpath "$input" 2>/dev/null || echo "$input")" ]]; then
            warn "Skipping $base: output path is the same as input"
            draw_progress "$DONE" "$TOTAL"
            printf "\n"
            continue
        fi

        if [[ -f "$out" && "$FORCE" -eq 0 ]]; then
            warn "Exists (use -f to overwrite): $out"
            draw_progress "$DONE" "$TOTAL"
            printf "\n"
            continue
        fi

        local start_time end_time elapsed
        start_time=$(date +%s)

        info "[$DONE/$TOTAL] $base  (mode: $MODE)"

        case "$ext_lower" in
            jpg|jpeg|png|webp|bmp|tiff|tif|gif|avif|heic)
                process_image "$input" "$out" || { warn "Failed: $input"; draw_progress "$DONE" "$TOTAL"; printf "\n"; continue; }
                ;;
            mp4|mkv|mov|avi|webm|m4v|flv|wmv|ogv|mpg|mpeg|ts)
                process_video "$input" "$out" || { warn "Failed: $input"; draw_progress "$DONE" "$TOTAL"; printf "\n"; continue; }
                ;;
            *)
                warn "Unsupported extension: .$ext"
                draw_progress "$DONE" "$TOTAL"
                printf "\n"
                continue
                ;;
        esac

        end_time=$(date +%s)
        elapsed=$((end_time - start_time))

        [[ "$QUIET" -eq 0 ]] && draw_progress "$DONE" "$TOTAL"
        [[ "$QUIET" -eq 0 ]] && printf "  %s  (%ds)\n" "$base" "$elapsed"
    done

    [[ "$QUIET" -eq 0 ]] && draw_progress "$TOTAL" "$TOTAL" && printf "\n"
    info "All done!"
}

for arg in "$@"; do
    if [[ "$arg" == "--help" ]]; then
        usage
        exit 0
    fi
done

while getopts ":o:m:kfvqh" opt; do
    case $opt in
        o) OUTPUT="$OPTARG" ;;
        m)
            case "$OPTARG" in
                safe|normal|aggressive|extreme) MODE="$OPTARG" ;;
                *) error "Invalid mode: $OPTARG. Use: safe, normal, aggressive, extreme" ;;
            esac
            ;;
        k) KEEP_META=1 ;;
        f) FORCE=1 ;;
        v) VERBOSE=1 ;;
        q) QUIET=1 ;;
        h) usage; exit 0 ;;
        \?) error "Invalid option: -$OPTARG" ;;
        :) error "Option -$OPTARG requires an argument" ;;
    esac
done
shift $((OPTIND - 1))

trap 'echo -e "\n${C_R}[ABORTED]${C_N}" >&2; exit 130' INT TERM

main "$@"