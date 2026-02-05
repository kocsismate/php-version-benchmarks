#!/usr/bin/env bash
set -e

abs () {
    local x="$1"

    printf "%.50f" "$(echo "scale=50; x=$x; if (x < 0) x = - (x); x" | bc -l)"
}

diff () {
    local x="$1"
    local y="$2"

    printf "%.50f" "$(echo "scale=50; x=$x; y=$y; x - y" | bc -l)"
}

int_diff () {
    local x="$1"
    local y="$2"

    echo "x=$x; y=$y; x - y" | bc -l
}

abs_diff () {
    local x="$1"
    local y="$2"

    printf "%.50f" "$(echo "scale=50; x=$x; y=$y; if (x >= y) x - y else y - x" | bc -l)"
}

percent_diff () {
  awk -v t1="$1" -v t2="$2" 'BEGIN{print (t1/t2-1) * 100}'
}

min () {
  echo "$1" | awk 'BEGIN{a=999999}{if ($1<0+a) a=$1}END{print a}'
}

max () {
  echo "$1" | awk 'BEGIN{a=0}{if ($1>0+a) a=$1}END{print a}'
}

mean () {
   local nums=($1)
   local n="$2"
   local sum=0

   for val in "${nums[@]}"; do
       sum="$(echo "scale=50; $sum + $val" | bc -l)"
   done

   printf "%.50f" "$(echo "scale=50; $sum / ${#nums[@]}" | bc -l)"
}

median() {
    local nums=($1)
    local n="$2"

    local -a sorted=()
    IFS=$'\n' sorted=($(printf '%s\n' "${nums[@]}" | sort -n))
    unset IFS

    if (( n % 2 == 1 )); then
        local mid="$(( n / 2 ))"
        printf "%s" "${sorted[$mid]}"
    else
        local mid1="$(( n / 2 - 1))"
        local mid2="$(( n / 2 ))"
        printf "%.50f" "$(echo "scale=50; x=${sorted[mid1]}; y=${sorted[mid2]}; (x + y) / 2" | bc -l)"
    fi
}

median_abs_dev() {
    local nums=($1)
    local median="$2"
    local n="$3"

    local abs_devs=()
    for x in "${nums[@]}"; do
        abs_devs+=("$(abs_diff "$x" "$median")")
    done

    median "${abs_devs[*]}" "$n"
}

 # Sample variance: divides by n-1 instead of n
variance () {
    local nums=($1)
    local mean="$2"
    local n="$3"

    local sum_sq_diff=0
    for val in "${nums[@]}"; do
      diff="$(echo "scale=50; $val - $mean" | bc -l)"
      sq_diff="$(echo "scale=50; $diff * $diff" | bc -l)"
      sum_sq_diff="$(echo "scale=50; $sum_sq_diff + $sq_diff" | bc -l)"
    done

    printf "%.50f" "$(echo "scale=50; $sum_sq_diff / ($n - 1)" | bc -l)"
}

std_dev () {
    local var="$1"

    printf "%.50f" "$(echo "scale=50; sqrt($var)" | bc -l)"
}

relative_std_dev () {
    local mean="$1"
    local std_dev="$2"

    printf "%.50f" "$(echo "scale=50; $std_dev / $mean * 100" | bc -l)"
}

# Adjusted Fisher–Pearson standardized moment coefficient
skewness () {
    local nums=($1)
    local mean="$2"
    local std_dev="$3"
    local n="$4"

    local x
    local sum=0
    for x in "${nums[@]}"; do
        # Standardize each data point by subtracting the mean and dividing by the sample standard deviation
        local z="$(printf "%.50f" "$(echo "scale=50; ($x - $mean) / $std_dev" | bc -l)")"
        # Cube each standardized value by raising it to the power of 3:
        local cube_z="$(printf "%.50f" "$(echo "scale=50; $z^3" | bc -l)")"
        # Sum all the cubed standardized values
        local sum="$(printf "%.50f" "$(echo "scale=50; $sum + $cube_z" | bc -l)")"
    done

    # Correction factor: n / ((n-1) * (n-2))
    local correction="$(printf "%.50f" "$(echo "scale=50; $n / (($n-1) * ($n-2))" | bc -l)")"

    # Multiply the result by the correction factor to obtain the sample skewness
    printf "%.50f" "$(echo "scale=50; $correction * $sum" | bc -l)"
}

# MAD method
outliers() {
    local nums=($1)
    local median="$2"
    local mad="$3"

    # Degenerate case
    if [[ "$mad" == "0" ]]; then
        return 0
    fi

    local outliers=()
    for k in "${!nums[@]}"; do
        local iteration="$(( k + 1 ))"
        local abs_diff="$(abs_diff "${nums[${k}]}" "$median")"
        local score="$(echo "scale=50; $abs_diff / $mad" | bc)"

        if [[ "$(echo "$score > 3.5" | bc)" -eq 1 ]]; then
            outliers["$iteration"]=${nums[${k}]}
        fi
    done

    local first=true
    for k in "${!outliers[@]}"; do
        if [[ "$first" == true ]]; then
            first=false
        else
            printf ", "
        fi

        printf "%d => %.6f" "$k" "${outliers[$k]}"
    done
}

# Check normality vs log-normality
decide_distribution () {
    local nums=($1)
    local n="$2"
    local skewness_raw="$3"

    # log-transformed skewness (only if all positive)
    local lognums=()
    for x in "${nums[@]}"; do
        local logx="$(printf "%.50f" "$(echo "scale=50; l($x)" | bc -l)")"
        lognums+=("$logx")
    done

    local lognum_n="${#lognums[@]}"
    local lognum_mean="$(mean "${lognums[*]}" "$lognum_n")"
    local lognum_variance="$(variance "${lognums[*]}" "$lognum_mean" "$lognum_n")"
    local lognum_std_dev="$(std_dev "$lognum_variance")"
    local skewness_log="$(skewness "${lognums[*]}" "$lognum_mean" "$lognum_std_dev" "$lognum_n")"

    # decision
    abs_raw="$(abs "$skewness_raw")"
    abs_log="$(abs "$skewness_log")"

    cmp="$(echo "$abs_log < $abs_raw" | bc -l)"
    if [ "$cmp" -eq 1 ]; then
        echo "log-normal"
    else
        echo "normal"
    fi
}

welch_t_stat () {
    local mean1="$1"
    local var1="$2"
    local n1="$3"
    local mean2="$4"
    local var2="$5"
    local n2="$6"

    local t_num="$(echo "scale=50; $mean1 - $mean2" | bc -l)"
    local t_denom="$(echo "scale=50; sqrt($var1 / $n1 + $var2 / $n2)" | bc -l)"

    printf "%.50f" "$(echo "scale=50; $t_num / $t_denom" | bc -l)"
}

# Degrees of freedom (Welch–Satterthwaite)
degrees_of_freedom () {
    local var1="$1"
    local n1="$2"

    local var2="$3"
    local n2="$4"

    df_num="$(echo "scale=50; ($var1 / $n1 + $var2 / $n2)^2" | bc -l)"
    df_denom="$(echo "scale=50; (($var1 / $n1)^2) / ($n1 - 1) + (($var2 / $n2)^2) / ($n2 - 1)" | bc -l)"

    printf "%.50f" "$(echo "scale=50; $df_num / $df_denom" | bc -l)"
}

welch_p_value() {
    local df="$1"
    local t="$2"

    if [ "$(echo "$t == 0" | bc -l)" -eq 1 ]; then
        echo "1"
        return
    fi

    # header probabilities
    header=(1.00 0.50 0.40 0.30 0.20 0.10 0.05 0.02 0.01 0.002 0.001)

    # table: first column = df threshold, then the critical t-values for the header columns
    # columns separated by whitespace (tabs/spaces).
    read -r -d '' TBL <<'TSV' || true
1000000000000    0.000 0.674 0.842 1.036 1.282 1.645 1.960 2.326 2.576 3.090 3.291
1000             0.000 0.675 0.842 1.037 1.282 1.646 1.962 2.330 2.581 3.098 3.300
100              0.000 0.677 0.845 1.042 1.290 1.660 1.984 2.364 2.626 3.174 3.390
80               0.000 0.678 0.846 1.043 1.292 1.664 1.990 2.374 2.639 3.195 3.416
60               0.000 0.679 0.848 1.045 1.296 1.671 2.000 2.390 2.660 3.232 3.460
40               0.000 0.681 0.851 1.050 1.303 1.684 2.021 2.423 2.704 3.307 3.551
30               0.000 0.683 0.854 1.055 1.310 1.697 2.042 2.457 2.750 3.385 3.646
29               0.000 0.683 0.854 1.055 1.311 1.699 2.045 2.462 2.756 3.396 3.659
28               0.000 0.683 0.855 1.056 1.313 1.701 2.048 2.467 2.763 3.408 3.674
27               0.000 0.684 0.855 1.057 1.314 1.703 2.052 2.473 2.771 3.421 3.690
26               0.000 0.684 0.856 1.058 1.315 1.706 2.056 2.479 2.779 3.435 3.707
25               0.000 0.684 0.856 1.058 1.316 1.708 2.060 2.485 2.787 3.450 3.725
24               0.000 0.685 0.857 1.059 1.318 1.711 2.064 2.492 2.797 3.467 3.745
23               0.000 0.685 0.858 1.060 1.319 1.714 2.069 2.500 2.807 3.485 3.768
22               0.000 0.686 0.858 1.061 1.321 1.717 2.074 2.508 2.819 3.505 3.792
21               0.000 0.686 0.859 1.063 1.323 1.721 2.080 2.518 2.831 3.527 3.819
20               0.000 0.687 0.860 1.064 1.325 1.725 2.086 2.528 2.845 3.552 3.850
19               0.000 0.688 0.861 1.066 1.328 1.729 2.093 2.539 2.861 3.579 3.883
18               0.000 0.688 0.862 1.067 1.330 1.734 2.101 2.552 2.878 3.610 3.922
17               0.000 0.689 0.863 1.069 1.333 1.740 2.110 2.567 2.898 3.646 3.965
16               0.000 0.690 0.865 1.071 1.337 1.746 2.120 2.583 2.921 3.686 4.015
15               0.000 0.691 0.866 1.074 1.341 1.753 2.131 2.602 2.947 3.733 4.073
14               0.000 0.692 0.868 1.076 1.345 1.761 2.145 2.624 2.977 3.787 4.140
13               0.000 0.694 0.870 1.079 1.350 1.771 2.160 2.650 3.012 3.852 4.221
12               0.000 0.695 0.873 1.083 1.356 1.782 2.179 2.681 3.055 3.930 4.318
11               0.000 0.697 0.876 1.088 1.363 1.796 2.201 2.718 3.106 4.025 4.437
10               0.000 0.700 0.879 1.093 1.372 1.812 2.228 2.764 3.169 4.144 4.587
9                0.000 0.703 0.883 1.100 1.383 1.833 2.262 2.821 3.250 4.297 4.781
8                0.000 0.706 0.889 1.108 1.397 1.860 2.306 2.896 3.355 4.501 5.041
7                0.000 0.711 0.896 1.119 1.415 1.895 2.365 2.998 3.499 4.785 5.408
6                0.000 0.718 0.906 1.134 1.440 1.943 2.447 3.143 3.707 5.208 5.959
5                0.000 0.727 0.920 1.156 1.476 2.015 2.571 3.365 4.032 5.893 6.869
4                0.000 0.741 0.941 1.190 1.533 2.132 2.776 3.747 4.604 7.173 8.610
3                0.000 0.765 0.978 1.250 1.638 2.353 3.182 4.541 5.841 10.215 12.924
2                0.000 0.816 1.061 1.386 1.886 2.920 4.303 6.965 9.925 22.327 31.599
1                0.000 1.000 1.376 1.963 3.078 6.314 12.71 31.82 63.66 318.31 636.62
TSV

    t="$(abs "$t")"

    # pick row: first line in TBL such that df >= key
    local row
    row=$(awk -v df="$df" 'BEGIN{FS="[ \t]+"}
        {
          key = $1 + 0
          if (df >= key) {
            # print the rest of the line (skip the key)
            $1 = ""; sub(/^[ \t]+/, "");
            print; exit
          }
        }' <<< "$TBL")

    if [ -z "$row" ]; then
        echo "error: no table row selected for df=$df" >&2
        return 2
    fi

    # read row values into array 'vals'
    read -r -a vals <<< "$row"
    local n="${#vals[@]}"

    # loop through columns, find interval where t fits
    for ((i=0; i < n-1; i++)); do
        local curr=${vals[i]}
        local next=${vals[i+1]}

        # comparisons with bc (returns 1 or 0)
        local ge="$(echo "scale=50; $t >= $curr" | bc -l)"
        local lt="$(echo "scale=50; $t < $next" | bc -l)"

        if [ "$ge" -eq 1 ] && [ "$lt" -eq 1 ]; then
            # header[i] and header[i+1] used for interpolation
            local h_i="${header[i]}"
            local h_ip1="${header[i+1]}"

            # p = header[i+1] + ((header[i] - header[i+1]) / (next - curr) * (t - curr))
            printf "%.12f" "$(echo "scale=50; $h_ip1 + ( ($h_i - $h_ip1) / ($next - $curr) ) * ($t - $curr)" | bc -l)"
            return 0
        fi
    done

    # t beyond last interval -> return 0.001 (smallest p in table)
    printf "%.12f" 0.001
}

# Normal CDF approximation
phi () {
    local z="$1"

    local phi="$(bc -l <<BCL
scale=50
z = $z
p = 0.2316419
b1 = 0.319381530
b2 = -0.356563782
b3 = 1.781477937
b4 = -1.821255978
b5 = 1.330274429

t = 1 / (1 + p*z)
poly = b1*t + b2*(t^2) + b3*(t^3) + b4*(t^4) + b5*(t^5)
nd = e( - (z*z) / 2 ) / sqrt(2 * 4 * a(1))
1 - nd * poly
BCL
    )"

    printf "%.50f" "$phi"
}

effect_size_standardized () {
    local n="$1"
    local z="$2"

    printf "%.50f" "$(echo "scale=50; n=$n; z=$z; sqrt((z * z) / (n + n))" | bc -l)"
}

effect_size_common () {
    local n="$1"
    local u="$2"

    printf "%.50f" "$(echo "scale=50; n=$n; u=$u; u/(n*n)" | bc -l)"
}

# Wilcoxon rank-sum using normal approximation and continuity correction
wilcoxon_u_test () {
    local file1="$1"
    local file2="$2"
    local n="$3"

    # Combine samples
    local combined="$(mktemp)"
    nl -w1 -s' ' -nln "$file1" | sed 's/$/ A/' > "$combined"
    nl -w1 -s' ' -nln "$file2" | sed 's/$/ B/' >> "$combined"

    local sorted="$(mktemp)"
    sort -k2,2n -k1,1n "$combined" > "$sorted"

    # Assign ranks (average for ties)
    ranks="$(mktemp)"
    awk '
    {
      val=$2; grp=$3; i=NR
      vals[i]=val; grps[i]=grp
    }
    END {
      i=1
      while (i<=NR) {
        j=i
        while (j<NR && vals[j]==vals[j+1]) j++
        avg=(i+j)/2
        for (k=i;k<=j;k++) {
          print vals[k], grps[k], avg
        }
        i=j+1
      }
    }' "$sorted" > "$ranks"

    # Compute rank sums
    local ranks1="$(awk '$2=="A"{s+=$3} END{print s}' "$ranks")"
    local ranks2="$(awk '$2=="B"{s+=$3} END{print s}' "$ranks")"
    rm -f "$combined" "$sorted" "$ranks"

    # Compute U
    local u1="$(printf "%.50f" "$(echo "scale=50; $ranks1 - ($n*($n+1)/2)" | bc -l)")"
    local u2="$(printf "%.50f" "$(echo "scale=50; $ranks2 - ($n*($n+1)/2)" | bc -l)")"

    printf "%.50f %.50f" "$u1" "$u2"
}

# Wilcoxon rank-sum using normal approximation and continuity correction
wilcoxon_z_test () {
    local n="$1"
    local u="$2"
    local file1="$3"
    local file2="$4"

    if [[ "$file1" == "$file2" ]]; then
        printf "%.50f" "0"
        return
    fi

    # Mean and sigma
    local mu="$(echo "scale=50; $n*$n/2" | bc -l)"
    local sigma="$(echo "scale=50; sqrt($n*$n*($n+$n+1)/12)" | bc -l)"

    # Continuity correction
    local cmp="$(echo "$u > $mu" | bc -l)"
    local cc
    if [ "$cmp" -eq 1 ]; then
      cc="$(echo "scale=50; -0.5" | bc -l)"
    else
      cc="$(echo "scale=50; 0.5" | bc -l)"
    fi

    printf "%.50f" "$(echo "scale=50; ($u - $mu + $cc)/$sigma" | bc -l)"
}

# Two-sided p-value
wilcoxon_p_value () {
    local z="$1"

    local abs_z="$(abs "$z")"
    local phi="$(phi "$abs_z")"

    printf "%.50f" "$(echo "scale=50; 2*(1-$phi)" | bc -l)"
}
