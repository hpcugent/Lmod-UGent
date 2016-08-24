#!/usr/bin/env groovy

def RPMLINT_VERSION = "1.9"

node {
    stage 'Checkout'
    checkout scm
    sh "git clean -fxd"

    stage 'rpmlint'
    sh "wget -q https://github.com/rpm-software-management/rpmlint/archive/rpmlint-${RPMLINT_VERSION}.tar.gz"
    sh "tar -xzf rpmlint-${RPMLINT_VERSION}.tar.gz"
    env.PATH = "${pwd()}/rpmlint-rpmlint-${RPMLINT_VERSION}:${env.PATH}"
    sh "rpmlint Lmod-UGent.spec"
}
