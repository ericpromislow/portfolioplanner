#!/bin/bash

set -eux

EXTRA="a"
case $# in
	0) DATE="$(date +%F)" ;;
	1) DATE="$1" ; shift ;;
	*) DATE="$1" ; EXTRA="$2" ; shift ; shift ;;
esac

rm -f tmp/totals.ods

ruby bin/investin.rb -d "$DATE" -n 6 -s "tmp/full-summary-${DATE}${EXTRA}.ods" "$@"
