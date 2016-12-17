#!/bin/bash

chkconfig httpd on
chkconfig mysqld on

echo "<?php phpinfo(); ?>" >> /var/www/html/index.php

service httpd restart