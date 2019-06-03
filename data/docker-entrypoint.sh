#!/bin/sh

set -e
set -u

###
### Default variables
###
DEF_DELIM_START='<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->'
DEF_DELIM_CLOSE='<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->'


###
### Environment variables
###

# Set delimiter
if ! env | grep -q '^DELIM_START='; then
	DELIM_START="${DEF_DELIM_START}"
fi
if ! env | grep -q '^DELIM_CLOSE='; then
	DELIM_CLOSE="${DEF_DELIM_CLOSE}"
fi


###
### Helper functions
###

# Returns all but the last argument as an array using a POSIX-compliant method
# for handling arrays.
# Credit: https://gist.github.com/akutz/7a39159bbbe9c299c79f1d2107ef1357
trim_last_arg() {
  _l="${#}" _i=0 _j="$((_l-1))" && while [ "${_i}" -lt "${_l}" ]; do
    if [ "${_i}" -lt "${_j}" ]; then
      printf '%s\n' "${1}" | sed "s/'/'\\\\''/g;1s/^/'/;\$s/\$/' \\\\/"
    fi
    shift; _i="$((_i+1))"
  done
  echo " "
}


###
### Arguments appended?
###
if [ "${#}" -ge "1" ]; then

	###
	### Custom replace operation
	###
	if [ "${1}" = "terraform-docs-replace" ]; then

		# Remove first argument "replace"
		shift;

		# Store and Remove last argument (filename)
		eval MY_FILE="\${$#}"			# store last argument
		args="$(trim_last_arg "${@}")"	# get all the args except the last arg
		eval "set -- ${args}"			# update the shell's arguments with the new value


		# Check if file exists
		if [ ! -f "${WORKDIR}/${MY_FILE}" ]; then
			>&2 echo "Error, ${MY_FILE} not found in: ${WORKDIR}/${MY_FILE}"
			exit 1
		fi
		# Check if starting delimiter exists in file
		if ! grep -Fq "${DELIM_START}" "${WORKDIR}/${MY_FILE}"; then
			>&2 echo "Error, Starting delimiter not found ${MY_FILE}: '${DELIM_START}'"
			exit 1
		fi
		# Check if closint delimiter exists in file
		if ! grep -Fq "${DELIM_CLOSE}" "${WORKDIR}/${MY_FILE}"; then
			>&2 echo "Error, Closing delimiter not found ${MY_FILE}: '${DELIM_CLOSE}'"
			exit 1
		fi

		# Get owner and permissions of current file
		UID="$(stat -c %u "${WORKDIR}/${MY_FILE}")"
		GID="$(stat -c %g "${WORKDIR}/${MY_FILE}")"
		PERM="$(stat -c %a "${WORKDIR}/${MY_FILE}")"

		# Get terraform-docs output
		>&2 echo "terraform-docs ${*} ${WORKDIR}/$(dirname ${MY_FILE})"
		DOCS="$(terraform-docs "${@}" "${WORKDIR}/$(dirname ${MY_FILE})")"

		# Create temporary README.md
		mkdir -p /tmp
		grep -B 100000000 -F "${DELIM_START}" "${WORKDIR}/${MY_FILE}" > /tmp/README.md
		printf "${DOCS}\n\n" >> /tmp/README.md
		grep -A 100000000 -F "${DELIM_CLOSE}" "${WORKDIR}/${MY_FILE}" >> /tmp/README.md

		# Adjust permissions of temporary file
		chown ${UID}:${GID} /tmp/README.md
		chmod ${PERM} /tmp/README.md

		# Overwrite existing file
		mv -f /tmp/README.md "${WORKDIR}/${MY_FILE}"
		exit 0

	###
	### terraform-docs command
	###
	elif [ "${1}" = "terraform-docs" ]; then
		exec "${@}"

	###
	### Unsupported command
	###
	else
		>&2 echo "Error, Unsupported command."
		>&2 echo "Usage: cytopia/terraform-docs terraform-docs <ARGS> ."
		>&2 echo "       cytopia/terraform-docs terraform-docs-replace <ARGS>"
		>&2 echo
		>&2 echo "terraform-docs           Output as expected from terraform-docs"
		>&2 echo "terraform-docs-replace   Same as above, but replaces directly inside README.md"
		>&2 echo "                         if DELIM_START and DELIM_CLOSE are found."
		exit 1

	fi

###
### No arguments appended
###
else
	exec terraform-docs --version
fi