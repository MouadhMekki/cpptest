#! /bin/bash
# Copyright (C) 2017 Sebastian Pipping
# Licensed under GNU LGPL v2.1 or later

set -e


# Static config
version_old=1.1.2  # .. to compare against
version_new=$(git describe --tags)
prefix_old=cpptest-${version_old}-git
abi_old=abi-${version_old}.xml
abi_new=abi-${version_new}.xml

# Dynamic config
: ${ABI_CHECKER_OPTIONS:=-report-format xml -stdout}


make_descriptor_xml() {
	local version="$1"
	local prefix="$2"

	cat <<-EOF
		<version>
			${version}
		</version>

		<headers>
			${prefix}config/config.h
			${prefix}src/cpptest-assert.h
			${prefix}src/cpptest-collectoroutput.h
			${prefix}src/cpptest-compileroutput.h
			${prefix}src/cpptest.h
			${prefix}src/cpptest-htmloutput.h
			${prefix}src/cpptest-output.h
			${prefix}src/cpptest-source.h
			${prefix}src/cpptest-suite.h
			${prefix}src/cpptest-textoutput.h
			${prefix}src/cpptest-time.h
			${prefix}src/missing.h
			${prefix}src/utils.h
			${prefix}win/winconfig.h
		</headers>

		<libs>
			${prefix}src/.libs/libcpptest.so
		</libs>
	EOF
}


ensure_built() {
	local prefix="$1"
	[[ -f ${prefix}/configure ]] || ( cd ${prefix} && ./autogen.sh )
	[[ -f ${prefix}/Makefile ]] || ( cd ${prefix} && ./configure )
	[[ -f ${prefix}/src/.libs/libcpptest.so ]] || ( cd ${prefix} && make )
}


# Create old version binary
[[ -f ${prefix_old}.tar.gz ]] || git archive --format=tar.gz \
		--prefix=${prefix_old}/ --output=${prefix_old}.tar.gz ${version_old}
[[ -d ${prefix_old} ]] || tar xf ${prefix_old}.tar.gz
fgrep -q /bin/bash ${prefix_old}/autogen.sh || {
    git show ee3f55820a9afd332f4e3fb23971686c164e045b \
            | patch ${prefix_old}/autogen.sh
}
fgrep -q AC_CONFIG_MACRO_DIR ${prefix_old}/configure.ac || {
    git show a087c579808ffe9e4e13e1ca9ab58a13b7913916 \
            | patch ${prefix_old}/configure.ac
}
ensure_built ${prefix_old}


# Create new version binary
ensure_built .


# Run ABI checker
make_descriptor_xml ${version_old} ${prefix_old}/ > ${abi_old}
make_descriptor_xml ${version_new} '' > ${abi_new}
PS4='# '
set -x
abi-compliance-checker -d1 ${abi_old} -d2 ${abi_new} -l libcpptest.so \
		${ABI_CHECKER_OPTIONS}
