#!/bin/bash

trap exit ERR

function rm_noerror {
    rm -rf $1 || true
}

function populateContents {
    content_prefix=../../package_contents/windows/

    # eip
    rm_noerror ${content_prefix}/eip*
    mkdir -p ${content_prefix}/eip-win/apps/eip
    cp -r ../../windows_binaries/openvpn/* ${content_prefix}/eip-win/apps/eip

    # launcher
    rm_noerror ${content_prefix}/launcher*
    mkdir -p ${content_prefix}/launcher-win/apps/
    cp ../../leap_client_launcher/src/launcher.py ${content_prefix}/launcher-win/apps/
    cp ../../windows_binaries/launcher/launcher.exe ${content_prefix}/launcher-win/
    mkdir ${content_prefix}/launcher-win/packages/
    touch ${content_prefix}/launcher-win/packages/.keep

    # leap_client (we use the same than in linux)
    # leap_pycommon (we use the same than in linux)

    # libBoost
    rm_noerror ${content_prefix}/libBoost*
    mkdir -p ${content_prefix}/libBoost-win/
    cp ../../windows_binaries/boost/* ${content_prefix}/libBoost-win/

    # libOpenSSL
    rm_noerror ${content_prefix}/libOpenSSL*
    mkdir -p ${content_prefix}/libOpenSSL-win/Lib/OpenSSL
    cp ../../windows_binaries/openssl/Lib/OpenSSL/* ${content_prefix}/libOpenSSL-win/Lib/OpenSSL/

    # libPySide
    rm_noerror ${content_prefix}/libPySide*
    mkdir -p ${content_prefix}/libPySide-win
    cp ../../windows_binaries/pyside/* ${content_prefix}/libPySide-win/

    # TODO: no need for two openssl packages here
    # OpenSSL
    rm_noerror ${content_prefix}/OpenSSL*
    mkdir -p ${content_prefix}/OpenSSL-win/Lib/OpenSSL
    cp -r ../../windows_binaries/pyopenssl/Lib/OpenSSL/* ${content_prefix}/OpenSSL-win/Lib/OpenSSL/

    # PyDeps
    rm_noerror ${content_prefix}/PyDeps*
    mkdir -p ${content_prefix}/PyDeps-win/Lib
    cp -r ../../windows_binaries/pydeps/Lib/* ${content_prefix}/PyDeps-win/Lib/
    rm_noerror ${content_prefix}/PyDeps-win/Lib/{OpenSSL,PySide}

    # PySide
    rm_noerror ${content_prefix}/PySide*
    mkdir -p ${content_prefix}/PySide-win/Lib
    cp -r ../../windows_binaries/pypyside/Lib/* ${content_prefix}/PySide-win/Lib/

    # thandy (we use the same as for linux)
}

function createThpConfig {
    # $1 thp_config
    # $2 scripts
    PYTHONPATH=~/Code/leap/thandy/lib/ python ../../thandy/lib/thandy/ThpHelper.py \
        thpconfig \
        --thp_name=$1 \
        --version_list=${versions[$1]} \
        --scan=../../package_contents/windows/$1/ \
        --os=win \
        --arch=x86 \
        --generate_file_list=1 \
        --scripts=$2

    mv $1*.{cfg,filelist} $1
}

function createThp {
    # $1 package name
    PYTHONPATH=~/Code/leap/thandy/lib/ python ../../thandy/lib/thandy/ThpCLI.py \
        makethppackage \
        $1/*_thp.cfg \
        ../../package_contents/windows/$1/ \
        $1/ \
        ../../package_scripts/windows/$1/
    cp $1/*.thp ../../repo/data/
}

function createPackageConfig {
    # $1 app_name
    PYTHONPATH=~/Code/leap/thandy/lib/ python ../../thandy/lib/thandy/ConfigCLI.py \
        packageconfig \
        --app_name=$1 \
        --version_list=${versions[$1]} \
        --location=/pkginfo/$1/$1-${versions_str[$1]}.txt \
        --short_desc=${short_desc[$1]} \
        --long_desc=${long_desc[$1]} \
        --dest=.
    mv $1-${versions_str[$1]}_package.cfg $1
}

function cleanAll {
    for i in $(find ../../package_contents/ | egrep 'py~$|pyc$|json~$'); do
        rm_noerror $i
    done

    rm -rf */*
    rm_noerror LEAPClient*
}

function createBundleConfig {
    # $1 bundle name
    # $2 version list
    # $3 location /bundleinfo/leap/leap-1.2.3.txt
    # $4 comma separated package names
    PYTHONPATH=~/Code/leap/thandy/lib/ python ../../thandy/lib/thandy/ConfigCLI.py \
        bundleconfig \
        --bundle_name=$1 \
        --version_list=$2 \
        --bundle_location=$3 \
        --os=lin \
        --arch=x86 \
        --short_gloss="" \
        --long_gloss="" \
        --pkg_names=$4
}

function makePackage {
    # $1 keyid
    # $2 package name
    package_config=$(echo $2/*_package.cfg)
    thp=$(echo $2/$2*.thp)
    PYTHONPATH=~/Code/leap/thandy/lib/ expect -c "spawn python ../../thandy/lib/thandy/SignerCLI.py \
        makepackage \
        --keyid=$1 \
        ${package_config} \
        ${thp}
        expect \"Passphrase:\" {send \"$passw\r\"; interact}"
    mv $2*.txt $2
}

function makeBundle {
    # $1 keyid
    # $2 bundle name
    bundle_config=$(echo $2*_bundle.cfg)
    packages=$(echo */*.txt)" "$(echo ../linux/{leap,thandy,leap_pycommon}/*.txt)
    PYTHONPATH=~/Code/leap/thandy/lib/ expect -c "spawn python ../../thandy/lib/thandy/SignerCLI.py \
        makebundle \
        --keyid=$1 \
        ${bundle_config} \
        ${packages}
        expect -nocase \"passphrase:\" {send \"$passw\r\"; interact}"
}

function insertAll {
    PYTHONPATH=~/Code/leap/thandy/lib/ python ../../thandy/lib/thandy/ServerCLI.py \
        insert \
        --repo=../../repo \
        */*.txt \
        *.txt
}

function timestamp {
    PYTHONPATH=~/Code/leap/thandy/lib/ python ../../thandy/lib/thandy/ServerCLI.py \
        timestamp \
        --repo=../../repo/
}

declare -A short_desc
declare -A long_desc
declare -A versions
declare -A versions_str
declare -A scripts

short_desc=(
    ["eip"]=""
    ["launcher"]=""
    ["libBoost"]=""
    ["libOpenSSL"]=""
    ["libPySide"]=""
    ["OpenSSL"]=""
    ["PyDeps"]=""
    ["PySide"]=""
)

long_desc=(
    ["eip-win"]=""
    ["launcher-win"]=""
    ["libBoost-win"]=""
    ["libOpenSSL-win"]=""
    ["libPySide-win"]=""
    ["OpenSSL-win"]=""
    ["PyDeps-win"]=""
    ["PySide-win"]=""
)

versions=(
    ["eip-win"]=1,2
    ["launcher-win"]=1,8
    ["libBoost-win"]=1,7
    ["libOpenSSL-win"]=1,2
    ["libPySide-win"]=1,2
    ["OpenSSL-win"]=1,2
    ["PyDeps-win"]=1,5
    ["PySide-win"]=1,2
)

versions_str=(
    ["eip-win"]="1.2"
    ["launcher-win"]="1.8"
    ["libBoost-win"]="1.7"
    ["libOpenSSL-win"]="1.2"
    ["libPySide-win"]="1.2"
    ["OpenSSL-win"]="1.2"
    ["PyDeps-win"]="1.5"
    ["PySide-win"]="1.2"
)

scripts=(
    ["eip-win"]=""
    ["launcher-win"]=""
    ["libBoost-win"]=""
    ["libOpenSSL-win"]=""
    ["libPySide-win"]=""
    ["OpenSSL-win"]=""
    ["PyDeps-win"]=""
    ["PySide-win"]=""
)

packages="eip-win launcher-win libBoost-win libOpenSSL-win libPySide-win OpenSSL-win PyDeps-win PySide-win"
comma_packages=${packages// /,}

stty -echo
read -p "Password for Thandy: " passw; echo
stty echo

echo "Populating contents"
populateContents

echo "Cleaning all the pyc, and emacs backup files"
cleanAll

for i in ${packages}; do
    mkdir $i || true
    if [ -d $i ]; then
        echo "Creating thp config for $i"
        createThpConfig $i ${scripts[$i]}
        echo "Creating thp package for $i"
        createThp $i
        echo "Creating package config for $i"
        createPackageConfig $i
        echo "Making package..."
        makePackage oy0 $i
    fi
done

final_comma_packages=${comma_packages}",leap,thandy,leap_pycommon"

createBundleConfig "LEAPClient-windows" "1,2" "/bundleinfo/LEAPClient-win/LEAPClient-win-1.2.txt" ${final_comma_packages}
makeBundle oy0 LEAPClient
insertAll
timestamp