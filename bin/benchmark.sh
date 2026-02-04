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

print_environment () {
    printf "URI\tID\tName\tEnvironment\tRunner\tInstance type\tArchitecture\tCPU\tCPU cores\tCPU frequency\tRAM\tKernel\tOS\tGCC\tDedicated instance\tDeeper C-states\tTurbo boost\tHyper-threading\tTime\n" > "$1.tsv"

cat << EOF > "$1.md"
### $INFRA_NAME

|  Attribute    |     Value      |
|---------------|----------------|
EOF

    instance_type="$INFRA_INSTANCE_TYPE"
    if [[ "$INFRA_DEDICATED_INSTANCE" == "1" ]]; then
        instance_type="${instance_type} (dedicated)"
    fi
    instance_type="| Instance type |$instance_type|\n"

    local architecture="$(uname -m)"
    local kernel="$(uname -r)"

    cpu="$(lscpu | grep '^Model name:' || true)"
    cpu="${cpu/Model name:/}"
    cpu="$(echo "$cpu" | awk '{$1=$1;print}')"

    ram_kb=$(grep "MemTotal" /proc/meminfo | awk '{print $2}')
    ram_gb=$(expr "$ram_kb" / 1024 / 1024)

    os="$(grep '^PRETTY_NAME=' /etc/os-release)"
    os="${os/PRETTY_NAME=/}"
    os="${os//\"/}"
    os="$(echo "$os" | awk '{$1=$1;print}')"
    gcc_version="$(gcc -v 2>&1 | grep "gcc version" | awk '{print $3}')"

    cpu_settings=""
    if [[ "$INFRA_DISABLE_DEEPER_C_STATES" == "1" ]]; then
        cpu_settings="${cpu_settings}, disabled deeper C-states"
        deeper_c_states="0"
    else
        deeper_c_states="1"
    fi

    if [[ "$INFRA_DISABLE_TURBO_BOOST" == "1" ]]; then
        cpu_settings="${cpu_settings}, disabled turbo boost"
        turbo_boost="0"
    else
        turbo_boost="1"
    fi

    if [[ "$INFRA_DISABLE_HYPER_THREADING" == "1" ]]; then
        cpu_settings="${cpu_settings}, disabled hyper-threading"
        hyper_threading="0"
    else
        hyper_threading="1"
    fi

    if [[ "$INFRA_LOCK_CPU_FREQUENCY" == "1" ]]; then
        cpu_frequency_khz="$(cat /sys/devices/system/cpu/cpu0/cpufreq/base_frequency)"
        cpu_frequency_mhz="$(( cpu_frequency_khz / 1000 ))"
    else
        cpu_frequency_mhz=""
    fi

    if [ ! -z "$cpu_settings" ]; then
        cpu_settings="${cpu_settings:2}"
    fi

    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%d\t%d\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%s\n" \
        "${RESULT_ROOT_DIR}_${RUN}_${INFRA_ID}" "$INFRA_ID" "$INFRA_NAME" "$INFRA_ENVIRONMENT" "$INFRA_RUNNER" "$INFRA_INSTANCE_TYPE" "$architecture" \
        "$cpu" "$CPU_COUNT" "$cpu_frequency_mhz" "$ram_gb" "$kernel" "$os" "$gcc_version" "$INFRA_DEDICATED_INSTANCE" "$deeper_c_states" "$turbo_boost" "$hyper_threading" \
        "$NOW" >> "$1.tsv"

    if [[ -n "$cpu" ]]; then
        cpu="${cpu}, "
    fi
    cpu="${cpu}${CPU_COUNT} core"
    if [ "$CPU_COUNT" -gt "1" ]; then
        cpu="${cpu}s"
    fi

    if [[ -n "$cpu_frequency_mhz" ]]; then
        cpu="${cpu} @ $cpu_frequency_mhz MHz"
    fi

    if [[ -n "$cpu_settings" ]]; then
        cpu_settings="| CPU settings  |$cpu_settings|\n"
    fi

    if [[ -n "$BENCHMARK_LOG_URL" || -n "$BENCHMARK_ARTIFACT_URL" ]]; then
        job_details_value="$BENCHMARK_LOG_URL"
        if [[ -n "$BENCHMARK_ARTIFACT_URL" ]]; then
            job_details_value="$job_details_value ([Artifacts]($BENCHMARK_ARTIFACT_URL))"
        fi
        job_details="| Job details  |$job_details_value|\n"
    fi

    if [[ -n "$BENCHMARK_EXTRA_TITLE" && -n "$BENCHMARK_EXTRA_TEXT" ]]; then
        extra="| $BENCHMARK_EXTRA_TITLE  |$BENCHMARK_EXTRA_TEXT|\n"
    fi

    printf "| Environment   |%s|\n${instance_type}| Architecture  |%s\n| CPU           |%s|\n${cpu_settings}| RAM           |%d GB|\n| Kernel        |%s|\n| OS            |%s|\n| GCC           |%s|\n| Time          |%s|\n${job_details}${extra}" \
        "$INFRA_ENVIRONMENT" "$architecture" \
        "$cpu" "$ram_gb" "$kernel" "$os" "$gcc_version" "$NOW UTC" >> "$1.md"
}

print_result_tsv_header () {
    printf "Test name\tTest warmup\tTest iterations\tTest requests\tPHP\tPHP Commit hash\tPHP Commit URL\tMin\tMax\tStd dev\tRel std dev %%\tMean\tMean diff %%\tMedian\tMedian diff %%\tSkewness\tZ-stat\tP-value\tMemory usage\n" >> "$1.tsv"
}

print_result_md_header () {
    local result_file="$1"

    local run_suffix=""
    if [ "$TEST_ITERATIONS" -gt "1" ]; then
        run_suffix="s"
    fi

    local warmup_suffix=""
    if [ "$TEST_WARMUP" -gt "1" ]; then
        warmup_suffix="s"
    fi

    local request_suffix=""
    if [ "$TEST_REQUESTS" -gt "1" ]; then
        request_suffix="s"
    fi

    local description="$(printf "%d iteration%s, %d warmup%s, %d request%s" "$TEST_ITERATIONS" "$run_suffix" "$TEST_WARMUP" "$warmup_suffix" "$TEST_REQUESTS" "$request_suffix")"

cat << EOF >> "$result_file.md"
### $TEST_NAME - $description (sec)

|     PHP     |     Min     |     Max     |    Std dev   | Rel std dev % |  Mean  | Mean diff % |   Median   | Median diff % | Skewness |  Z-stat  | P-value |     Memory    |
|-------------|-------------|-------------|--------------|---------------|--------|-------------|------------|---------------|----------|----------|---------|---------------|
EOF
}

print_result_value () {
    local log_file="$1"
    local memory_log_file="$2"
    local perf_log_file="$3"
    local result_file="$4"
    local final_result_file="$5"
    local stat_file="$6"

    local var="PHP_COMMITS_$PHP_ID"
    local commit_hash="${!var}"
    commit_hash="$(echo "$commit_hash" | cut -c 1-10)"
    local url="${PHP_REPO//.git/}/commit/$commit_hash"

    local results="$(cat "$log_file")"
    if [ -z "$first_results" ]; then
        first_results="$results"
    fi
    if [ -z "$first_log_file" ]; then
        first_log_file="$log_file"
    fi

    local memory_result="$(cat "$memory_log_file")"

    local n_arr=($results)
    local n="$(echo "${#n_arr[@]}")"
    if [ -z "$first_n" ]; then
        first_n="$n"
    fi
    local min="$(min "$results")"
    local max="$(max "$results")"
    local mean="$(mean "$results")"
    if [ -z "$first_mean" ]; then
        first_mean="$mean"
    fi
    local mean_diff="$(percent_diff "$mean" "$first_mean")"
    local median="$(median "$results" "$n")"
    if [ -z "$first_median" ]; then
        first_median="$median"
    fi
    local median_diff="$(percent_diff "$median" "$first_median")"
    local variance="$(variance "$results" "$mean" "$n")"
    if [ -z "$first_var" ]; then
        first_var="$variance"
    fi
    local std_dev="$(std_dev "$variance")"
    local relative_std_dev="$(relative_std_dev "$mean" "$std_dev")"
    local skewness="$(skewness "$results" "$mean" "$std_dev" "$n")"
    local mad="$(median_abs_dev "$results" "$median" "$n")"
    local outliers="$(outliers "$results" "$median" "$mad")"
    local apparent_distribution="$(decide_distribution "$results" "$n" "$skewness")"
    local df="$(degrees_of_freedom "$first_var" "$first_n" "$variance" "$n")"
    local welch_t_stat="$(welch_t_stat "$first_mean" "$first_var" "$first_n" "$mean" "$variance" "$n")"
    local welch_p_value="$(welch_p_value "$df" "$welch_t_stat")"
    read wilcoxon_u1_value wilcoxon_u2_value <<< "$(wilcoxon_u_test "$first_log_file" "$log_file" "$n")"
    local wilcoxon_z_stat="$(wilcoxon_z_test "$n" "$wilcoxon_u1_value" "$first_log_file" "$log_file")"
    local wilcoxon_p_value="$(wilcoxon_p_value "$wilcoxon_z_stat")"
    local effect_size_standardized="$(effect_size_standardized "$n" "$wilcoxon_z_stat")"
    local effect_size_common="$(effect_size_common "$n" "$wilcoxon_u1_value")"

    echo "-----------------------------------------------------------------"
    echo "$PHP_ID"
    echo "-----------------------------------------------------------------"
    echo "Descriptive statistics"
    echo "- N                 : $n" | tee -a "$stat_file"
    echo "- Min               : $min" | tee -a "$stat_file"
    echo "- Max               : $max" | tee -a "$stat_file"
    printf -- "- Mean              : %.6f (%.6f %%)\n" "$mean" "$mean_diff" | tee -a "$stat_file"
    printf -- "- Median            : %.6f (%.6f %%)\n" "$median" "$median_diff" | tee -a "$stat_file"
    printf -- "- Variance          : %.9f\n" "$variance" | tee -a "$stat_file"
    printf -- "- Std dev           : %.6f (%.6f %%)\n" "$std_dev" "$relative_std_dev" | tee -a "$stat_file"
    printf -- "- Skewness          : %.6f\n" "$skewness" | tee -a "$stat_file"
    printf -- "- MAD (median)      : %.6f\n" "$mad" | tee -a "$stat_file"
    printf -- "- Outliers          : %s\n" "$outliers" | tee -a "$stat_file"
    printf -- "- Distribution      : ~ %s\n" "$apparent_distribution" | tee -a "$stat_file"
    # Based on https://www.statskingdom.com/150MeanT2uneq.html
    echo "Welch's T test" | tee -a "$stat_file"
    printf -- "- Degrees of freedom: %.6f\n" "$df" | tee -a "$stat_file"
    printf -- "- Test statistic T  : %.6f\n" "$welch_t_stat" | tee -a "$stat_file"
    printf -- "- Two tailed P-value: %.6f\n" "$welch_p_value" | tee -a "$stat_file"
    # Based on https://www.statskingdom.com/170median_mann_whitney.html
    echo "Wilcoxon U test" | tee -a "$stat_file"
    printf -- "- U1                : %.6f\n" "$wilcoxon_u1_value" | tee -a "$stat_file"
    printf -- "- U2                : %.6f\n" "$wilcoxon_u2_value" | tee -a "$stat_file"
    printf -- "- Test statistic Z  : %.6f\n" "$wilcoxon_z_stat" | tee -a "$stat_file"
    printf -- "- Two tailed P-value: %.6f\n" "$wilcoxon_p_value" | tee -a "$stat_file"
    printf -- "- Std effect size   : %.6f\n" "$effect_size_standardized" | tee -a "$stat_file"
    printf -- "- Common effect size: %.6f\n" "$effect_size_common" | tee -a "$stat_file"

    local memory_usage="$(echo "scale=3;${memory_result}/1024"|bc -l)"

    printf "%s\t%d\t%d\t%d\t%s\t%s\t%s\t%.5f\t%.5f\t%.5f\t%.5f\t%.5f\t%.2f\t%.5f\t%.2f\t%.3f\t%.3f\t%.3f\t%.2f\n" \
        "$TEST_NAME" "$TEST_WARMUP" "$TEST_ITERATIONS" "$TEST_REQUESTS" \
        "$PHP_NAME" "$commit_hash" "$url" \
        "$min" "$max" "$std_dev" "$relative_std_dev" "$mean" "$mean_diff" "$median" "$median_diff" "$skewness" "$wilcoxon_z_stat" "$wilcoxon_p_value" "$memory_usage" | tee -a "$result_file.tsv" "$final_result_file.tsv" > /dev/null

    printf "|[%s]($url)|%.5f|%.5f|%.5f|%.2f%%|%.5f|%.2f%%|%.5f|%.2f%%|%.3f|%.3f|%.3f|%.2f MB|\n" \
        "$PHP_NAME" "$min" "$max" "$std_dev" "$relative_std_dev" "$mean" "$mean_diff" "$median" "$median_diff" "$skewness" "$wilcoxon_z_stat" "$wilcoxon_p_value" "$memory_usage" >> "$result_file.md"
}

run_cgi () {
    local mode="$1"
    local warmup="$2"
    local requests="$3"
    local script="$4"
    local uri="$5"
    local env="$6"

    if git --git-dir="$php_source_path/.git" --work-tree="$php_source_path" merge-base --is-ancestor "7b4c14dc10167b65ce51371507d7b37b74252077" HEAD > /dev/null 2>&1; then
        opcache=""
    else
        opcache="-d zend_extension=$php_source_path/modules/opcache.so"
    fi

    declare -A php_env_vars=( \
        [CONTENT_TYPE]="'text/html; charset=utf-8'" \
        [REQUEST_URI]="$uri" \
        [HTTP_HOST]="localhost" \
        [SERVER_NAME]="localhost" \
        [SCRIPT_FILENAME]="$PROJECT_ROOT/$4" \
        [REQUEST_METHOD]="GET" \
        [REDIRECT_STATUS]="200" \
        [APP_ENV]="$env" \
        [APP_DEBUG]=false \
        [APP_SECRET]=random \
        [SESSION_DRIVER]=cookie \
        [SESSION_DOMAIN]="" \
        [CACHE_STORE]=null \
        [LOG_LEVEL]=INFO \
        [LOG_CHANNEL]=stderr \
        [DB_CONNECTION]=sqlite \
        [LOG_DEPRECATIONS_CHANNEL]=stderr \
        [LOG_DEPRECATIONS_TRACE]=true \
        [BROADCAST_DRIVER]=null \
        [USE_ZEND_ALLOC_HUGE_PAGES]=1 \
        [MALLOC_ARENA_MAX]=1 \
        [MALLOC_MMAP_THRESHOLD_]=131072 \
    )

    local php_env_var_list=()
    for key in "${!php_env_vars[@]}"; do
      php_env_var_list+=("$key=${php_env_vars[$key]}")
    done

    # TODO for jemalloc
    # export LD_PRELOAD=/usr/lib64/libjemalloc.so.2
    # export MALLOC_CONF="narenas:1,dirty_decay_ms:2000,muzzy_decay_ms:2000,background_thread:false"

    if [ "$mode" = "quiet" ]; then
        if [[ "$INFRA_LOCK_CPU_FREQUENCY" == "0" || "$INFRA_DISABLE_DEEPER_C_STATES" == "0" ]]; then
            sleep 0.25
        fi
        sudo cgexec -g cpuset:php \
            nice -n -20 ionice -c 1 -n 0 \
            sudo -u "$USER" \
            env -i -S "${php_env_var_list[*]}" \
            $php_source_path/sapi/cgi/php-cgi $opcache -T "$warmup,$requests" "$PROJECT_ROOT/$4" > /dev/null
    elif [ "$mode" = "verbose" ]; then
       sudo cgexec -g cpuset:php \
            nice -n -20 ionice -c 1 -n 0 \
            sudo -u "$USER" \
            env -i -S "${php_env_var_list[*]}" \
            $php_source_path/sapi/cgi/php-cgi $opcache -T "$warmup,$requests" "$PROJECT_ROOT/$4"
    elif [ "$mode" = "memory" ]; then
        sudo cgexec -g cpuset:php \
            nice -n -20 ionice -c 1 -n 0 \
            sudo -u "$USER" \
            env -i -S "${php_env_var_list[*]}" \
            /usr/bin/time -v $php_source_path/sapi/cgi/php-cgi $opcache -q -T "$warmup,$requests" "$PROJECT_ROOT/$4" > /dev/null
    elif [ "$mode" = "perf" ]; then
        sudo cgexec -g cpuset:php \
            nice -n -20 ionice -c 1 -n 0 \
            sudo -u "$USER" \
            env -i -S "${php_env_var_list[*]}" \
            perf stat -e instructions,cycles,branches,branch-misses,page-faults --repeat=5 \
            $php_source_path/sapi/cgi/php-cgi $opcache -q -T "$warmup,$requests" "$PROJECT_ROOT/$4" > /dev/null

        if [[ "$INFRA_COLLECT_EXTENDED_PERF_STATS" == "1" ]]; then
            sudo cgexec -g cpuset:php \
                nice -n -20 ionice -c 1 -n 0 \
                sudo -u "$USER" \
                env -i -S "${php_env_var_list[*]}" \
                perf stat -e LLC-loads,LLC-load-misses --repeat=5 \
                $php_source_path/sapi/cgi/php-cgi $opcache -q -T "$warmup,$requests" "$PROJECT_ROOT/$4" > /dev/null

            sudo cgexec -g cpuset:php \
                nice -n -20 ionice -c 1 -n 0 \
                sudo -u "$USER" \
                env -i -S "${php_env_var_list[*]}" \
                perf stat -e LLC-stores,LLC-store-misses --repeat=5 \
                $php_source_path/sapi/cgi/php-cgi $opcache -q -T "$warmup,$requests" "$PROJECT_ROOT/$4" > /dev/null

            sudo cgexec -g cpuset:php \
                nice -n -20 ionice -c 1 -n 0 \
                sudo -u "$USER" \
                env -i -S "${php_env_var_list[*]}" \
                perf stat -e iTLB-load-misses,dTLB-load-misses --repeat=5 \
                $php_source_path/sapi/cgi/php-cgi $opcache -q -T "$warmup,$requests" "$PROJECT_ROOT/$4" > /dev/null
        fi
    else
        echo "Invalid php-cgi run mode"
        exit 1
    fi
}

run_cli () {
    local mode="$1"
    local warmup="$2"
    local requests="$3"
    local script="$4"

    if git --git-dir="$php_source_path/.git" --work-tree="$php_source_path" merge-base --is-ancestor "7b4c14dc10167b65ce51371507d7b37b74252077" HEAD > /dev/null 2>&1; then
        opcache=""
    else
        opcache="-d zend_extension=$php_source_path/modules/opcache.so"
    fi

    declare -A php_env_vars=( \
        [USE_ZEND_ALLOC_HUGE_PAGES]=1 \
        [MALLOC_ARENA_MAX]=1 \
        [MALLOC_MMAP_THRESHOLD_]=131072 \
    )

    local php_env_var_list=()
    for key in "${!php_env_vars[@]}"; do
      php_env_var_list+=("$key=${php_env_vars[$key]}")
    done

    # TODO for jemalloc
    # export LD_PRELOAD=/usr/lib64/libjemalloc.so.2
    # export MALLOC_CONF="narenas:1,dirty_decay_ms:2000,muzzy_decay_ms:2000,background_thread:false"

    if [ "$mode" = "quiet" ]; then
        if [[ "$INFRA_LOCK_CPU_FREQUENCY" == "0" || "$INFRA_DISABLE_DEEPER_C_STATES" == "0" ]]; then
            sleep 0.5
        fi

        sudo cgexec -g cpuset:php \
            nice -n -20 ionice -c 1 -n 0 \
            sudo -u "$USER" \
            env -i -S "${php_env_var_list[*]}" \
            $php_source_path/sapi/cgi/php-cgi $opcache -T "$warmup,$requests" "$PROJECT_ROOT/$script" > /dev/null
    elif [ "$mode" = "verbose" ]; then
        sudo cgexec -g cpuset:php \
            nice -n -20 ionice -c 1 -n 0 \
            sudo -u "$USER" \
            env -i -S "${php_env_var_list[*]}" \
            $php_source_path/sapi/cgi/php-cgi $opcache -T "$warmup,$requests" "$PROJECT_ROOT/$script"
    elif [ "$mode" = "memory" ]; then
        sudo cgexec -g cpuset:php \
            nice -n -20 ionice -c 1 -n 0 \
            sudo -u "$USER" \
            env -i -S "${php_env_var_list[*]}" \
            /usr/bin/time -v \
            $php_source_path/sapi/cgi/php-cgi $opcache -T "$warmup,$requests" "$PROJECT_ROOT/$script" > /dev/null
    elif [ "$mode" = "perf" ]; then
        sudo cgexec -g cpuset:php \
            nice -n -20 ionice -c 1 -n 0 \
            sudo -u "$USER" \
            env -i -S "${php_env_var_list[*]}" \
            perf stat -e instructions,cycles,branches,branch-misses,page-faults --repeat=5 \
            $php_source_path/sapi/cgi/php-cgi $opcache -T "$warmup,$requests" "$PROJECT_ROOT/$script" > /dev/null

        if [[ "$INFRA_COLLECT_EXTENDED_PERF_STATS" == "1" ]]; then
            sudo cgexec -g cpuset:php \
                nice -n -20 ionice -c 1 -n 0 \
                sudo -u "$USER" \
                env -i -S "${php_env_var_list[*]}" \
                perf stat -e LLC-loads,LLC-load-misses --repeat=5 \
                $php_source_path/sapi/cgi/php-cgi $opcache -T "$warmup,$requests" "$PROJECT_ROOT/$script" > /dev/null

            sudo cgexec -g cpuset:php \
                nice -n -20 ionice -c 1 -n 0 \
                sudo -u "$USER" \
                env -i -S "${php_env_var_list[*]}" \
                perf stat -e LLC-stores,LLC-store-misses --repeat=5 \
                $php_source_path/sapi/cgi/php-cgi $opcache -T "$warmup,$requests" "$PROJECT_ROOT/$script" > /dev/null

            sudo cgexec -g cpuset:php \
                nice -n -20 ionice -c 1 -n 0 \
                sudo -u "$USER" \
                env -i -S "${php_env_var_list[*]}" \
                perf stat -e iTLB-load-misses,dTLB-load-misses --repeat=5 \
                $php_source_path/sapi/cgi/php-cgi $opcache -T "$warmup,$requests" "$PROJECT_ROOT/$script" > /dev/null
        fi
    else
        echo "Invalid php-cli run mode"
        exit 1
    fi
}

assert_test_output() {
    local expectation_file="$1"
    local actual_file="$2"

    $php_source_path/sapi/cli/php "$PROJECT_ROOT/app/zend/assert_output.php" "$expectation_file" "$actual_file"
}

format_memory_log_file() {
    local result="$(grep "Maximum resident set size" "$1")"
    echo "$result" > "$1"
    sed -i "s/	Maximum resident set size (kbytes): //g" "$1"
}

format_perf_log_file() {
    local stats_pattern="instructions|cycles|branches|branch-misses|page-faults|LLC-loads|LLC-load-misses|LLC-stores|LLC-store-misses|iTLB-load-misses|dTLB-load-misses|stalled-cycles-frontend|stalled-cycles-backend"
    local result="$(grep -E "$stats_pattern" "$1")"

    echo "$result" > "$1"
}

load_php_config () {
    source $PHP_CONFIG_FILE
    export PHP_CONFIG_FILE
    php_source_path="$PROJECT_ROOT/tmp/$PHP_ID"

    log_dir="$result_dir"
    log_file="$log_dir/${PHP_ID}.log"
    output_file="$log_dir/${PHP_ID}_output.txt"
    memory_log_file="$log_dir/${PHP_ID}_memory.log"
    perf_log_file="$log_dir/${PHP_ID}_perf.log"
    stat_file="$log_dir/${PHP_ID}_stat.log"
    environment_debug_log_file="$log_dir/${PHP_ID}_env_debug.log"
    mkdir -p "$log_dir"
}

collect_environment_metrics() {
    local cpu="$1"

    local v_context_switches n_context_switches \
        minor_page_faults major_page_faults \
        irqs soft_irqs run_queue_length \
        io_reads io_writes io_time

    # Context switches
    v_context_switches="$(sed -n 's/^voluntary_ctxt_switches:[[:space:]]*//p' /proc/self/status)"
    n_context_switches="$(sed -n 's/^nonvoluntary_ctxt_switches:[[:space:]]*//p' /proc/self/status)"

    # Page faults (minflt = column 10, majflt = column 12)
    read -r _ _ _ _ _ _ _ _ _ _ minor_page_faults _ major_page_faults _ < /proc/self/stat

    # IRQ for the given CPU
    irqs=0
    while read -r line; do
        set -- "$line"
        # first column is the IRQ name, then CPU0 CPU1 CPU2...
        # CPU colum index: cpu+2 (mert $1 = IRQ név)
        col="$((cpu + 2))"
        val="$(eval "echo \${$col}")"
        irqs="$((irqs + val))"
    done < <(tail -n +2 /proc/interrupts)

    # soft_irq
    soft_irqs=0
    while read -r line; do
        set -- $line
        local col=$((cpu + 2))
        local val=$(eval "echo \${$col}")
        soft_irqs="$((soft_irqs + val))"
    done < <(tail -n +2 /proc/softirqs)

    # run_queue length
    run_queue_length="$(cut -d ' ' -f1 /proc/loadavg)"

#    sudo nvme amzn stats /dev/nvme2n1 | head
#    Total Ops:
#      Read: 238
#      Write: 0
#    Total Bytes:
#      Read: 4426752
#      Write: 0
#    Total Time (us):
#      Read: 7958
#      Write: 0

    # I/O stats
    local io_line="$(grep " nvme0n1 " /proc/diskstats)"
    read -r _ _ _ io_reads _ _ _ io_writes _ _ _ _ io_time _ _ <<< "$io_line"

    echo "$v_context_switches" "$n_context_switches" \
        "$minor_page_faults" "$major_page_faults" \
        "$irqs" "$soft_irqs" "$run_queue_length" \
        "$io_reads" "$io_writes" "$io_time"
}

print_environment_metrics_diff () {
    local iteration="$1"

    local v_context_switches_diff="$(int_diff "${v_context_switches[1]}" "${v_context_switches[0]}")"
    local n_context_switches_diff="$(int_diff "${n_context_switches[1]}" "${n_context_switches[0]}")"
    local minor_page_faults_diff="$(int_diff "${minor_page_faults[1]}" "${minor_page_faults[0]}")"
    local major_page_faults_diff="$(int_diff "${major_page_faults[1]}" "${major_page_faults[0]}")"
    local irqs_diff="$(int_diff "${irqs[1]}" "${irqs[0]}")"
    local soft_irqs_diff="$(int_diff "${soft_irqs[1]}" "${soft_irqs[0]}")"
    local run_queue_length_diff="$(diff "${run_queue_length[1]}" "${run_queue_length[0]}")"
    local io_reads_diff="$(int_diff "${io_reads[1]}" "${io_reads[0]}")"
    local io_writes_diff="$(int_diff "${io_writes[1]}" "${io_writes[0]}")"
    local io_time_diff="$(int_diff "${io_time[1]}" "${io_time[0]}")"

    echo "-----------------------------------------------------------------"
    printf "Iteration: %-4d\tResult: #RESULT$iteration#\tDiff: #DIFF$iteration#\n" "$iteration"
    echo "-----------------------------------------------------------------"
    printf "Voluntary context switches    : %d\n" "$v_context_switches_diff"
    printf "Non-voluntary context switches: %d\n" "$n_context_switches_diff"
    printf "Minor page faults             : %d\n" "$minor_page_faults_diff"
    printf "Major page faults             : %d\n" "$major_page_faults_diff"
    printf "IRQs                          : %d\n" "$irqs_diff"
    printf "Soft IRQs                     : %d\n" "$soft_irqs_diff"
    printf "Run queue length              : %.3f\n" "$run_queue_length_diff"
    printf "I/O reads                     : %d\n" "$io_reads_diff"
    printf "I/O writes                    : %d\n" "$io_writes_diff"
    printf "I/O time (ms)                 : %d\n" "$io_time_diff"
}

postprocess_environment_debug_Log_file () {
    local environment_debug_log_file="$1"
    local log_file="$2"

    local results="$(cat "$log_file")"
    local results_arr=($results)
    local n="${#results_arr[@]}"
    local median="$(median "$results" "$n")"

    for k in "${!results_arr[@]}"; do
        local iteration="$(( k + 1 ))"
        local diff="$(printf "%+.6f" "$(diff "${results_arr[${k}]}" "$median")")"

        sed -i "s/#RESULT$iteration#/${results_arr[${k}]}/g" "$environment_debug_log_file"
        sed -i "s/#DIFF$iteration#/$diff/g" "$environment_debug_log_file"
   done
}

draw_diagram () {
    result_dir="$1"
    test_name="$2"
    plot_args="$3"

    gnuplot -persist <<EOF
    set terminal svg size 1600,850 fname "Arial" background "white"
    set output "$result_dir/result.svg"

    set title "Benchmark results for $test_name"
    set key outside bottom
    set xlabel "Iteration"
    set ylabel "Execution time (s)"
    set grid

    set datafile separator "\t"
    plot $plot_args
EOF
}

reset_original_file () {
    file="$1"

    if [[ -f "${file}.original" ]]; then
        mv -f "${file}.original" "$file"
    fi
}

reset_symfony () {
    # Update config based on PHP version
    reset_original_file "$PROJECT_ROOT/app/symfony/config/packages/doctrine.yaml"
    reset_original_file "$PROJECT_ROOT/app/symfony/vendor/symfony/var-exporter/ProxyHelper.php"
    reset_original_file "$PROJECT_ROOT/app/symfony/vendor/symfony/dependency-injection/LazyProxy/PhpDumper/LazyServiceDumper.php"

    if git --git-dir="$php_source_path/.git" --work-tree="$php_source_path" merge-base --is-ancestor "315fef2c72d172f4f81420e8f64ab2f3cd9e55b1" HEAD > /dev/null 2>&1; then
        sed -i.original "s/        enable_lazy_ghost_objects: true/        enable_lazy_ghost_objects: true\n        enable_native_lazy_objects: true/g" "$PROJECT_ROOT/app/symfony/config/packages/doctrine.yaml"
    else
        sed -i.original "s/if (\\\\PHP_VERSION_ID < 80400) {/if (\\\\PHP_VERSION_ID <= 80400) {/g" "$PROJECT_ROOT/app/symfony/vendor/symfony/var-exporter/ProxyHelper.php"
        sed -i.original "s/if (\\\\PHP_VERSION_ID < 80400) {/if (\\\\PHP_VERSION_ID <= 80400) {/g" "$PROJECT_ROOT/app/symfony/vendor/symfony/dependency-injection/LazyProxy/PhpDumper/LazyServiceDumper.php"
    fi

    # Regenerate cache
    if [[ -d "$PROJECT_ROOT/tmp/app/symfony/cache-$PHP_ID" ]]; then
        cp -rf "$PROJECT_ROOT/tmp/app/symfony/cache-$PHP_ID" "$PROJECT_ROOT/app/symfony/var/cache"
    else
        rm -rf "$PROJECT_ROOT/tmp/app/symfony/cache/prod/Container*"
        rm -rf "$PROJECT_ROOT/tmp/app/symfony/cache/prod/App_KernelProdContainer*"
        APP_ENV=prod APP_DEBUG=false APP_SECRET=random $php_source_path/sapi/cli/php "$PROJECT_ROOT/app/symfony/bin/console" "cache:warmup"

        cp -r "$PROJECT_ROOT/app/symfony/var/cache" "$PROJECT_ROOT/tmp/app/symfony/cache-$PHP_ID"
    fi
}

reset_apps () {
    case "$TEST_ID" in
        symfony_main_*)
            reset_symfony
            ;;

        symfony_blog_*)
            reset_symfony
            ;;
    esac
}

postprocess_results () {
    local plot_args=""
    local -a plot_colors=("#1f77b4" "#ff7f0e" "#2ca02c" "#d62728" "#9467bd" "#8c564b" "#e377c2" "#7f7f00" "#17becf" "#00008b" "#b8860b" "#000000")
    local plot_size="${#plot_colors[@]}"

    local i=0
    for PHP_CONFIG_FILE in $PROJECT_ROOT/config/php/*.ini; do
        load_php_config

        # Format benchmark log
        sed -i "/^[[:space:]]*$/d" "$log_file"
        sed -i "s/Elapsed time\: //g" "$log_file"
        sed -i "s/ sec//g" "$log_file"

        if [ "$INFRA_DEBUG_ENVIRONMENT" == "1" ]; then
            postprocess_environment_debug_Log_file "$environment_debug_log_file" "$log_file"
        fi

        if [[ -n "$plot_args" ]]; then
            plot_args="${plot_args}, "
        fi

        plot_color_num="$(( i % plot_size ))"
        plot_args="${plot_args}  \"$log_file\" using 1 with points lc rgb \"${plot_colors[plot_color_num]}\" pointtype 7 pointsize 1.5 title \"$PHP_NAME results\""
        i="$(( i + 1 ))"
    done

    draw_diagram "$result_dir" "$TEST_NAME" "$plot_args"
}

run_real_benchmark () {
    for PHP_CONFIG_FILE in $PROJECT_ROOT/config/php/*.ini; do
        load_php_config

        reset_apps

        echo "---------------------------------------------------------------------------------------"
        echo "$TEST_NAME PERF STATS - $RUN/$N - $INFRA_NAME - $PHP_NAME (JIT: $PHP_JIT)"
        echo "---------------------------------------------------------------------------------------"

        # Verifying output
        run_cgi "verbose" "0" "1" "$1" "$2" "$3" 2>&1 | tee -a "$output_file"
        if [ -n "$test_expectation_file" ]; then
            assert_test_output "$test_expectation_file" "$output_file"
        fi

        # Measuring memory usage
        run_cgi "memory" "$TEST_WARMUP" "$TEST_REQUESTS" "$1" "$2" "$3" 2>&1 | tee -a "$memory_log_file"

        # Gathering perf metrics
        run_cgi "perf" "$TEST_WARMUP" "$TEST_REQUESTS" "$1" "$2" "$3" 2>&1 | tee -a "$perf_log_file"
    done

    if [ "$INFRA_DEBUG_ENVIRONMENT" == "1" ]; then
        declare -a v_context_switches=(0 0)
        declare -a n_context_switches=(0 0)
        declare -a minor_page_faults=(0 0)
        declare -a major_page_faults=(0 0)
        declare -a irqs=(0 0)
        declare -a soft_irqs=(0 0)
        declare -a run_queue_length=(0 0)
        declare -a io_reads=(0 0)
        declare -a io_writes=(0 0)
        declare -a io_time=(0 0)
    fi

    $PROJECT_ROOT/build/script/wait_for_cpu_temp.sh "$PHP_CPU" "$INFRA_MAX_ALLOWED_CPU_TEMP" "$CPU_TEMP_TIMEOUT" "$CPU_TEMP_FALLBACK_SLEEP"

    # Benchmark
    for i in $(seq $TEST_ITERATIONS); do
        for PHP_CONFIG_FILE in $PROJECT_ROOT/config/php/*.ini; do
            load_php_config

            reset_apps

            cpu_temp="$([ -f /sys/class/thermal/thermal_zone0/temp ] && echo "scale=2; $(cat /sys/class/thermal/thermal_zone0/temp) / 1000" | bc || echo "N/A") °C"
            echo "---------------------------------------------------------------------------------------"
            echo "$TEST_NAME BENCHMARK $i/$TEST_ITERATIONS - run $RUN/$N - $INFRA_NAME - $PHP_NAME (JIT: $PHP_JIT) - CPU: $cpu_temp"
            echo "---------------------------------------------------------------------------------------"

            # Debugging environment - initial state
            if [ "$INFRA_DEBUG_ENVIRONMENT" == "1" ]; then
                read -r "v_context_switches[0]" "n_context_switches[0]" \
                    "minor_page_faults[0]" "major_page_faults[0]" \
                    "irqs[0]" "soft_irqs[0]" "run_queue_length[0]" \
                    "io_reads[0]" "io_writes[0]" "io_time[0]" < <(collect_environment_metrics "$PHP_CPU")
            fi

            run_cgi "quiet" "$TEST_WARMUP" "$TEST_REQUESTS" "$1" "$2" "$3" 2>&1 | tee -a "$log_file"

            # Debugging environment - final state
            if [ "$INFRA_DEBUG_ENVIRONMENT" == "1" ]; then
                read -r "v_context_switches[1]" "n_context_switches[1]" \
                    "minor_page_faults[1]" "major_page_faults[1]" \
                    "irqs[1]" "soft_irqs[1]" "run_queue_length[1]" \
                    "io_reads[1]" "io_writes[1]" "io_time[1]" < <(collect_environment_metrics "$PHP_CPU")

                print_environment_metrics_diff "$i" | tee -a "$environment_debug_log_file"
            fi
        done
    done

    postprocess_results
}

run_micro_benchmark () {
    for PHP_CONFIG_FILE in $PROJECT_ROOT/config/php/*.ini; do
        load_php_config

        echo "---------------------------------------------------------------------------------------"
        echo "$TEST_NAME PERF STATS - $RUN/$N - $INFRA_NAME - $PHP_NAME (JIT: $PHP_JIT)"
        echo "---------------------------------------------------------------------------------------"

        # Verifying output
        run_cli "verbose" "0" "1" "$1" 2>&1 | tee -a "$output_file"
        if [ ! -z "$test_expectation_file" ]; then
            assert_test_output "$test_expectation_file" "$output_file"
        fi

        # Measuring memory usage
        run_cli "memory" "0" "$TEST_REQUESTS" "$1" 2>&1 | tee -a "$memory_log_file"

        # Gathering perf metrics
        run_cli "perf" "0" "$TEST_REQUESTS" "$1" 2>&1 | tee -a "$perf_log_file"
    done

    if [ "$INFRA_DEBUG_ENVIRONMENT" == "1" ]; then
        declare -a v_context_switches=(0 0)
        declare -a n_context_switches=(0 0)
        declare -a minor_page_faults=(0 0)
        declare -a major_page_faults=(0 0)
        declare -a irqs=(0 0)
        declare -a soft_irqs=(0 0)
        declare -a run_queue_length=(0 0)
        declare -a io_reads=(0 0)
        declare -a io_writes=(0 0)
        declare -a io_time=(0 0)
    fi

    $PROJECT_ROOT/build/script/wait_for_cpu_temp.sh "$PHP_CPU" "$INFRA_MAX_ALLOWED_CPU_TEMP" "$CPU_TEMP_TIMEOUT" "$CPU_TEMP_FALLBACK_SLEEP"

    # Benchmark
    for i in $(seq $TEST_ITERATIONS); do
        for PHP_CONFIG_FILE in $PROJECT_ROOT/config/php/*.ini; do
            load_php_config

            cpu_temp="$([ -f /sys/class/thermal/thermal_zone0/temp ] && echo "scale=2; $(cat /sys/class/thermal/thermal_zone0/temp) / 1000" | bc || echo "N/A") °C"
            echo "---------------------------------------------------------------------------------------"
            echo "$TEST_NAME BENCHMARK $i/$TEST_ITERATIONS - run $RUN/$N - $INFRA_NAME - $PHP_NAME (JIT: $PHP_JIT) - CPU: $cpu_temp"
            echo "---------------------------------------------------------------------------------------"

            # Debugging environment - initial state
            if [ "$INFRA_DEBUG_ENVIRONMENT" == "1" ]; then
                read -r "v_context_switches[0]" "n_context_switches[0]" \
                    "minor_page_faults[0]" "major_page_faults[0]" \
                    "irqs[0]" "soft_irqs[0]" "run_queue_length[0]" \
                    "io_reads[0]" "io_writes[0]" "io_time[0]" < <(collect_environment_metrics "$PHP_CPU")
            fi

            run_cli "quiet" "$TEST_WARMUP" "$TEST_REQUESTS" "$1" 2>&1 | tee -a "$log_file"

            # Debugging environment - final state
            if [ "$INFRA_DEBUG_ENVIRONMENT" == "1" ]; then
                read -r "v_context_switches[1]" "n_context_switches[1]" \
                    "minor_page_faults[1]" "major_page_faults[1]" \
                    "irqs[1]" "soft_irqs[1]" "run_queue_length[1]" \
                    "io_reads[1]" "io_writes[1]" "io_time[1]" < <(collect_environment_metrics "$PHP_CPU")

                print_environment_metrics_diff "$i" | tee -a "$environment_debug_log_file"
            fi
        done
    done

    postprocess_results
}

run_benchmark () {
    test_expectation_file="${test_config//.ini/.expectation}"
    if [ ! -f "$test_expectation_file" ]; then
        test_expectation_file=""
    fi
    result_dir="$infra_dir/${TEST_NUMBER}_${TEST_ID}"
    result_file="$result_dir/result"

    mkdir -p "$result_dir"
    touch "$result_file.tsv"
    touch "$result_file.md"

    print_result_tsv_header "$result_file"
    print_result_md_header "$result_file"

    first_log_file=""
    first_results=""
    first_n=""
    first_mean=""
    first_median=""
    first_var=""

    case "$TEST_ID" in
        laravel_*)
            run_real_benchmark "app/laravel/public/index.php" "" "production"
            ;;

        symfony_main_*)
            run_real_benchmark "app/symfony/public/index.php" "/" "prod"
            ;;

        symfony_blog_*)
            run_real_benchmark "app/symfony/public/index.php" "/en/blog/" "prod"
            ;;

        wordpress_*)
            run_real_benchmark "app/wordpress/index.php" "/" "prod"
            ;;

        bench)
            run_micro_benchmark "app/zend/bench.php"
            ;;

        micro_bench)
            run_micro_benchmark "app/zend/micro_bench.php"
            ;;

        *)
            echo "Invalid test ID!"
            exit 1
            ;;
    esac

    for PHP_CONFIG_FILE in $PROJECT_ROOT/config/php/*.ini; do
        load_php_config

        format_perf_log_file "$perf_log_file"

        format_memory_log_file "$memory_log_file"

        print_result_value "$log_file" "$memory_log_file" "$perf_log_file" "$result_file" "$final_result_file" "$stat_file"
    done

    echo "" >> "$final_result_file.md"
    cat "$result_file.md" >> "$final_result_file.md"
}

CPU_COUNT="$(nproc)"
PHP_CPU="$(( CPU_COUNT - 1 ))"

CPU_TEMP_TIMEOUT=180
CPU_TEMP_FALLBACK_SLEEP=10

result_base_dir="$PROJECT_ROOT/tmp/results/$RESULT_ROOT_DIR"

infra_dir="$result_base_dir/${RUN}_${INFRA_ID}"
final_result_file="$infra_dir/result"
mkdir -p "$infra_dir"
touch "$final_result_file.tsv"
touch "$final_result_file.md"

print_result_tsv_header "$final_result_file"

environment_file="$infra_dir/environment"

print_environment "$environment_file"
cat "$environment_file.md" >> "$final_result_file.md"

function run_benchmarks () {
    TEST_NUMBER=0
    for test_config in $PROJECT_ROOT/config/test/*.ini; do
        source $test_config
        ((TEST_NUMBER=TEST_NUMBER+1))

        if [[ "$TEST_ID" =~ ^wordpress_.*$ ]]; then
            sudo systemctl start containerd.service
            sudo service docker start

            db_container_id="$(docker ps -aqf "name=wordpress_db")"
            sudo cgexec -g cpuset:mysql \
                docker start "$db_container_id"

            $PROJECT_ROOT/build/script/wait_for_mysql.sh "wordpress_db" "wordpress" "wordpress" "wordpress" "60"
        fi

        run_benchmark

        if [[ "$TEST_ID" =~ ^wordpress_.*$ ]]; then
            sudo service docker stop
            sudo systemctl stop containerd.service
        fi
    done
}

run_benchmarks
