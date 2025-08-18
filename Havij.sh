#!/bin/bash
# =================================================================
# اسکریپت جامع مدیریت سرور
# Version: 2.0
# Telegram: @sorshtaml
# =================================================================
# تعریف رنگ‌ها برای خروجی بهتر
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
YELLOW='\033[1;93m'
NC='\033[0m' # No Color
# متغیرهای سراسری برای اطلاعات سرور
SERVER_IP=""
SERVER_COUNTRY=""
SERVER_COUNTRY_CODE=""
SERVER_ISP=""
# --- تابع بررسی ابزارهای مورد نیاز ---
check_dependencies() {
    local missing_deps=()
    local deps_to_check=( "curl" "jq" "wget" "bc" "lsb_release" "dig" )
    echo -e "${CYAN}Checking for required tools...${NC}"
    for cmd in "${deps_to_check[@]}"; do
        if ! command -v $cmd &> /dev/null; then
            if [ "$cmd" == "dig" ]; then
                missing_deps+=("dnsutils")
            else
                missing_deps+=("$cmd")
            fi
        fi
    done
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${RED}Error: The following packages are not installed:${NC}"
        # Print unique dependencies
        printf " - %s\n" "${missing_deps[@]}" | sort -u
        echo -e "${CYAN}Please install them by running:${NC}"
        echo "sudo apt-get update && sudo apt-get install -y ${missing_deps[*]}"
        exit 1
    fi
    echo -e "${GREEN}All required tools are installed.${NC}"
}
# --- تابع دریافت اطلاعات سرور ---
get_server_info() {
    SERVER_IP=$(hostname -I | awk '{print $1}')
    IP_INFO=$(curl -sS --max-time 5 "http://ipwhois.app/json/$SERVER_IP")
    SERVER_COUNTRY=$(echo "$IP_INFO" | jq -r '.country // "N/A"')
    SERVER_COUNTRY_CODE=$(echo "$IP_INFO" | jq -r '.country_code // "N/A"' | tr '[:upper:]' '[:lower:]')
    SERVER_ISP=$(echo "$IP_INFO" | jq -r '.isp // "N/A"')
}
# --- تابع نمایش هدر ---
display_header() {
    local menu_title="$1"
    echo -e "${WHITE}Telegram Channel:${NC} @coming-soon"
    echo -e "${WHITE}Telegram ID:${NC}      @sorshtaml"
    echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
    echo -e "${CYAN}IP Address:${NC} $SERVER_IP"
    echo -e "${CYAN}Location:${NC}   $SERVER_COUNTRY ($SERVER_COUNTRY_CODE)"
    echo -e "${CYAN}Datacenter:${NC} $SERVER_ISP"
    echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
    echo -e "${WHITE}$menu_title${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
}
# --- تابع برای نمایش انیمیشن اسپینر ---
run_with_spinner() {
    local title="$1"
    local cmd="$2"
    
    # Hide cursor
    tput civis
    
    # Run command in the background and redirect its output to a temporary log file
    local temp_log
    temp_log=$(mktemp)
    eval "$cmd" > "$temp_log" 2>&1 &
    local pid=$!
    # Bouncing block animation settings
    local i=0
    local bar_width=25
    
    # While the command is running, show the animation
    while kill -0 $pid 2>/dev/null; do
        # Calculate position of the block
        local pos=$((i % (bar_width * 2)))
        if [ $pos -ge $bar_width ]; then
            pos=$((bar_width * 2 - pos))
        fi
        
        # Print the bar
        printf "\r${CYAN}${title}... [ "
        for ((j=0; j<bar_width; j++)); do
            if [ $j -eq $pos ]; then
                printf "▓"
            else
                printf "░"
            fi
        done
        printf " ]${NC}"
        
        i=$((i+1))
        sleep 0.1
    done
    
    # Wait for the command to finish and get its exit code
    wait $pid
    local exit_code=$?
    # Clear the spinner line
    printf "\r%s\n" "$(tput el)"
    
    # Show success or failure message
    if [ $exit_code -eq 0 ]; then
        printf "${GREEN}✅ ${title}... Finished.${NC}\n"
    else
        printf "${RED}❌ ${title}... Failed.${NC}\n"
    fi
    
    # Clean up the temporary log file and show cursor again
    rm -f "$temp_log"
    tput cnorm
    
    return $exit_code
}
# --- تابع تنظیم بهترین میرور ---
set_best_mirror() {
    clear
    display_header "Setting the best Mirror"
    
    # تابع کمکی برای اعمال تغییرات میرور
    apply_mirror_url() {
        local selected_mirror=$1
        if [ -z "$selected_mirror" ]; then
            echo -e "${RED}Error: No mirror URL provided.${NC}"; return;
        fi
        
        local clean_mirror_url=${selected_mirror%/}
        echo -e "${CYAN}Applying mirror: ${GREEN}${clean_mirror_url}${NC}"
        local version=$(lsb_release -sr | cut -d '.' -f 1)
        local sources_file
        if [[ "$version" -ge 24 ]]; then
            sources_file="/etc/apt/sources.list.d/ubuntu.sources"
        else
            sources_file="/etc/apt/sources.list"
        fi
        echo "Backing up current sources file to ${sources_file}.bak..."
        sudo cp "$sources_file" "${sources_file}.bak.$(date +%F-%T)"
        echo "Updating sources file..."
        sudo sed -i -E "s|URIs: https?://[^ ]+|URIs: ${clean_mirror_url}|g" "$sources_file" 2>/dev/null
        sudo sed -i -E "s|deb https?://[^ ]+|deb ${clean_mirror_url}|g" "$sources_file" 2>/dev/null
        echo "Running apt-get update..."
        sudo apt-get update
        echo -e "${GREEN}Mirror updated successfully!${NC}"
    }
    measure_speed() {
        local url=$1; local clean_url=${url%/};
        local output=$(wget --timeout=5 --tries=1 -O /dev/null "$clean_url/dists/$(lsb_release -cs)/Release" 2>&1 | grep -o '[0-9.]* [KM]B/s' | tail -1)
        if [[ -z $output ]]; then echo -1; else
            if [[ $output == *K* ]]; then echo "$output" | sed 's/ KB\/s//';
            elif [[ $output == *M* ]]; then echo "scale=2; $(echo "$output" | sed 's/ MB\/s//') * 1024" | bc; fi
        fi
    }
    # تابع اصلی برای تست یک لیست از میرورها
    test_mirrors() {
        local -n mirrors_to_test=$1 # Pass array by reference
        for mirror in "${mirrors_to_test[@]}"; do
            printf "${CYAN}%-50s${NC} | " "$mirror"
            speed=$(measure_speed "$mirror")
            if [[ $speed == -1 ]]; then echo -e "${RED}Failed to connect${NC}"; continue; fi
            echo -e "${GREEN}${speed} KB/s${NC}"
            if (( $(echo "$speed > best_speed" | bc -l) )); then
                best_speed=$speed
                best_mirror=$mirror
            fi
        done
    }
    echo -e "\n${BLUE}Starting smart mirror test based on your location...${NC}"
    
    iranian_mirrors=(
        "http://mirror.afranet.com/ubuntu/" "http://ftp.iust.ac.ir/pub/ubuntu/" "http://mirror.tabrizu.ac.ir/ubuntu/"
        "http://ftp.um.ac.ir/ubuntu/" "http://ftp.ipm.ac.ir/pub/ubuntu/" "https://ubuntu.pishgaman.net/ubuntu"
        "https://mirrors.pardisco.co/ubuntu/" "http://mirror.aminidc.com/ubuntu/" "http://mirror.faraso.org/ubuntu/"
        "https://ir.ubuntu.sindad.cloud/ubuntu/" "https://ubuntu-mirror.kimiahost.com/" "https://archive.ubuntu.petiak.ir/ubuntu/"
        "https://ubuntu.hostiran.ir/ubuntuarchive/" "https://ubuntu.bardia.tech/" "https://mirror.iranserver.com/ubuntu/"
        "https://ir.archive.ubuntu.com/ubuntu/" "https://mirror.0-1.cloud/ubuntu/" "http://linuxmirrors.ir/pub/ubuntu/"
        "http://repo.iut.ac.ir/repo/Ubuntu/" "https://ubuntu.shatel.ir/ubuntu/" "http://ubuntu.byteiran.com/ubuntu/"
        "https://mirror.rasanegar.com/ubuntu/" "http://mirrors.sharif.ir/ubuntu/" "http://mirror.ut.ac.ir/ubuntu/"
        "http://mirror.asiatech.ir/ubuntu/" "https://mirror.digitalvps.ir/ubuntu" "https://iranrepo.ir/ubuntu"
    )
    international_mirrors=(
        "http://archive.ubuntu.com/ubuntu/" "http://nova.clouds.archive.ubuntu.com/ubuntu" "http://mirror.manageit.ir/ubuntu" 
        "http://de.archive.ubuntu.com/ubuntu/" "http://fr.archive.ubuntu.com/ubuntu/" "http://es.archive.ubuntu.com/ubuntu/" 
        "http://us.archive.ubuntu.com/ubuntu/" "http://tr.archive.ubuntu.com/ubuntu" "http://mirrors.digitalocean.com/ubuntu" 
        "http://mirror.leaseweb.com/ubuntu" "http://mirror.hetzner.de/ubuntu/archive/" "http://mirror.hetzner.com/ubuntu/archive/" 
        "http://ftp.halifax.rwth-aachen.de/ubuntu/" "https://mirror.netcologne.de/ubuntu/" "http://ftp.linux.org.tr/ubuntu/" 
        "http://mirror.veriteknik.net.tr/ubuntu/" "http://nl.archive.ubuntu.com/ubuntu/" "http://mirror.i3d.net/pub/ubuntu/archive/" 
        "http://gb.archive.ubuntu.com/ubuntu/" "http://mirror.bytemark.co.uk/ubuntu/" "http://ubuntu.mirrors.ovh.net/ftp.ubuntu.com/" 
        "http://mirror.us.leaseweb.net/ubuntu/" "http://sg.archive.ubuntu.com/ubuntu/" "http://mirror.vodien.com/ubuntu/" 
        "http://za.archive.ubuntu.com/ubuntu/" "http://ca.archive.ubuntu.com/ubuntu/" "http://jp.archive.ubuntu.com/ubuntu/" 
        "http://kr.archive.ubuntu.com/ubuntu/" "http://ch.archive.ubuntu.com/ubuntu/" "http://ftp.belnet.be/ubuntu/dists/" 
        "http://se.archive.ubuntu.com/ubuntu/" "http://fi.archive.ubuntu.com/ubuntu/" "http://dk.archive.ubuntu.com/ubuntu/" 
        "http://no.archive.ubuntu.com/ubuntu/" "http://cz.archive.ubuntu.com/ubuntu/" "http://pl.archive.ubuntu.com/ubuntu/" 
        "http://at.archive.ubuntu.com/ubuntu/" "http://hu.archive.ubuntu.com/ubuntu/" "http://gr.archive.ubuntu.com/ubuntu/" 
        "http://pt.archive.ubuntu.com/ubuntu/" "http://au.archive.ubuntu.com/ubuntu/" "http://mirror.aarnet.edu.au/pub/ubuntu/archive/" 
        "http://mirror.internode.on.net/pub/ubuntu/ubuntu/" "http://us-east-1.ec2.archive.ubuntu.com/ubuntu/" 
        "http://us-east-2.ec2.archive.ubuntu.com/ubuntu/" "http://us-west-1.ec2.archive.ubuntu.com/ubuntu/" 
        "http://us-west-2.ec2.archive.ubuntu.com/ubuntu/" "http://af-south-1.ec2.archive.ubuntu.com/ubuntu/" 
        "http://ap-east-1.ec2.archive.ubuntu.com/ubuntu/" "http://ap-south-1.ec2.archive.ubuntu.com/ubuntu/" 
        "http://ap-northeast-2.ec2.archive.ubuntu.com/ubuntu/" "http://ap-southeast-1.ec2.archive.ubuntu.com/ubuntu/" 
        "http://ap-southeast-2.ec2.archive.ubuntu.com/ubuntu/" "http://ap-northeast-1.ec2.archive.ubuntu.com/ubuntu/" 
        "http://ca-central-1.ec2.archive.ubuntu.com/ubuntu/" "http://eu-central-1.ec2.archive.ubuntu.com/ubuntu/" 
        "http://eu-west-1.ec2.archive.ubuntu.com/ubuntu/" "http://eu-west-2.ec2.archive.ubuntu.com/ubuntu/" 
        "http://eu-south-1.ec2.archive.ubuntu.com/ubuntu/" "http://eu-west-3.ec2.archive.ubuntu.com/ubuntu/" 
        "http://eu-north-1.ec2.archive.ubuntu.com/ubuntu/" "http://me-south-1.ec2.archive.ubuntu.com/ubuntu/" 
        "http://sa-east-1.ec2.archive.ubuntu.com/ubuntu/" "https://mirror.yandex.ru/ubuntu/" "https://mirrors.edge.kernel.org/ubuntu/" 
        "http://ftp.kaist.ac.kr/ubuntu/" "http://ftp.neowiz.com/ubuntu/" "https://ftp.icm.edu.pl/pub/Linux/ubuntu/" 
        "https://ftp.task.gda.pl/pub/linux/ubuntu/" "https://mirror.kumi.systems/ubuntu/" "http://mirror.clarkson.edu/ubuntu/" 
        "http://ftp.heanet.ie/pub/ubuntu/" "http://mirror.cedia.org.ec/ubuntu/" "https://mirror.vpsfree.cz/ubuntu/" 
        "https://mirror.linux.pizza/ubuntu/" "https://ubuntu.c3sl.ufpr.br/" "https://quantum-mirror.hu/mirrors/pub/ubuntu/" 
        "https://mirror.picobar.dev/ubuntu/" "https://mirror.dogado.de/ubuntu/" "http://ftp.fau.de/ubuntu/" 
        "https://fastmirror.pp.ua/ubuntu/" "http://mirror.infomaniak.com/ubuntu/" "https://mirrors.g-core.labs.org/ubuntu/" 
        "http://mirrors.xmission.com/ubuntu/" "https://mirrors.up.pt/ubuntu/"
    )
    best_mirror=""; best_speed=0;
    if [[ "$SERVER_COUNTRY_CODE" == "ir" ]]; then
        # مرحله 1: تست میرورهای ایران
        echo -e "\n${BLUE}--- Stage 1: Testing ${#iranian_mirrors[@]} Iranian mirrors ---${NC}"
        echo -e "${BLUE}Mirror URL | Download Speed (KB/s)${NC}"
        echo "-----------------------------------------------------"
        test_mirrors iranian_mirrors
        # پرسش از کاربر برای ادامه
        if [ -n "$best_mirror" ]; then
            echo -e "\n${GREEN}Iranian mirror test complete. Fastest local mirror found:${NC}"
            echo -e "${CYAN}$best_mirror${WHITE} with speed ${GREEN}$best_speed KB/s${NC}"
        fi
        read -p "Do you want to test the remaining ${#international_mirrors[@]} international mirrors? (y/n): " continue_test
        if [[ "$continue_test" == "y" || "$continue_test" == "Y" ]]; then
            # مرحله 2: تست میرورهای بین‌المللی
            echo -e "\n${BLUE}--- Stage 2: Testing ${#international_mirrors[@]} international mirrors ---${NC}"
            echo -e "${BLUE}Mirror URL | Download Speed (KB/s)${NC}"
            echo "-----------------------------------------------------"
            test_mirrors international_mirrors
        else
            echo -e "${YELLOW}Skipping international mirror test.${NC}"
        fi
    else
        # اگر سرور خارج از ایران بود، همه را با هم تست کن
        echo -e "\n${BLUE}--- Testing all available mirrors ---${NC}"
        echo -e "${BLUE}Mirror URL | Download Speed (KB/s)${NC}"
        echo "-----------------------------------------------------"
        all_mirrors=("${iranian_mirrors[@]}" "${international_mirrors[@]}")
        test_mirrors all_mirrors
    fi
    # نمایش نتیجه نهایی و اعمال
    if [ -n "$best_mirror" ]; then
        echo -e "\n${BLUE}-----------------------------------------------------${NC}"
        echo -e "${GREEN}Overall fastest mirror found:${NC}"
        echo -e "${CYAN}$best_mirror${WHITE} with speed ${GREEN}$best_speed KB/s${NC}"
        echo -e "${BLUE}-----------------------------------------------------${NC}"
        
        read -p "Do you want to apply this mirror? (y/n): " confirm
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
            apply_mirror_url "$best_mirror"
        else
            read -p "Do you want to enter a mirror manually? (y/n): " manual_confirm
            if [[ "$manual_confirm" == "y" || "$manual_confirm" == "Y" ]]; then
                read -p "Please enter the mirror URL: " manual_mirror
                if [ -n "$manual_mirror" ]; then apply_mirror_url "$manual_mirror";
                else echo -e "${RED}No URL entered. Operation cancelled.${NC}"; fi
            else echo -e "${YELLOW}Operation cancelled.${NC}"; fi
        fi
    else 
        echo -e "\n${RED}No working mirrors were found.${NC}"
    fi
}
# --- تابع تنظیم بهترین DNS ---
set_best_dns() {
    clear
    display_header "Setting the best DNS"
    
    echo -e "\n${BLUE}Starting DNS speed test...${NC}"
    
    declare -A dns_providers
    # DNS providers اصلی
    dns_providers["Electro"]="78.157.42.100 78.157.42.101"
    dns_providers["RadarGame"]="10.202.10.10 10.202.10.11"
    dns_providers["Mokhaberat"]="95.38.132.152 95.38.132.153"
    dns_providers["Asiatech"]="194.36.174.161 194.36.174.162"
    dns_providers["Shatel"]="85.15.1.15 85.15.1.14"
    dns_providers["ParsOnline"]="91.98.98.98 91.99.99.99"
    dns_providers["HiWEB"]="188.40.40.40 188.40.41.41"
    dns_providers["Respina"]="91.99.101.102 91.99.101.103"
    dns_providers["Afranet"]="91.99.96.9 91.99.97.9"
    dns_providers["MobinNet"]="92.114.36.36 92.114.37.37"
    dns_providers["ParsAbr"]="172.29.13.30 172.29.13.40"
    dns_providers["Cloudflare"]="1.1.1.1 1.0.0.1"
    dns_providers["Google"]="8.8.8.8 8.8.4.4"
    dns_providers["Quad9"]="9.9.9.9 149.112.112.112"
    dns_providers["OpenDNS"]="208.67.222.222 208.67.220.220"
    dns_providers["ControlD"]="76.76.2.11 76.76.10.11"
    dns_providers["AdGuard"]="94.140.14.14 94.140.15.15"
    dns_providers["DNS.WATCH"]="84.200.69.80 84.200.70.40"
    dns_providers["NextDNS"]="45.90.28.238 45.90.30.238"
    dns_providers["Neustar"]="156.154.70.1 156.154.71.1"
    dns_providers["Mullvad"]="194.242.2.2 193.19.108.2"
    dns_providers["FDN"]="80.67.169.12 80.67.169.40"
    dns_providers["Viewqwest"]="61.8.31.133 61.8.31.134"
    dns_providers["IIJ"]="210.173.160.27 210.173.160.28"
    dns_providers["TWNIC"]="101.101.101.101 101.102.103.104"
    dns_providers["CleanBrowse"]="185.228.168.9 185.228.169.9"
    dns_providers["Yandex"]="77.88.8.8 77.88.8.1"
    dns_providers["TurkTelekom"]="195.175.39.49 195.175.39.50"
    dns_providers["Turkcell"]="193.192.108.6 193.192.108.7"
    # DNS providers جدید
    dns_providers["Comodo Secure DNS"]="8.26.56.26 8.20.247.20"
    dns_providers["Verisign"]="64.6.64.6 64.6.65.6"
    # نسخه‌های قدیمی و جدید Level3
    dns_providers["Level3"]="4.2.2.4 4.2.2.3"
    dns_providers["Level3 Old"]="4.2.2.1 4.2.2.2"
    # نسخه‌های قدیمی و جدید NextDNS
    dns_providers["NextDNS (Old)"]="45.90.30.180 45.90.28.180"
    # نسخه‌های قدیمی و جدید Shecan
    dns_providers["Shecan"]="185.55.225.25 185.55.226.26"
    dns_providers["Shecan Old"]="178.22.122.100 185.51.200.2"
    # نسخه‌های قدیمی و جدید ArvanCloud
    dns_providers["ArvanCloud"]="185.43.135.1 185.43.133.1"
    dns_providers["ArvanCloud Old"]="185.129.244.1 185.129.244.2"
    # سایر DNS providers جدید
    dns_providers["DNS PRO"]="87.107.110.109 87.107.110.110"
    dns_providers["Telecommunication Company of Iran"]="217.218.155.155 217.218.127.127"
    dns_providers["403 (ISP Network)"]="10.202.10.202 10.202.10.102"
    dns_providers["Private Network"]="10.70.95.150 10.70.95.162"
    
    # ایجاد فایل موقت برای ذخیره نتایج
    temp_dns_results=$(mktemp)
    
    # --- تابع اجرای تست DNS ---
    run_dns_tests() {
        results=()
        for name in "${!dns_providers[@]}"; do
            ips=${dns_providers[$name]}; read -r dns1 dns2 <<< "$ips"
            time1=$(dig @$dns1 google.com +time=2 +tries=1 | grep "Query time:" | cut -d ' ' -f 4)
            if [ -n "$dns2" ]; then time2=$(dig @$dns2 google.com +time=2 +tries=1 | grep "Query time:" | cut -d ' ' -f 4); else time2=""; fi
            if [[ -z "$time1" && -z "$time2" ]]; then avg_time=-1; else
                if [[ -n "$time1" && -n "$time2" ]]; then avg_time=$(( (time1 + time2) / 2 ));
                elif [ -n "$time1" ]; then avg_time=$time1; else avg_time=$time2; fi
            fi
            results+=("$avg_time|$name|$ips")
        done
        # نوشتن نتایج در فایل موقت
        printf "%s\n" "${results[@]}" > "$temp_dns_results"
    }
    
    # اجرای تست DNS با انیمیشن اسپینر
    run_with_spinner "Testing DNS servers" "run_dns_tests"
    
    # خواندن نتایج از فایل موقت
    mapfile -t results < "$temp_dns_results"
    rm -f "$temp_dns_results"
    
    IFS=$'\n' sorted_results=($(sort -n <<<"${results[*]}")); unset IFS
    echo -e "\n${CYAN}📊 DNS Test Results (sorted by speed):${NC}"
    printf "${WHITE}%-4s %-15s %-25s %-10s${NC}\n" "No." "Provider" "DNS Servers" "Avg Time"
    echo "------------------------------------------------------------"
    
    working_dns=(); choice_num=1
    for r in "${sorted_results[@]}"; do
        IFS='|' read -r time name ips <<< "$r"
        if [ "$time" -ne -1 ]; then
            printf "%-4s %-15s %-25s ${GREEN}%s${NC}\n" "$choice_num" "$name" "$ips" "${time} ms"
            working_dns+=("$ips"); ((choice_num++))
        fi
    done
    for r in "${sorted_results[@]}"; do
        IFS='|' read -r time name ips <<< "$r"
        if [ "$time" -eq -1 ]; then printf "${RED}%-4s %-15s %-25s %s${NC}\n" "X" "$name" "$ips" "Failed"; fi
    done
    if [ ${#working_dns[@]} -eq 0 ]; then echo -e "\n${RED}❌ No working DNS servers found.${NC}"; return; fi
    echo -e "\n${CYAN}Please choose the DNS to set (enter the number):${NC}"; read -p "Choice: " choice
    if [[ "$choice" -gt 0 && "$choice" -le ${#working_dns[@]} ]]; then
        selected_dns_set=${working_dns[$((choice-1))]}
        read -r dns1 dns2 <<< "$selected_dns_set"
        
        echo -e "You selected: ${GREEN}$selected_dns_set${NC}"
        
        # --- بخش اعمال DNS به روش ترکیبی و نهایی ---
        
        # مرحله 1: تنظیم مستقیم DNS روی اینترفیس اصلی برای override کردن DHCP
        iface=$(ip route | grep default | awk '{print $5}' | head -n1)
        if [ -n "$iface" ]; then
            echo -e "${CYAN}Applying DNS directly to interface ${WHITE}$iface${CYAN} to override DHCP...${NC}"
            # دستور اصلاح شده: متغیر بدون علامت نقل قول پاس داده می‌شود
            sudo resolvectl dns "$iface" $selected_dns_set
            sudo resolvectl domain "$iface" "~."
        else
            echo -e "${YELLOW}Warning: Could not detect the main network interface. Skipping interface-specific DNS setting.${NC}"
        fi
        # مرحله 2: بازنویسی مستقیم /etc/resolv.conf برای اطمینان و پایداری
        echo -e "${YELLOW}Applying DNS by recreating /etc/resolv.conf...${NC}"
        sudo rm -f /etc/resolv.conf
        echo "nameserver $dns1" | sudo tee /etc/resolv.conf > /dev/null
        if [ -n "$dns2" ]; then
            echo "nameserver $dns2" | sudo tee -a /etc/resolv.conf > /dev/null
        fi
        
        # مرحله 3 (جدید): دائمی کردن تنظیمات با Cron Job
        echo -e "${YELLOW}Making the interface DNS setting persistent across reboots using cron...${NC}"
        if [ -n "$iface" ]; then
            # دستور برای اجرا شدن در زمان بوت (شامل هر دو دستور dns و domain)
            reboot_command="sleep 15 && /usr/bin/resolvectl dns $iface $selected_dns_set && /usr/bin/resolvectl domain $iface '~.'"
            # کامنت برای شناسایی دستور در کرون
            cron_comment="# Set custom DNS on reboot by toolbox script"
            
            # جستجو و حذف cron job‌های قبلی مرتبط با DNS
            echo -e "${CYAN}Searching for existing DNS cron jobs...${NC}"
            if sudo crontab -u root -l 2>/dev/null | grep -q "resolvectl dns"; then
                echo -e "${YELLOW}Found existing DNS cron jobs. Removing them...${NC}"
                # حذف تمام خطوط حاوی resolvectl dns
                sudo crontab -u root -l 2>/dev/null | grep -v "resolvectl dns" | sudo crontab -u root -
            fi
            
            # افزودن cron job جدید
            echo -e "${CYAN}Adding new DNS cron job...${NC}"
            (sudo crontab -u root -l 2>/dev/null; echo "$cron_comment"; echo "@reboot $reboot_command") | sudo crontab -u root -
            echo -e "${GREEN}✅ Cron job created successfully to re-apply DNS on reboot.${NC}"
        else
            echo -e "${YELLOW}Warning: Could not create cron job due to missing interface.${NC}"
        fi
        # مرحله 4: راه‌اندازی مجدد سرویس برای اعمال تمام تغییرات
        echo -e "${CYAN}Restarting systemd-resolved service to apply all changes...${NC}"
        sudo systemctl restart systemd-resolved
        echo -e "${GREEN}✅ DNS servers have been updated using the combined method.${NC}"
        echo -e "${CYAN}Final DNS status:${NC}"
        resolvectl status | grep "DNS Server" -A 3
    else
        echo -e "${RED}Invalid choice.${NC}"
    fi
}
# --- تابع بهینه‌سازی شبکه ---
setup_optimization_network() {
    # ایجاد فایل اسکریپت بهینه‌سازی شبکه
    cat > /root/OptimizeNetwork.sh << 'SCRIPT_EOF'
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
#--- Global variables and constants ---
readonly SCRIPT_NAME="$(basename "${0}")"
readonly SCRIPT_VERSION="6.4 (Hybrid Final - Definitive Fix)"
readonly LOG_FILE="/var/log/network_optimization.log"
readonly BACKUP_FILE_PATH="/tmp/network_config_backup_$(date +%s).txt"
readonly ROLLBACK_STATE_FILE="/tmp/network_optimization.state"
readonly LOCK_FILE="/var/run/network_optimization.lock"
readonly PERSISTENT_SERVICE_FILE="/etc/systemd/system/network-optimization.service"
#--- Color codes ---
readonly RED='\033[0;31m'; readonly GREEN='\033[0;32m'; readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'; readonly CYAN='\033[0;36m'; readonly WHITE='\033[1;37m'
readonly NC='\033[0m'
#--- Script state variables ---
declare -A OPTIMIZATION_FEATURES
declare -A BACKUP_SETTINGS
declare -A APPLIED_SETTINGS
declare MAIN_INTERFACE=""
declare CPU_CORES=0
declare IS_VIRTUAL=false
declare DRY_RUN=false
#===============================================================================
# Utility Functions
#===============================================================================
log() {
    local level="$1"; shift; local message="$*"; local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "${LOG_FILE}"
}
error_exit() {
    local error_message="$1"; local exit_code="${2:-1}"
    log "ERROR" "FATAL: ${error_message}"
    cleanup
    exit "${exit_code}"
}
cleanup() {
    if [[ -f "${LOCK_FILE}" ]]; then rm -f "${LOCK_FILE}" 2>/dev/null || true; fi
}
trap cleanup EXIT
trap 'error_exit "Script interrupted by user" 130' INT
trap 'error_exit "Script terminated" 143' TERM
# The core of fault-tolerant execution and dry-run logic
try_apply_setting() {
    local description="$1"; shift; local command_to_run=("$@")
    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY-RUN" "Would execute: ${description} -> [${command_to_run[*]}]"
        return 0
    fi
    if output=$("${command_to_run[@]}" 2>&1); then
        log "INFO" "  ✓ ${GREEN}SUCCESS${NC}: ${description}"
        # DEFINITIVE FIX (v6.4): Temporarily set IFS to a space to join the array correctly,
        # ensuring the command is stored as a clean, single-line string.
        local old_ifs=$IFS
        IFS=' '
        APPLIED_SETTINGS["${description}"]="${command_to_run[*]}"
        IFS=$old_ifs
        return 0
    else
        log "WARNING" "  ✗ ${YELLOW}FAILED${NC}: ${description}"
        log "WARNING" "    Error details: ${output}"
        return 1
    fi
}
#===============================================================================
# Pre-flight Checks & System Info
#===============================================================================
check_root() { if [[ $EUID -ne 0 ]]; then error_exit "This script must be run as root."; fi; }
check_dependencies() { for tool in ethtool ip grep awk sed lscpu; do if ! command -v "$tool" &>/dev/null; then if [[ "$tool" == "ethtool" ]]; then apt-get update && apt-get install -y ethtool || yum install -y ethtool; else error_exit "Required tool '${tool}' is not installed."; fi; fi; done; }
create_lock() { if [[ -f "${LOCK_FILE}" ]]; then error_exit "Lock file exists. Another instance may be running."; fi; echo $$ > "${LOCK_FILE}"; }
detect_system_info() { CPU_CORES=$(nproc); if systemd-detect-virt -q; then IS_VIRTUAL=true; else IS_VIRTUAL=false; fi; }
#===============================================================================
# Robust Network Interface Detection Functions
#===============================================================================
detect_by_default_route() {
    ip route show default 2>/dev/null | awk '/default/ {print $5}' | head -n1
}
detect_by_active_ethernet() {
    ip -brief link show up 2>/dev/null | grep -E '^(eth|en|ens|enp)' | awk '{print $1}' | head -n1
}
validate_interface() {
    local interface="$1"
    if ! ip link show "${interface}" >/dev/null 2>&1; then
        log "ERROR" "Interface '${interface}' does not exist."
        return 1
    fi
    if ! ethtool "${interface}" >/dev/null 2>&1; then
        log "ERROR" "Cannot query interface '${interface}' with ethtool."
        return 1
    fi
    return 0
}
detect_main_interface() {
    local interface=""
    local detection_methods=(
        "detect_by_default_route"
        "detect_by_active_ethernet"
    )
    
    log "INFO" "Starting robust network interface detection..."
    
    for method in "${detection_methods[@]}"; do
        interface=$(${method}) || continue
        if [[ -n "${interface}" ]] && validate_interface "${interface}"; then
            MAIN_INTERFACE="${interface}"
            log "INFO" "Main interface detected: ${GREEN}${MAIN_INTERFACE}${NC} (method: ${method})"
            return 0
        fi
    done
    
    error_exit "Could not automatically detect a valid network interface. Please specify one with -i."
}
#===============================================================================
# Analysis, Optimization, and State Management
#===============================================================================
analyze_interface() {
    local interface="$1"
    log "INFO" "--- Analyzing interface: ${interface} ---"
    create_configuration_backup "${interface}"
    log "INFO" "Driver: $(ethtool -i "${interface}" 2>/dev/null | grep "^driver:" | awk '{print $2}' || echo 'N/A')"
    ethtool -k "${interface}" 2>/dev/null | sed 's/^/\t/' || log "INFO" "\tCould not read features."
    local ring_info; ring_info=$(ethtool -g "${interface}" 2>/dev/null || echo "")
    if [[ -n "$ring_info" ]]; then
        local max_rx; max_rx=$(echo "${ring_info}" | grep "RX:" | head -n1 | awk '{print $2}'); local current_rx; current_rx=$(echo "${ring_info}" | grep "RX:" | tail -n1 | awk '{print $2}'); if [[ $current_rx -lt $max_rx ]]; then OPTIMIZATION_FEATURES["ring_rx"]="$max_rx"; fi
        local max_tx; max_tx=$(echo "${ring_info}" | grep "TX:" | head -n1 | awk '{print $2}'); local current_tx; current_tx=$(echo "${ring_info}" | grep "TX:" | tail -n1 | awk '{print $2}'); if [[ $current_tx -lt $max_tx ]]; then OPTIMIZATION_FEATURES["ring_tx"]="$max_tx"; fi
    fi
    local channel_info; channel_info=$(ethtool -l "${interface}" 2>/dev/null || echo "")
    if [[ -n "$channel_info" ]]; then
        local max_c; max_c=$(echo "${channel_info}" | grep "Combined:" | head -n1 | awk '{print $2}'); local cur_c; cur_c=$(echo "${channel_info}" | grep "Combined:" | tail -n1 | awk '{print $2}'); if [[ -n "$max_c" && "$max_c" -gt 1 ]]; then local optimal; optimal=$((max_c < CPU_CORES ? max_c : CPU_CORES)); if [[ $cur_c -lt $optimal ]]; then OPTIMIZATION_FEATURES["channels"]="$optimal"; fi; fi
    fi
    log "INFO" "--- Analysis complete ---"
}
create_configuration_backup() {
    local interface="$1"; log "INFO" "Creating full configuration backup to: ${BACKUP_FILE_PATH}"
    {
        echo "## Backup by ${SCRIPT_NAME} v${SCRIPT_VERSION} on $(date)"; echo "## Interface: $1"; echo
        echo "### Driver Info"; ethtool -i "$1" 2>/dev/null || echo "Info not available."; echo
        echo "### Link Settings"; ethtool "$1" 2>/dev/null || echo "Info not available."; echo
        echo "### Features"; ethtool -k "$1" 2>/dev/null || echo "Info not available."; echo
        echo "### Ring Buffers"; ethtool -g "$1" 2>/dev/null || echo "Info not available."; echo
        echo "### Coalescing"; ethtool -c "$1" 2>/dev/null || echo "Info not available."; echo
        echo "### Channels"; ethtool -l "$1" 2>/dev/null || echo "Info not available."
    } > "${BACKUP_FILE_PATH}"; log "INFO" "Configuration backup created."
}
apply_optimizations() {
    local interface="$1"
    log "INFO" "=== Applying Comprehensive Network Optimizations for ${interface} ==="
    log "INFO" "--- Applying low-latency offload settings... ---"
    local offload_features_off=("generic-receive-offload" "large-receive-offload" "tcp-segmentation-offload" "generic-segmentation-offload" "rx-gro-hw" "tx-nocache-copy")
    for feature in "${offload_features_off[@]}"; do
        BACKUP_SETTINGS["k:${feature}"]=$(ethtool -k "$interface" 2>/dev/null | grep -E "^${feature}:" | awk '{print $2}' || echo "on")
        try_apply_setting "Disable ${feature}" ethtool -K "$interface" "$feature" off || true
    done
    log "INFO" "--- Applying performance and reliability settings... ---"
    local perf_features_on=("rx-checksumming" "tx-checksumming" "scatter-gather" "receive-hashing")
    for feature in "${perf_features_on[@]}"; do
        BACKUP_SETTINGS["k:${feature}"]=$(ethtool -k "$interface" 2>/dev/null | grep -E "^${feature}:" | awk '{print $2}' || echo "off")
        try_apply_setting "Enable ${feature}" ethtool -K "$interface" "$feature" on || true
    done
    log "INFO" "--- Applying advanced optimizations... ---"
    if [[ -n "${OPTIMIZATION_FEATURES[ring_rx]:-}" ]] || [[ -n "${OPTIMIZATION_FEATURES[ring_tx]:-}" ]]; then
        BACKUP_SETTINGS["g:rx"]=$(ethtool -g "$interface" 2>/dev/null | grep "RX:" | tail -n1 | awk '{print $2}' || echo "256")
        BACKUP_SETTINGS["g:tx"]=$(ethtool -g "$interface" 2>/dev/null | grep "TX:" | tail -n1 | awk '{print $2}' || echo "256")
        try_apply_setting "Set Ring Buffers to max" ethtool -G "$interface" rx "${OPTIMIZATION_FEATURES[ring_rx]}" tx "${OPTIMIZATION_FEATURES[ring_tx]}" || true
    fi
    
    BACKUP_SETTINGS["c:adaptive"]="on"
    try_apply_setting "Set static interrupt coalescing" ethtool -C "$interface" adaptive-rx off adaptive-tx off rx-usecs 1 rx-frames 1 tx-usecs 8 tx-frames 32 || true
    
    if [[ -n "${OPTIMIZATION_FEATURES[channels]:-}" ]]; then
        BACKUP_SETTINGS["l:combined"]=$(ethtool -l "$interface" 2>/dev/null | grep "Combined:" | tail -n1 | awk '{print $2}' || echo "1")
        try_apply_setting "Set multi-queue channels to ${OPTIMIZATION_FEATURES[channels]}" ethtool -L "$interface" combined "${OPTIMIZATION_FEATURES[channels]}" || true
    fi
    BACKUP_SETTINGS["a:flowcontrol"]="on"
    try_apply_setting "Disable Flow Control" ethtool -A "$interface" rx off tx off autoneg off || true
    
    log "INFO" "=== Optimization Application Phase Complete ==="
}
save_rollback_state() {
    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY-RUN" "Skipping rollback state save."
        return
    fi
    if [[ ${#BACKUP_SETTINGS[@]} -gt 0 ]]; then
        declare -p BACKUP_SETTINGS > "${ROLLBACK_STATE_FILE}"
        log "INFO" "Rollback state saved to ${ROLLBACK_STATE_FILE}"
    fi
}
load_rollback_state() {
    if [[ -f "${ROLLBACK_STATE_FILE}" ]]; then
        # shellcheck source=/dev/null
        source "${ROLLBACK_STATE_FILE}"
        log "INFO" "Rollback state loaded from ${ROLLBACK_STATE_FILE}"
        return 0
    else
        log "WARNING" "No rollback state file found. Cannot perform rollback."
        return 1
    fi
}
validate_optimizations() {
    local interface="$1"
    log "INFO" "=== Validating Applied Optimizations ==="
    if [[ "$DRY_RUN" == "true" ]]; then log "DRY-RUN" "Skipping validation."; return; fi
    if ! ip link show "${interface}" | grep -q "state UP"; then log "WARNING" "Interface ${interface} is not UP"; else log "INFO" "✓ Interface ${interface} is UP"; fi
    sleep 1; local errors; errors=$(ethtool -S "${interface}" 2>/dev/null | grep -iE "(drop|error|fail|miss)" | awk '{s+=$2} END {print s+0}');
    if [[ $errors -gt 0 ]]; then log "WARNING" "Detected ${errors} total errors/drops on ${interface}"; else log "INFO" "✓ No significant errors detected"; fi
}
rollback_changes() {
    local interface="$1"
    log "INFO" "--- Rolling back network optimizations from last run ---"
    if ! load_rollback_state; then return 1; fi
    if [[ ${#BACKUP_SETTINGS[@]} -eq 0 ]]; then log "WARNING" "No backup settings found in state file."; rm -f "${ROLLBACK_STATE_FILE}"; return 1; fi
    
    for key in "${!BACKUP_SETTINGS[@]}"; do
        local type="${key%%:*}" cmd_part="${key#*:}" original_state="${BACKUP_SETTINGS[$key]}"
        case "$type" in
            k) try_apply_setting "[Rollback] Restore ${cmd_part} to ${original_state}" ethtool -K "${interface}" "${cmd_part}" "${original_state}" || true;;
            g) try_apply_setting "[Rollback] Restore ring buffers" ethtool -G "${interface}" rx "${BACKUP_SETTINGS[g:rx]}" tx "${BACKUP_SETTINGS[g:tx]}" || true; break;;
            c) try_apply_setting "[Rollback] Restore adaptive coalescing" ethtool -C "${interface}" adaptive-rx on adaptive-tx on || true;;
            l) try_apply_setting "[Rollback] Restore channels" ethtool -L "${interface}" combined "${original_state}" || true;;
            a) try_apply_setting "[Rollback] Restore flow control" ethtool -A "${interface}" rx on tx on autoneg on || true;;
        esac
    done
    log "INFO" "--- Rollback complete ---"
    rm -f "${ROLLBACK_STATE_FILE}"
}
create_persistent_service() {
    local interface="$1"
    if [[ "$DRY_RUN" == "true" ]]; then log "DRY-RUN" "Skipping persistence."; return; fi
    if [[ ${#APPLIED_SETTINGS[@]} -eq 0 ]]; then log "INFO" "No successful optimizations to persist."; return; fi
    log "INFO" "--- Creating systemd service ---"
    
    local exec_start_lines=""; for desc in "${!APPLIED_SETTINGS[@]}"; do
        # Retrieve the full, clean command string.
        local full_command=${APPLIED_SETTINGS[$desc]}
        # Prepend the absolute path to the tool for systemd
        exec_start_lines+="ExecStart=/usr/sbin/${full_command}\n"
    done
    
    local service_content; service_content=$(cat <<SERVICE_EOF
[Unit]
Description=Persistent Network Optimizations for ${interface} by ${SCRIPT_NAME}
After=network.target
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStartPre=/bin/sleep 2
${exec_start_lines}
[Install]
WantedBy=multi-user.target
SERVICE_EOF
)
    if echo -e "${service_content}" > "${PERSISTENT_SERVICE_FILE}"; then
        log "INFO" "Service file successfully written to ${PERSISTENT_SERVICE_FILE}"
        try_apply_setting "Reload systemd daemon" systemctl daemon-reload || true
        try_apply_setting "Enable persistent service" systemctl enable network-optimization.service || true
        log "INFO" "${GREEN}Persistence enabled.${NC}"
    else
        log "ERROR" "Failed to create systemd service file."
    fi
}
#===============================================================================
# Main Execution
#===============================================================================
show_usage() {
    cat <<HELP_EOF
${WHITE}Advanced Network Optimization Tool v${SCRIPT_VERSION}${NC}
${BLUE}Usage:${NC} ${SCRIPT_NAME} [OPTIONS]
${CYAN}This script combines robust detection, fault-tolerant application,
and dynamic persistence to safely optimize your network interface.${NC}
${BLUE}Options:${NC}
  -h, --help              Show this help message.
  -v, --version           Show script version.
  -i, --interface IFACE   Specify network interface to optimize (e.g., eth0).
  -a, --analyze-only      Analyze the interface and exit without making changes.
  -r, --rollback          Rollback changes from the last successful run.
  -s, --service           Apply optimizations and create a persistent systemd service.
  --dry-run               Show what would be done without applying any changes.
${BLUE}Default Behavior:${NC}
  If run with no options, it will apply optimizations for the current session only.
${BLUE}Examples:${NC}
  sudo ./${SCRIPT_NAME}             # Auto-detect and optimize for current session
  sudo ./${SCRIPT_NAME} -s          # Auto-detect, optimize, and make it persistent
  sudo ./${SCRIPT_NAME} -i enp1s0 -s # Optimize interface enp1s0 and make it persistent
  sudo ./${SCRIPT_NAME} -a          # Only analyze the current configuration
  sudo ./${SCRIPT_NAME} --dry-run   # See what changes would be made
  sudo ./${SCRIPT_NAME} -r          # Revert the last optimization run
HELP_EOF
}
main() {
    local analyze_only=false
    local rollback_mode=false
    local create_service=false
    local specified_interface=""
    # Comprehensive argument parsing
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help) show_usage; exit 0 ;;
            -v|--version) echo "${SCRIPT_NAME} version ${SCRIPT_VERSION}"; exit 0 ;;
            -i|--interface) specified_interface="$2"; shift 2 ;;
            -a|--analyze-only) analyze_only=true; shift ;;
            -r|--rollback) rollback_mode=true; shift ;;
            -s) create_service=true; shift ;;
            --dry-run) DRY_RUN=true; shift ;;
            *) error_exit "Unknown option: $1. Use -h for help." ;;
        esac
    done
    
    # --- Pre-flight checks ---
    check_root; create_lock; check_dependencies; detect_system_info;
    # --- Interface detection and validation ---
    if [[ -n "$specified_interface" ]]; then
        if validate_interface "$specified_interface"; then
            MAIN_INTERFACE="$specified_interface"
            log "INFO" "Using user-specified interface: ${GREEN}${MAIN_INTERFACE}${NC}"
        else
            error_exit "The specified interface '${specified_interface}' is not valid."
        fi
    else
        detect_main_interface
    fi
    
    # --- Main execution logic based on flags ---
    if [[ "$rollback_mode" == "true" ]]; then
        rollback_changes "$MAIN_INTERFACE"
    elif [[ "$analyze_only" == "true" ]]; then
        analyze_interface "$MAIN_INTERFACE"
        log "INFO" "Analysis complete. No changes were made."
    else
        # This is the main optimization path (including default, -s, and --dry-run)
        analyze_interface "$MAIN_INTERFACE"
        apply_optimizations "$MAIN_INTERFACE"
        save_rollback_state
        validate_optimizations "$MAIN_INTERFACE"
        
        if [[ "$create_service" == "true" ]]; then
            create_persistent_service "$MAIN_INTERFACE"
        fi
        if [[ "$DRY_RUN" == "true" ]]; then
             echo -e "\n${YELLOW}DRY RUN COMPLETE.${NC} No changes were made to the system."
        else
             echo -e "\n${GREEN}Optimization process for '${MAIN_INTERFACE}' is complete.${NC}"
        fi
    fi
    
    log "INFO" "Script execution finished."
}
#--- Script Entry Point ---
mkdir -p "$(dirname "$LOG_FILE")"
log "INFO" "--- Starting ${SCRIPT_NAME} v${SCRIPT_VERSION} ---"
main "$@"
SCRIPT_EOF
    # اعمال دسترسی اجرایی به فایل
    chmod +x /root/OptimizeNetwork.sh
    echo -e "${GREEN}Network optimization script created successfully!${NC}"
    
    # حلقه برای منوی بهینه‌سازی شبکه
    while true; do
        clear
        display_header "Optimization Network"
        echo -e "${WHITE}Please choose an option:${NC}"
        echo -e "  ${GREEN}1)${NC} Dry Run"
        echo -e "      Trial run without applying changes"
        echo -e "  ${GREEN}2)${NC} Quick Optimization"
        echo -e "      One-time optimization for current session"
        echo -e "  ${GREEN}3)${NC} Persistent Optimization"
        echo -e "      Optimize and make changes persistent"
        echo -e "  ${GREEN}4)${NC} Custom Interface"
        echo -e "      Optimize a specific network interface and make it persistent"
        echo -e "  ${GREEN}5)${NC} Analyze Interface"
        echo -e "      View current status of network interface"
        echo -e "  ${GREEN}6)${NC} Rollback Changes"
        echo -e "      Revert the last optimization changes"
        echo -e "  ${GREEN}0)${NC} Back to Main Menu"
        echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
        
        read -p "Enter your choice [0-6]: " choice
        
        case $choice in
            0)
                break
                ;;
            1)
                echo -e "${CYAN}Running dry run (trial without changes)...${NC}"
                sudo /root/OptimizeNetwork.sh --dry-run
                ;;
            2)
                echo -e "${CYAN}Running quick optimization (one-time)...${NC}"
                sudo /root/OptimizeNetwork.sh
                ;;
            3)
                echo -e "${CYAN}Running persistent optimization...${NC}"
                sudo /root/OptimizeNetwork.sh -s
                ;;
            4)
                read -p "Enter the network interface name (e.g. eth0, ens3): " interface_name
                if [ -n "$interface_name" ]; then
                    echo -e "${CYAN}Optimizing interface $interface_name with persistence...${NC}"
                    sudo /root/OptimizeNetwork.sh -i "$interface_name" -s
                else
                    echo -e "${RED}No interface name provided. Operation cancelled.${NC}"
                fi
                ;;
            5)
                echo -e "${CYAN}Analyzing network interface status...${NC}"
                sudo /root/OptimizeNetwork.sh -a
                ;;
            6)
                echo -e "${CYAN}Rolling back last optimization changes...${NC}"
                sudo /root/OptimizeNetwork.sh -r
                ;;
            *)
                echo -e "${RED}Invalid option. Please try again.${NC}"
                ;;
        esac
        
        # اگر گزینه 0 (بازگشت) انتخاب نشده باشد، منتظر بمانیم
        if [ "$choice" != "0" ]; then
            read -p $'\nPress Enter to continue...'
        fi
    done
}
# --- تابع آپدیت و نصب پیش‌نیازها ---
update_and_install_prerequisites() {
    clear
    display_header "Update upgrade and install prerequisites"
    
    # --- تابع اصلی برای آپدیت و نصب بسته‌ها ---
    update_and_install_packages() {
        # --- STEP 1: AUTOMATIC SYSTEM UPDATE & UPGRADE ---
        local update_cmd="DEBIAN_FRONTEND=noninteractive dpkg --force-confold --configure -a && DEBIAN_FRONTEND=noninteractive apt-get --fix-broken install -yq && apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get -yq -o Dpkg::Options::=\"--force-confdef\" -o Dpkg::Options::=\"--force-confold\" dist-upgrade"
        run_with_spinner "Repairing, Updating, and Upgrading System" "$update_cmd"
        
        # --- STEP 2: INTERACTIVE GROUPED DEPENDENCIES INSTALLATION ---
        _install_group_if_confirmed() {
            local group_title="$1"
            shift
            local deps_to_check=("$@")
            local missing_deps=()
            for dep in "${deps_to_check[@]}"; do
                if ! dpkg -s "$dep" >/dev/null 2>&1; then
                    missing_deps+=("$dep")
                fi
            done
            if [ ${#missing_deps[@]} -gt 0 ]; then
                echo -e "\n${WHITE}The '${group_title}' group requires the following packages:${NC} ${CYAN}${missing_deps[*]}${NC}"
                printf "${YELLOW}Do you want to install these packages? (y/n): ${NC}"
                read -e -r install_choice
                if [[ "$install_choice" =~ ^[yY]$ ]]; then
                    local install_cmd="DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends ${missing_deps[*]}"
                    run_with_spinner "Installing ${group_title}" "$install_cmd"
                fi
            else
                echo -e "\n${GREEN}✅ Packages for the '${group_title}' group are already installed.${NC}"
            fi
        }
        
        local core_deps=("curl" "wget" "net-tools" "dnsutils" "bc" "lsb-release" "uuid-runtime" "unzip" "git" "gnupg")
        local socat_dep=("socat")
        local security_deps=("fail2ban" "chkrootkit" "rkhunter" "lynis" "iptables-persistent" "xtables-addons-common" "geoip-database")
        local monitoring_deps=("htop" "btop" "ncdu" "iftop")
        local web_deps=("certbot")
        local advanced_deps=("mtr-tiny" "iperf3" "jq" "netcat-openbsd" "nmap" "fping" "python3" "python3-pip")
        
        _install_group_if_confirmed "CORE & ESSENTIAL TOOLS" "${core_deps[@]}"
        _install_group_if_confirmed "SOCAT (FOR NETWORK CONNECTIONS)" "${socat_dep[@]}"
        _install_group_if_confirmed "SECURITY & SCANNER TOOLS" "${security_deps[@]}"
        _install_group_if_confirmed "MONITORING TOOLS" "${monitoring_deps[@]}"
        _install_group_if_confirmed "WEB & SSL TOOLS" "${web_deps[@]}"
        _install_group_if_confirmed "ADVANCED NETWORK TOOLS" "${advanced_deps[@]}"
        
        echo -e "\n${GREEN}✅ Prerequisite check and installation process finished.${NC}"
    }
    
    # اجرای تابع اصلی
    update_and_install_packages
}
# --- تابع غیرفعال کردن IPv6 ---
disable_ipv6() {
    # حذف تمام خطوط مرتبط با IPv6 (با مقادیر 0 یا 1)
    sudo sed -i '/^# Disabling IPv6$/d' /etc/sysctl.conf
    sudo sed -i '/^# Enable IPv6$/d' /etc/sysctl.conf
    sudo sed -i '/^net.ipv6.conf.all.disable_ipv6 = [01]$/d' /etc/sysctl.conf
    sudo sed -i '/^net.ipv6.conf.default.disable_ipv6 = [01]$/d' /etc/sysctl.conf
    sudo sed -i '/^net.ipv6.conf.lo.disable_ipv6 = [01]$/d' /etc/sysctl.conf
    
    # اضافه کردن تنظیمات غیرفعال کردن IPv6
    sudo bash -c 'cat >> /etc/sysctl.conf <<EOL
# Disabling IPv6
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOL'
    
    # اعمال تنظیمات
    sudo sysctl -p > /dev/null 2>&1
    sudo systemctl daemon-reload > /dev/null 2>&1
}
# --- تابع فعال کردن IPv6 ---
enable_ipv6() {
    # بررسی وجود تنظیمات غیرفعال کردن IPv6 با مقدار 1
    if grep -q "^net.ipv6.conf.all.disable_ipv6 = 1" /etc/sysctl.conf && \
       grep -q "^net.ipv6.conf.default.disable_ipv6 = 1" /etc/sysctl.conf && \
       grep -q "^net.ipv6.conf.lo.disable_ipv6 = 1" /etc/sysctl.conf; then
        # حذف تمام خطوط مرتبط با IPv6 (با مقادیر 0 یا 1)
        sudo sed -i '/^# Disabling IPv6$/d' /etc/sysctl.conf
        sudo sed -i '/^# Enable IPv6$/d' /etc/sysctl.conf
        sudo sed -i '/^net.ipv6.conf.all.disable_ipv6 = [01]$/d' /etc/sysctl.conf
        sudo sed -i '/^net.ipv6.conf.default.disable_ipv6 = [01]$/d' /etc/sysctl.conf
        sudo sed -i '/^net.ipv6.conf.lo.disable_ipv6 = [01]$/d' /etc/sysctl.conf
        
        # اضافه کردن تنظیمات فعال کردن IPv6
        sudo bash -c 'cat >> /etc/sysctl.conf <<EOL
# Enable IPv6
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.default.disable_ipv6 = 0
net.ipv6.conf.lo.disable_ipv6 = 0
EOL'
    fi
    
    # اعمال تنظیمات
    sudo sysctl -p > /dev/null 2>&1
    sudo systemctl daemon-reload > /dev/null 2>&1
}
# --- تابع حذف تغییرات IPv6 ---
remove_ipv6_changes() {
    # حذف تمام خطوط مرتبط با IPv6 (با مقادیر 0 یا 1)
    sudo sed -i '/^# Disabling IPv6$/d' /etc/sysctl.conf
    sudo sed -i '/^# Enable IPv6$/d' /etc/sysctl.conf
    sudo sed -i '/^net.ipv6.conf.all.disable_ipv6 = [01]$/d' /etc/sysctl.conf
    sudo sed -i '/^net.ipv6.conf.default.disable_ipv6 = [01]$/d' /etc/sysctl.conf
    sudo sed -i '/^net.ipv6.conf.lo.disable_ipv6 = [01]$/d' /etc/sysctl.conf
    
    # اعمال تنظیمات
    sudo sysctl -p > /dev/null 2>&1
    sudo systemctl daemon-reload > /dev/null 2>&1
}
# --- تابع منوی IPv6 ---
ipv6_toggle_menu() {
    while true; do
        clear
        display_header "Enable/Disable IPv6"
        echo -e "${WHITE}Please choose an option:${NC}"
        echo -e "  ${GREEN}1)${NC} Disable IPv6"
        echo -e "  ${GREEN}2)${NC} Enable IPv6"
        echo -e "  ${GREEN}3)${NC} Remove changes IPv6"
        echo -e "  ${GREEN}0)${NC} Back to BBR Menu"
        echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
        
        read -p "Enter your choice [0-3]: " choice
        
        case $choice in
            0)
                break
                ;;
            1)
                run_with_spinner "Disabling IPv6" disable_ipv6
                echo -e "${GREEN}✅ IPv6 disabled successfully.${NC}"
                ;;
            2)
                run_with_spinner "Enabling IPv6" enable_ipv6
                echo -e "${GREEN}✅ IPv6 enabled successfully.${NC}"
                ;;
            3)
                run_with_spinner "Removing IPv6 changes" remove_ipv6_changes
                echo -e "${GREEN}✅ IPv6 changes removed successfully.${NC}"
                read -p "Do you want to reboot the system now for changes to take effect? (y/n): " reboot_choice
                if [[ "$reboot_choice" =~ ^[yY]$ ]]; then
                    echo -e "${CYAN}Rebooting system...${NC}"
                    sudo reboot
                else
                    echo -e "${YELLOW}System will not be rebooted. Changes will take effect after next reboot.${NC}"
                fi
                ;;
            *)
                echo -e "${RED}Invalid option. Please try again.${NC}"
                ;;
        esac
        
        # اگر گزینه 0 (بازگشت) انتخاب نشده باشد، منتظر بمانیم
        if [ "$choice" != "0" ]; then
            read -p $'\nPress Enter to continue...'
        fi
    done
}
# --- تابع غیرفعال کردن Ping (ICMP) ---
disable_ping_icmp() {
    # بررسی وجود تنظیمات قبلی
    if grep -q "^net.ipv4.icmp_echo_ignore_all = 1" /etc/sysctl.conf; then
        return 0
    fi
    
    # حذف تنظیمات قبلی اگر وجود داشته باشند
    sudo sed -i '/^# Disabling Ping (ICMP)$/,/^net.ipv4.icmp_echo_ignore_all = [01]$/d' /etc/sysctl.conf
    sudo sed -i '/^net.ipv4.icmp_echo_ignore_all = [01]$/d' /etc/sysctl.conf
    
    # اضافه کردن تنظیمات غیرفعال کردن Ping
    sudo bash -c 'cat >> /etc/sysctl.conf <<EOL
# Disabling Ping (ICMP)
net.ipv4.icmp_echo_ignore_all = 1
EOL'
    
    # اعمال تنظیمات
    sudo sysctl -p > /dev/null 2>&1
    sudo systemctl daemon-reload > /dev/null 2>&1
}
# --- تابع فعال کردن Ping (ICMP) ---
enable_ping_icmp() {
    # بررسی وجود تنظیمات غیرفعال کردن Ping
    if grep -q "^net.ipv4.icmp_echo_ignore_all = 1" /etc/sysctl.conf; then
        # تغییر مقدار به 0
        sudo sed -i 's/^net.ipv4.icmp_echo_ignore_all = 1/net.ipv4.icmp_echo_ignore_all = 0/' /etc/sysctl.conf
    fi
    
    # اعمال تنظیمات
    sudo sysctl -p > /dev/null 2>&1
    sudo systemctl daemon-reload > /dev/null 2>&1
}
# --- تابع حذف تغییرات Ping (ICMP) ---
delete_ping_icmp_changes() {
    # حذف بلوک تنظیمات
    sudo sed -i '/^# Disabling Ping (ICMP)$/,/^net.ipv4.icmp_echo_ignore_all = [01]$/d' /etc/sysctl.conf
    sudo sed -i '/^net.ipv4.icmp_echo_ignore_all = [01]$/d' /etc/sysctl.conf
    
    # اعمال تنظیمات
    sudo sysctl -p > /dev/null 2>&1
    sudo systemctl daemon-reload > /dev/null 2>&1
}
# --- تابع منوی Ping (ICMP) ---
ping_icmp_toggle_menu() {
    while true; do
        clear
        display_header "Enable/Disable Ping (ICMP)"
        echo -e "${WHITE}Please choose an option:${NC}"
        echo -e "  ${GREEN}1)${NC} Disable Ping (ICMP)"
        echo -e "  ${GREEN}2)${NC} Enable Ping (ICMP)"
        echo -e "  ${GREEN}3)${NC} Delete changes Ping (ICMP)"
        echo -e "  ${GREEN}0)${NC} Back to BBR Menu"
        echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
        
        read -p "Enter your choice [0-3]: " choice
        
        case $choice in
            0)
                break
                ;;
            1)
                run_with_spinner "Disabling Ping (ICMP)" disable_ping_icmp
                echo -e "${GREEN}✅ Ping (ICMP) disabled successfully.${NC}"
                ;;
            2)
                run_with_spinner "Enabling Ping (ICMP)" enable_ping_icmp
                echo -e "${GREEN}✅ Ping (ICMP) enabled successfully.${NC}"
                ;;
            3)
                run_with_spinner "Deleting Ping (ICMP) changes" delete_ping_icmp_changes
                echo -e "${GREEN}✅ Ping (ICMP) changes deleted successfully.${NC}"
                read -p "Do you want to reboot the system now for changes to take effect? (y/n): " reboot_choice
                if [[ "$reboot_choice" =~ ^[yY]$ ]]; then
                    echo -e "${CYAN}Rebooting system...${NC}"
                    sudo reboot
                else
                    echo -e "${YELLOW}System will not be rebooted. Changes will take effect after next reboot.${NC}"
                fi
                ;;
            *)
                echo -e "${RED}Invalid option. Please try again.${NC}"
                ;;
        esac
        
        # اگر گزینه 0 (بازگشت) انتخاب نشده باشد، منتظر بمانیم
        if [ "$choice" != "0" ]; then
            read -p $'\nPress Enter to continue...'
        fi
    done
}
# --- تابع اسکن پورت ---
port_scanning() {
    clear
    display_header "Port scanning"
    
    # بررسی نصب بودن nmap
    if ! command -v nmap &> /dev/null; then
        echo -e "${YELLOW}Nmap is not installed. Attempting to install it...${NC}"
        sudo apt-get update > /dev/null 2>&1
        sudo apt-get install -y nmap > /dev/null 2>&1
        
        # مجدداً بررسی نصب بودن nmap
        if ! command -v nmap &> /dev/null; then
            echo -e "${RED}Failed to install nmap. Please install it manually.${NC}"
            read -p $'\nPress Enter to return to the main menu...'
            return
        fi
        echo -e "${GREEN}Nmap installed successfully.${NC}"
    fi
    
    # دریافت آدرس IP یا دامین هدف
    echo -e "${WHITE}Please enter the target IP or domain:${NC}"
    echo -ne "${GREEN}Target:${NC} "
    read -e -r target
    
    # اعتبارسنجی ورودی
    if [[ -z "$target" ]]; then
        echo -e "${RED}No target specified.${NC}"
        read -p $'\nPress Enter to return to the main menu...'
        return
    fi
    
    # بررسی اینکه ورودی IP است یا دامین
    if [[ $target =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        # ورودی IP است
        IFS='.' read -r -a ip_parts <<< "$target"
        for part in "${ip_parts[@]}"; do
            if [[ $part -gt 255 ]]; then
                echo -e "${RED}The IP address entered is not valid.${NC}"
                read -p $'\nPress Enter to return to the main menu...'
                return
            fi
        done
    else
        # ورودی دامین است - بررسی اعتبار دامین با nslookup
        if ! nslookup "$target" > /dev/null 2>&1; then
            echo -e "${RED}The domain entered is not valid or cannot be resolved.${NC}"
            read -p $'\nPress Enter to return to the main menu...'
            return
        fi
    fi
    
    # نمایش پیام انتظار
    echo -e "\n${YELLOW}Please wait, scanning in progress...${NC}"
    echo -e "${CYAN}To cancel the scan and return to the menu, press CTRL+C.${NC}\n"
    
    # اجرای اسکن
    (
        trap '' INT
        echo -e "${BLUE}Running a full scan for all open ports on $target (This may take a long time)...${NC}"
        nmap -p- --open "$target"
    )
    
    echo -e "\n${GREEN}Nmap scan completed.${NC}"
}
# --- تابع سرعت تست ---
speed_test() {
    # تابع پاک کردن صفحه
    clear_screen() {
        clear
    }
    
    # تابع مکث و انتظار برای فشردن Enter توسط کاربر
    press_enter_to_continue() {
        echo ""
        read -p "$(echo -e "${GREEN}Press Enter to return to the menu...${NC}")"
    }
    
    # -------------------- توابع سرعت تست --------------------
    run_bench_method1() {
        echo -e "${CYAN}Running Bench Method 1...${NC}"
        wget -qO- bench.sh | bash
        press_enter_to_continue
    }
    
    run_bench_method2() {
        echo -e "${CYAN}Running Bench Method 2...${NC}"
        curl -Lso- bench.sh | bash
        press_enter_to_continue
    }
    
    run_iperf_client() {
        echo -e "${CYAN}Starting Iperf3 as client...${NC}"
        apt update > /dev/null 2>&1
        apt install -y iperf3 > /dev/null 2>&1
        ufw allow 5201 > /dev/null 2>&1
        echo ""
        read -p "What is the IP address of your target server? Enter Your Target IP: " server_ip
        echo -e "${YELLOW}--- Starting Download Test ---${NC}"
        iperf3 -c "${server_ip}" -i 1 -t 10 -P 20
        echo ""
        read -p "Download test finished. Press Enter to start the upload test..."
        echo -e "${YELLOW}--- Starting Upload Test ---${NC}"
        iperf3 -c "${server_ip}" -R -i 1 -t 10 -P 20
        press_enter_to_continue
    }
    
    run_iperf_server() {
        echo -e "${CYAN}Starting Iperf3 as server...${NC}"
        apt update > /dev/null 2>&1
        apt install -y iperf3 > /dev/null 2>&1
        ufw allow 5201 > /dev/null 2>&1
        echo -e "${GREEN}Iperf3 server is running. Use Ctrl+C to stop it when you are finished.${NC}"
        iperf3 -s
        press_enter_to_continue
    }
    
    show_iperf_menu() {
        while true; do
            clear
            display_header "Iperf3 Menu"
            echo -e "${WHITE}Please choose an option:${NC}"
            echo -e "  ${GREEN}1)${NC} Client (To test speed against a server)"
            echo -e "  ${GREEN}2)${NC} Server (To act as a target server)"
            echo -e "  ${GREEN}0)${NC} Back to Speed Test Menu"
            echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
            read -p "Enter your choice [0-2]: " iperf_choice
            case $iperf_choice in
                0) break ;;
                1) run_iperf_client ;;
                2) run_iperf_server ;;
                *) 
                    echo -e "${RED}Invalid option. Please try again.${NC}"
                    read -p $'\nPress Enter to continue...'
                    ;;
            esac
        done
    }
    
    run_speedtest_ookla() {
        echo -e "${CYAN}Downloading and running Ookla Speedtest...${NC}"
        
        # Download and extract
        wget -O ookla-speedtest.tgz https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-x86_64.tgz
        tar zxvf ookla-speedtest.tgz > /dev/null 2>&1
        # Get server number
        echo -e "${GREEN}Enter your ${YELLOW}Ookla server number${GREEN}. Or press Enter to let Speedtest choose automatically.${NC}"
        read -p "Server number: " server_num
        echo -e "${CYAN}Speed test starting, please wait...${NC}"
        if [[ -z "$server_num" ]]; then
            ./speedtest
        else
            ./speedtest -s "$server_num"
        fi
        # Cleanup
        echo -e "${CYAN}Cleaning up temporary files...${NC}"
        rm -f ookla-speedtest.tgz speedtest.md speedtest.5 speedtest
        
        press_enter_to_continue
    }
    
    # -------------------- منوی اصلی سرعت تست --------------------
    show_speed_test_menu() {
        clear
        display_header "Speed Test Menu"
        echo -e "${WHITE}Please choose an option:${NC}"
        echo -e "  ${YELLOW}1)${NC} Bench Method 1"
        echo -e "  ${YELLOW}2)${NC} Bench Method 2"
        echo -e "  ${YELLOW}3)${NC} Iperf3 (Between 2 Servers)"
        echo -e "  ${YELLOW}4)${NC} Speedtest Ookla"
        echo -e "  ${YELLOW}0)${NC} Back to Main Menu"
        echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
    }
    
    # -------------------- حلقه اصلی --------------------
    while true; do
        show_speed_test_menu
        read -p "Enter your choice [0-4]: " choice
        case $choice in
            0) break ;;
            1) run_bench_method1 ;;
            2) run_bench_method2 ;;
            3) show_iperf_menu ;;
            4) run_speedtest_ookla ;;
            *)
                echo -e "${RED}Invalid option. Please try again.${NC}"
                read -p $'\nPress Enter to continue...'
                ;;
        esac
    done
}
# --- تابع نصب BBR ---
install_bbr() {
    clear
    display_header "Installing BBR"
    
    # ایجاد نسخه پشتیبان از /etc/sysctl.conf
    sudo cp /etc/sysctl.conf /root/backup.sysctl.conf
    
    # پاک کردن محتوای /etc/sysctl.conf و نوشتن تنظیمات جدید
    sudo cat > /etc/sysctl.conf <<EOL
# Enable parameters
net.ipv4.tcp_ecn = 1
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_sack = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_mtu_probing = 1
# Dynamically adjusted buffer and backlog settings
net.core.netdev_max_backlog = 500000
net.core.somaxconn = 65535
net.core.rmem_default = 262144
net.core.rmem_max = 33554432
net.core.wmem_default = 262144
net.core.wmem_max = 33554432
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
# SYN Flood Protection
net.ipv4.tcp_max_syn_backlog = 8192
# Reduce the time it takes to free up connections in FIN_WAIT state
net.ipv4.tcp_fin_timeout = 30
# Enable IP forwarding for VPN relay servers
net.ipv4.ip_forward = 1
# New optimum
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_tw_reuse = 1
fs.file-max = 1000000
fs.nr_open = 1048576
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_timestamps = 1
fs.inotify.max_user_instances = 8192
# cake Sors Htaml  
net.core.default_qdisc = cake
net.ipv4.tcp_congestion_control = bbr
EOL
    
    # تنظیم /etc/profile
    if grep -q "ulimit -SHn 1000000" /etc/profile; then
        # حذف خط موجود و افزودن خط جدید در انتهای فایل
        sudo sed -i '/ulimit -SHn 1000000/d' /etc/profile
    fi
    echo "ulimit -SHn 1000000" | sudo tee -a /etc/profile > /dev/null
    
    # تنظیم /etc/security/limits.conf
    sudo cat > /etc/security/limits.conf <<EOL
*               soft    nofile           1000000
*               hard    nofile          1000000
EOL
    
    # اعمال تنظیمات
    run_with_spinner "Applying sysctl settings" "sudo sysctl -p"
    run_with_spinner "Reloading systemd daemon" "sudo systemctl daemon-reload"
    
    # پرسش برای ریبوت
    echo -e "${GREEN}✅ BBR installation completed successfully!${NC}"
    read -p "Do you want to reboot the system now for changes to take effect? (y/n): " reboot_choice
    if [[ "$reboot_choice" =~ ^[yY]$ ]]; then
        echo -e "${CYAN}Rebooting system...${NC}"
        sudo reboot
    else
        echo -e "${YELLOW}System will not be rebooted. Changes will take effect after next reboot.${NC}"
    fi
}
# --- تابع بازگردانی تنظیمات پیش‌فرض ---
revert_bbr_settings() {
    clear
    display_header "Reverting to default settings"
    
    # بررسی وجود فایل بکاپ
    if [ -f /root/backup.sysctl.conf ]; then
        # بازگردانی تنظیمات از بکاپ
        sudo cp /root/backup.sysctl.conf /etc/sysctl.conf
        
        # اعمال تنظیمات
        run_with_spinner "Applying sysctl settings" "sudo sysctl -p"
        run_with_spinner "Reloading systemd daemon" "sudo systemctl daemon-reload"
        
        echo -e "${GREEN}✅ Settings have been reverted to defaults successfully!${NC}"
        
        # پرسش برای ریبوت
        read -p "Do you want to reboot the system now for changes to take effect? (y/n): " reboot_choice
        if [[ "$reboot_choice" =~ ^[yY]$ ]]; then
            echo -e "${CYAN}Rebooting system...${NC}"
            sudo reboot
        else
            echo -e "${YELLOW}System will not be rebooted. Changes will take effect after next reboot.${NC}"
        fi
    else
        echo -e "${RED}❌ Backup file not found. Cannot revert to default settings.${NC}"
    fi
}
# --- تابع منوی BBR (به‌روز شده) ---
bbr_installation_menu() {
    while true; do
        clear
        display_header "BBR installation and network settings"
        echo -e "${WHITE}Please choose an option:${NC}"
        echo -e "  ${GREEN}1)${NC} Installing BBR"
        echo -e "  ${GREEN}2)${NC} Reverting to default settings"
        echo -e "  ${GREEN}3)${NC} Enable/Disable IPv6"
        echo -e "  ${GREEN}4)${NC} Enable/Disable Ping (ICMP)"
        echo -e "  ${GREEN}0)${NC} Back to Main Menu"
        echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
        
        read -p "Enter your choice [0-4]: " choice
        
        case $choice in
            0)
                break
                ;;
            1)
                install_bbr
                ;;
            2)
                revert_bbr_settings
                ;;
            3)
                ipv6_toggle_menu
                ;;
            4)
                ping_icmp_toggle_menu
                ;;
            *)
                echo -e "${RED}Invalid option. Please try again.${NC}"
                ;;
        esac
        
        # اگر گزینه 0 (بازگشت) انتخاب نشده باشد، منتظر بمانیم
        if [ "$choice" != "0" ]; then
            read -p $'\nPress Enter to continue...'
        fi
    done
}
# --- تابع تنظیمات MTU ---
mtu_settings_menu() {
    while true; do
        clear
        display_header "MTU Settings"
        echo -e "${WHITE}Please choose an option:${NC}"
        echo -e "  ${GREEN}1)${NC} Enable MTU"
        echo -e "  ${GREEN}2)${NC} Disable MTU"
        echo -e "  ${GREEN}0)${NC} Back to Main Menu"
        echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
        
        read -p "Enter your choice [0-2]: " choice
        
        case $choice in
            0)
                break
                ;;
            1)
                # Enable MTU
                while true; do
                    echo -ne "${WHITE}Enter your MTU value (default 1500):${NC} "
                    read mtu_value
                    
                    # اگر مقدار وارد نشود، از مقدار پیش‌فرض استفاده کن
                    if [[ -z "$mtu_value" ]]; then
                        mtu_value=1500
                        break
                    fi
                    
                    # بررسی اینکه مقدار عددی است و در محدوده 500 تا 1500 قرار دارد
                    if [[ "$mtu_value" =~ ^[0-9]+$ ]] && [[ "$mtu_value" -ge 500 ]] && [[ "$mtu_value" -le 1500 ]]; then
                        break
                    else
                        echo -e "${RED}Invalid MTU value. Please enter a number between 500 and 1500.${NC}"
                    fi
                done
                
                # تابع برای اعمال MTU
                apply_mtu() {
                    # اعمال MTU روی تمام اینترفیس‌ها (به جز lo)
                    for iface in $(ls /sys/class/net | grep -v lo); do 
                        sudo ip link set dev "$iface" mtu "$mtu_value"; 
                    done
                    
                    # حذف کرون‌جاب‌های قبلی مرتبط با MTU
                    crontab -l 2>/dev/null | grep -v '@reboot for iface in' | crontab -
                    
                    # افزودن کرون‌جاب جدید
                    (crontab -l 2>/dev/null; echo "@reboot for iface in \$(ls /sys/class/net | grep -v lo); do ip link set dev \"\$iface\" mtu $mtu_value; done") | crontab -
                }
                
                # اجرای تابع با انیمیشن
                run_with_spinner "Applying MTU settings" "apply_mtu"
                echo -e "${GREEN}✅ MTU settings applied successfully!${NC}"
                ;;
            2)
                # Disable MTU
                # تابع برای غیرفعال کردن MTU
                disable_mtu() {
                    # بازگردانی MTU به مقدار پیش‌فرض 1500
                    for iface in $(ls /sys/class/net | grep -v lo); do 
                        sudo ip link set dev "$iface" mtu 1500; 
                    done
                    
                    # حذف کرون‌جاب‌های مرتبط با MTU
                    crontab -l 2>/dev/null | grep -v '@reboot for iface in' | crontab -
                }
                
                # اجرای تابع با انیمیشن
                run_with_spinner "Disabling MTU settings" "disable_mtu"
                echo -e "${GREEN}✅ MTU settings disabled successfully!${NC}"
                
                # پرسش برای ریبوت
                read -p "Do you want to reboot the system now for changes to take effect? (y/n): " reboot_choice
                if [[ "$reboot_choice" =~ ^[yY]$ ]]; then
                    echo -e "${CYAN}Rebooting system...${NC}"
                    sudo reboot
                else
                    echo -e "${YELLOW}System will not be rebooted. Changes will take effect after next reboot.${NC}"
                fi
                ;;
            *)
                echo -e "${RED}Invalid option. Please try again.${NC}"
                ;;
        esac
        
        # اگر گزینه 0 (بازگشت) انتخاب نشده باشد، منتظر بمانیم
        if [ "$choice" != "0" ]; then
            read -p $'\nPress Enter to continue...'
        fi
    done
}
# --- تابع منوی اصلی ---
main_menu() {
    while true; do
        clear
        display_header "Main Menu"
        echo -e "${WHITE}Please choose an option:${NC}"
        echo -e "  ${YELLOW}1)${NC} Setting the best Mirror"
        echo -e "  ${YELLOW}2)${NC} Setting the best DNS"
        echo -e "  ${YELLOW}3)${NC} Optimization Network"
        echo -e "  ${YELLOW}4)${NC} Update upgrade and install prerequisites"
        echo -e "  ${YELLOW}5)${NC} BBR installation and network settings"
        echo -e "  ${YELLOW}6)${NC} Port scanning"
        echo -e "  ${YELLOW}7)${NC} Speed test"
        echo -e "  ${YELLOW}8)${NC} Set MTU"
        echo -e "  ${YELLOW}9)${NC} Exit"
        echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
        read -p "Enter your choice [1-9]: " choice
        case $choice in
            1) set_best_mirror ;;
            2) set_best_dns ;;
            3) setup_optimization_network ;;
            4) update_and_install_prerequisites ;;
            5) bbr_installation_menu ;;
            6) port_scanning ;;
            7) speed_test ;;
            8) mtu_settings_menu ;;
            9) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
            *) echo -e "${RED}Invalid option. Please try again.${NC}" ;;
        esac
        read -p $'\nPress Enter to return to the main menu...'
    done
}
# --- اجرای اسکریپت ---
check_dependencies
get_server_info
main_menu
