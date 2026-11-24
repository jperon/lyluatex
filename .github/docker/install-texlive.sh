#!/bin/sh
# Install TeX Live into /opt/texlive with the packages given as arguments.
#
# mirror.ctan.org sends every request to a random mirror, and now and then
# that mirror is broken (bad certificate) or out of date (checksum errors,
# which tlmgr reports but still exits 0 on). So check tlmgr's output too, and
# on any failure start again from scratch: the next attempt gets another
# mirror.

repository=$1
shift

attempt() {
    rm -rf /opt/texlive /tmp/install-tl-* /tmp/tl.out
    curl -fsSL "$repository/install-tl-unx.tar.gz" | tar -xz -C /tmp || return 1
    /tmp/install-tl-*/install-tl --profile=/tmp/texlive.profile \
        --location "$repository" > /tmp/tl.out 2>&1
    status=$?
    if [ $status -eq 0 ]; then
        tlmgr install "$@" >> /tmp/tl.out 2>&1
        status=$?
    fi
    grep -E 'Loading|did not succeed|checksums differ|could not' /tmp/tl.out
    [ $status -eq 0 ] && ! grep -qE 'did not succeed|checksums differ' /tmp/tl.out
}

for i in 1 2 3 4 5; do
    if attempt "$@"; then
        rm -rf /tmp/install-tl-* /tmp/tl.out
        exit 0
    fi
    echo "TeX Live attempt $i failed, retrying with another mirror"
    sleep 5
done
cat /tmp/tl.out
exit 1
