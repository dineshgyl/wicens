# Commands to customize the script.

rm wicens.sh
cp wicens.sh.orig wicens.sh
sed -i "s/script_version='4.10'/script_version='4.11'/" wicens.sh
sed -i 's/written by maverickcdn/written by maverickcdn bharat/' wicens.sh
sed -i -E 's|^script_git_src=.*|script_git_src='\''https://raw.githubusercontent.com/dineshgyl/wicens/master/'\'' #\0|' wicens.sh
sed -i -E 's|^(mail_log=.*wicens_email\.log.*)|mail_log='\''/tmp/wicens_email.log'\''            # log file for sendmail/curl #\1|' wicens.sh

sed -i 's|\*/${cron_check_freq} \* \* \* \*|0 9 */${cron_check_freq} * *|' wicens.sh
sed -i 's/\(${cron_check_freq}\)m/\1d/g' wicens.sh
sed -i '/cron_check_freq/ {s/\<mins\>/days/g; s/\<minutes\>/days/g}' wicens.sh
diff -U 0 wicens.sh.orig wicens.sh


New Version: 4.11

cd /tmp
curl -fsL --retry 2 --retry-delay 3 --connect-timeout 3 https://raw.githubusercontent.com/maverickcdn/wicens/master/wicens.sh > wicens.sh
cp wicens.sh wicens.sh.orig

sed -i 's/written by maverickcdn/written by maverickcdn bharat/' wicens.sh
sed -i -E 's|^script_git_src=.*|script_git_src='\''https://raw.githubusercontent.com/dineshgyl/wicens/master/'\'' #\0|' wicens.sh
sed -i -E 's|^(mail_log=.*wicens_email\.log.*)|mail_log='\''/tmp/wicens_email.log'\''            # log file for sendmail/curl #\1|' wicens.sh
sed -i 's/cron_check_freq=11/cron_check_freq=9/g' wicens.sh
sed -i 's/default:11/default:9/g' wicens.sh
sed -i 's/cron_option=1/cron_option=0/g' wicens.sh
sed -i 's/script_log=1/script_log=0/g' wicens.sh
sed -i 's/\(${cron_check_freq}\)m/\1d/g' wicens.sh
sed -i '/cron_check_freq/ {s/\<mins\>/days/g; s/\<minutes\>/days/g}' wicens.sh
sed -i 's|\(cron_string=\).*|\1\\"0 9 */\\${cron_check_freq} * * $script_name_full cron\\""|' wicens.sh

diff -U 0 wicens.sh.orig wicens.sh
