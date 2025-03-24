# Commands to customize the script.

rm wicens.sh
cp wicens.sh.orig wicens.sh
sed -i "s/script_version='4.10'/script_version='4.11'/" wicens.sh
sed -i 's/written by maverickcdn/written by maverickcdn bharat/' wicens.sh
sed -i -E 's|^script_git_src=.*|script_git_src='\''https://raw.githubusercontent.com/dineshgyl/wicens/master/'\'' #\0|' wicens.sh
sed -i -E 's|^(mail_log=.*wicens_email\.log.*)|mail_log='\''/tmp/wicens_email.log'\''            # log file for sendmail/curl #\1|' wicens.sh

sed -i 's|\*/${cron_check_freq} \* \* \* \*|0 9 */${cron_check_freq} * *|' wicens.sh
sed -i '/cron_check_freq/ {s/\<mins\>/days/g; s/\<minutes\>/days/g}' wicens.sh
diff -U 0 wicens.sh.orig wicens.sh
