<div align="center">

# Havij | اسکریپت جامع مدیریت سرور هویج 🥕

یک جعبه‌ابزار همه‌کاره برای مدیریت، بهینه‌سازی و افزایش امنیت سرورهای لینوکس (اوبونتو و دبیان)

[![GitHub Stars](https://img.shields.io/github/stars/aliakbar123as/Havij?style=for-the-badge&color=orange)](https://github.com/aliakbar123as/Havij/stargazers)
[![GitHub Forks](https://img.shields.io/github/forks/aliakbar123as/Havij?style=for-the-badge&color=blue)](https://github.com/aliakbar123as/Havij/network/members)
[![GitHub Issues](https://img.shields.io/github/issues/aliakbar123as/Havij?style=for-the-badge&color=red)](https://github.com/aliakbar123as/Havij/issues)
[![License](https://img.shields.io/github/license/aliakbar123as/Havij?style=for-the-badge&color=green)](https://github.com/aliakbar123as/Havij/blob/main/LICENSE)

</div>

---

## 📖 معرفی
**هویج** یک اسکریپت جامع و قدرتمند به زبان Bash است که برای ساده‌سازی فرآیندهای پیچیده مدیریت سرور طراحی شده. با استفاده از این ابزار، مدیران سرور می‌توانند تنها با چند کلیک، تنظیمات حیاتی شبکه را بهینه کرده، سرعت سرور را افزایش دهند و ابزارهای مورد نیاز خود را به سادگی نصب کنند.

---

## ✨ ویژگی‌های کلیدی

* **🚀 بهینه‌سازی خودکار میرور (APT):** به صورت هوشمند موقعیت سرور را تشخیص داده و سریع‌ترین میرور را از بین ده‌ها میرور ایرانی و خارجی برای افزایش سرعت `apt update` پیدا و تنظیم می‌کند.
* **🌐 تنظیم هوشمند DNS:** با تست سرعت ده‌ها سرویس‌دهنده DNS معتبر (داخلی و خارجی)، سریع‌ترین DNS را برای سرور شما پیدا و به صورت پایدار تنظیم می‌کند.
* **⚙️ بهینه‌سازی پیشرفته شبکه:** یک ماژول حرفه‌ای برای تیونینگ پارامترهای کارت شبکه با `ethtool`، همراه با قابلیت پشتیبان‌گیری، بازگردانی و پایدارسازی تنظیمات پس از ریبوت.
* **⚡️ نصب و بهینه‌سازی BBR:** جدیدترین الگوریتم کنترل ازدحام گوگل (BBR) را به همراه `cake` و مجموعه‌ای از تنظیمات بهینه `sysctl` برای دستیابی به حداکثر سرعت شبکه نصب می‌کند.
* **🔧 مدیریت آسان سرویس‌ها:**
    * فعال/غیرفعال کردن **IPv6**
    * فعال/غیرفعال کردن پاسخ به **Ping (ICMP)**
    * تنظیم دستی و پایدارسازی **MTU**
* **📊 ابزارهای تست و تحلیل:**
    * **تست سرعت (Speed Test):** مجموعه‌ای از ابزارهای تست سرعت معتبر مانند `iperf3` و `Ookla Speedtest`.
    * **اسکن پورت (Port Scan):** اسکن سریع پورت‌های باز روی سرور یا یک هدف مشخص با `nmap`.
* **📦 نصب‌کننده هوشمند پیش‌نیازها:** سیستم را آپدیت کرده و به شما اجازه می‌دهد تا گروه‌های مختلفی از ابزارهای ضروری (امنیتی، مانیتورینگ، شبکه و...) را به انتخاب خود نصب کنید.
* **🎨 رابط کاربری زیبا و رنگی:** تمام منوها دارای رابط کاربری خوانا، رنگی و همراه با انیمیشن انتظار برای تجربه کاربری بهتر هستند.

---

## 📥 نصب و اجرا

برای اجرا، کافیست دستور زیر را در ترمینال سرور خود (با دسترسی روت) وارد کنید:

```bash
wget -N --no-check-certificate [https://raw.githubusercontent.com/aliakbar123as/Havij/main/Havij.sh](https://raw.githubusercontent.com/aliakbar123as/Havij/main/Havij.sh) && bash Havij.sh
```

---

## 📸 نمایی از محیط اسکریپت

```ansi
[1;37mTelegram Channel:[0m @coming-soon
[1;37mTelegram ID:[0m      @sorshtaml
[1;93m═══════════════════════════════════════════[0m
[0;36mIP Address:[0m 192.168.1.10
[0;36mLocation:[0m   Iran (ir)
[0;36mDatacenter:[0m Asiatech
[1;93m═══════════════════════════════════════════[0m
[1;37mMain Menu[0m
[1;93m═══════════════════════════════════════════[0m
[1;37mPlease choose an option:[0m
  [1;93m1)[0m Setting the best Mirror
  [1;93m2)[0m Setting the best DNS
  [1;93m3)[0m Optimization Network
  [1;93m4)[0m Update upgrade and install prerequisites
  [1;93m5)[0m BBR installation and network settings
  [1;93m6)[0m Port scanning
  [1;93m7)[0m Speed test
  [1;93m8)[0m Set MTU
  [1;93m9)[0m Exit
[1;93m═══════════════════════════════════════════[0m
Enter your choice [1-9]: 
```

---

## 📜 مجوز (License)

این پروژه تحت مجوز MIT منتشر شده است. برای اطلاعات بیشتر فایل `LICENSE` را مطالعه کنید.

---
<div align="center">
با ❤️ ساخته شده برای جامعه لینوکس ایران
</div>
