#!/bin/bash
# mkpage.sh name arg1 arg2 ... -> build/web/t_name.html (test only, never deployed)
n=$1; shift; a="\"--\","
for x in "$@"; do a="$a\"$x\","; done; a="${a%,}"
sed "s/\"args\":\[\]/\"args\":[$a]/" build/web/index.html > build/web/t_$n.html
