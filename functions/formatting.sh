#!/bin/bash

bold=$(tput bold)
normal=$(tput sgr0)

function bld {
  echo "${bold}$1${normal}"
}

function slugify {
  echo $1 | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g' | sed 's/[^a-z0-9-]//g'
}

nclr () { local j; for ((j = 0; j <= "${1:-1}"; j++ )); do tput cuu1; done; tput ed; }

function indent () {
    local string="$1"
    local num_spaces="$2"

    printf "%${num_spaces}s%s\n" '' "$string"
}