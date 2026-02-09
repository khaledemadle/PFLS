echo "FASTA File Statistics:"
echo "----------------------"

    no_seq=$(grep '>' $1 | wc -l)
echo "Number of sequences:" $no_seq

    total_length=$(awk '!/>/ {printf $0}' $1 | wc -c)
echo "Total length of sequences:" $total_length

    longest_seq=$(awk '/>/ {if (seq) print seq; print; seq=""; next} {seq=seq $0} END {print seq}' $1 |awk '!/>/{print}' | awk '{ print length, $0 }' | sort -nr | awk '{$1=""; print $0}' | head -n 1| wc -c)
echo "Length of the longest sequence:" $longest_seq

    shortest_seq=$(awk '/>/ {if (seq) print seq; print; seq=""; next} {seq=seq $0} END {print seq}' $1 |awk '!/>/{print}' | awk '{ print length, $0 }' | sort -n | awk '{$1=""; print $0}' | head -n 1| wc -c)
echo "Length of the shortest sequence:" $shortest_seq

    av_seq=$(($total_length / $no_seq))
echo "Average sequence length:" $av_seq

    amount_GC=$(awk ' !/>/ {gc_count += gsub(/[GgCc]/, "", $1)} END {print gc_count}' $1)
    percentage_GC=$(echo "scale=2; $amount_GC / $total_length *100" |bc)
echo "GC Content (%):" $percentage_GC
