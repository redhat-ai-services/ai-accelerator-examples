#!/bin/bash
set -e

# check login
check_oc_login(){
  oc cluster-info | head -n1
  oc whoami || exit 1
  echo
}
