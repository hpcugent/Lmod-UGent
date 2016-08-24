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

    stage 'luacheck SitePackage'
    sh "mkdir luatree"
    sh "luarocks --tree=${pwd()}/luatree install luacheck"
    env.PATH = "${pwd()}/luatree/bin:${env.PATH}"
    env.LUA_PATH = "${pwd()}/luatree/share/lua/5.1/?.lua;${pwd()}/luatree/share/lua/5.1/?/init.lua;;"
    env.LUA_CPATH = "${pwd()}/luatree/lib/lua/5.1/?.so;;"
    sh "luacheck SitePackage.lua"
}
