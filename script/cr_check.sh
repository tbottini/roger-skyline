#!/bin/bash

cr_past=$(cat /var/cr_save)
cr_now=$(cat /etc/crontab)
if [ "$cr_past" != "$cr_now" ]
then
	diff /var/cr_save /etc/crontab | mail -s "Crontab Changed" root
fi
echo "$cr_now" > cr_save