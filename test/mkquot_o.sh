#!/bin/sh
# $Id: mkquot_o.sh,v 6.2 2010/09/16 08:32:02 deraugla Exp $

head -n2 quot_o.ml
../meta/camlp5r -nolib -I ../meta ../etc/pa_mktest.cmo ../etc/pr_o.cmo -flag M -impl ../main/mLast.mli |
sed -e '1,/begin_stuff/d; /end_stuff/,$d'
