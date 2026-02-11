#!/bin/bash
set -e

mkdir -p COMBINED-DATA

# ── Build library → culture mapping ──────────────────────────────
declare -A SAMPLE_MAP
while IFS=$'\t' read -r lib sample rest; do
    [[ "$lib" == "Metagenomes" ]] && continue
    SAMPLE_MAP["$lib"]="$sample"
done < RAW-DATA/sample-translation.txt

# ── Process each library directory ───────────────────────────────
for lib_dir in RAW-DATA/DNA*/; do
    lib=$(basename "$lib_dir")
    culture="${SAMPLE_MAP[$lib]}"
    [[ -z "$culture" ]] && { echo "No mapping for $lib – skipping"; continue; }

    echo "Processing $lib → $culture"

    # ── Copy metadata files ──────────────────────────────────────
    cp "${lib_dir}checkm.txt"      "COMBINED-DATA/${culture}-CHECKM.txt"
    cp "${lib_dir}gtdb.gtdbtk.tax" "COMBINED-DATA/${culture}-GTDB-TAX.txt"

    # ── Parse checkm.txt ─────────────────────────────────────────
    unset COMP CONT 2>/dev/null || true
    declare -A COMP CONT
    while read -r line; do
        [[ "$line" =~ ^[[:space:]]*-  ]] && continue
        [[ "$line" =~ "Bin Id"        ]] && continue
        [[ -z "${line// /}"           ]] && continue
        bid=$(awk '{print $1}'       <<< "$line")
        COMP["$bid"]=$(awk '{print $(NF-2)}' <<< "$line")
        CONT["$bid"]=$(awk '{print $(NF-1)}' <<< "$line")
    done < "${lib_dir}checkm.txt"

    # ── Process each FASTA file ──────────────────────────────────
    mag_n=0
    bin_n=0

    for fa in "${lib_dir}bins/"*.fasta; do
        [[ -f "$fa" ]] || continue
        bname=$(basename "$fa" .fasta)

        # Handle unbinned separately
        if [[ "$bname" == "bin-unbinned" ]]; then
            awk -v p="${culture}_UNBINNED" \
                '/^>/{n++; printf ">%s_%012d\n",p,n; next}{print}' \
                "$fa" > "COMBINED-DATA/${culture}_UNBINNED.fa"
            continue
        fi

        # Look up completeness & contamination
        c=""
        r=""
        for bid in "${!COMP[@]}"; do
            if [[ "$bid" == *"$bname" ]]; then
                c="${COMP[$bid]}"
                r="${CONT[$bid]}"
                break
            fi
        done

        # MAG: completeness >= 50 AND contamination < 5
        if [[ -n "$c" && -n "$r" ]] && \
           (( $(echo "$c >= 50" | bc -l) )) && \
           (( $(echo "$r <  5" | bc -l) )); then
            mag_n=$((mag_n + 1))
            tag="${culture}_MAG_$(printf '%03d' $mag_n)"
        else
            bin_n=$((bin_n + 1))
            tag="${culture}_BIN_$(printf '%03d' $bin_n)"
        fi

        awk -v p="$tag" \
            '/^>/{n++; printf ">%s_%012d\n",p,n; next}{print}' \
            "$fa" > "COMBINED-DATA/${tag}.fa"
    done
done

echo "Done – results in COMBINED-DATA/"
