#!/bin/bash

trap exit ERR

function rm_noerror {
    rm -rf $1 || true
}

function populateContents {
    content_prefix=../../package_contents/linux/

    # eip
    # Ignored, shouldn't change too much

    # launcher
    rm -rf ${content_prefix}/launcher/*
    mkdir -p ${content_prefix}/launcher/apps/
    cp ../../leap_client_launcher/src/launcher.py ${content_prefix}/launcher/apps/
    cp ../../leap_client_launcher/build/src/launcher ${content_prefix}/launcher/
    mkdir ${content_prefix}/launcher/packages/
    touch ${content_prefix}/launcher/packages/.keep

    # leap_client
    rm_noerror ${content_prefix}/leap/*
    mkdir -p ${content_prefix}/leap/apps/
    cp -rf ../../leap_client/src/leap ${content_prefix}/leap/apps/

    # leap_pycommon
    rm_noerror ${content_prefix}/leap_pycommon/*
    mkdir -p ${content_prefix}/leap_pycommon/lib/
    cp -rf ../../leap_pycommon/src/leap ${content_prefix}/leap_pycommon/lib/

    # libBoost
    rm_noerror ${content_prefix}/libBoost/lib
    mkdir -p ${content_prefix}/libBoost/lib/
    cp /home/chiiph/Downloads/boost_1_53_0/stage/lib/libboost_filesystem-gcc46-mt-1_53.so.1.53.0 ${content_prefix}/libBoost/lib/
    cp /home/chiiph/Downloads/boost_1_53_0/stage/lib/libboost_python-gcc46-mt-1_53.so.1.53.0 ${content_prefix}/libBoost/lib/
    cp /home/chiiph/Downloads/boost_1_53_0/stage/lib/libboost_system-gcc46-mt-1_53.so.1.53.0 ${content_prefix}/libBoost/lib/

    # libOpenSSL
    rm_noerror ${content_prefix}/libOpenSSL/lib
    mkdir -p ${content_prefix}/libOpenSSL/lib
    cp ../../leap_client_launcher/build/LEAPClient/lib/lib{lzo,pkcs11}*.so* ${content_prefix}/libOpenSSL/lib/

    # libPySide
    rm_noerror ${content_prefix}/libPySide/lib
    mkdir -p ${content_prefix}/libPySide/lib/
    cp ../../leap_client_launcher/build/LEAPClient/lib/lib{pyside,shiboken}*.so* ${content_prefix}/libPySide/lib/

    # OpenSSL
    rm_noerror ${content_prefix}/OpenSSL/lib
    mkdir -p ${content_prefix}/OpenSSL/lib
    cp -r ../../leap_client_launcher/build/LEAPClient/lib/OpenSSL ${content_prefix}/OpenSSL/lib/

    # PyDeps
    rm_noerror ${content_prefix}/PyDeps/lib
    mkdir -p ${content_prefix}/PyDeps/lib
    cp -r ../../leap_client_launcher/build/LEAPClient/lib/* ${content_prefix}/PyDeps/lib/
    rm_noerror ${content_prefix}/PyDeps/lib/{libboost*,liblzo*,libpkcs*,libpyside*,libshiboken*,OpenSSL,PySide}

    # PySide
    rm_noerror ${content_prefix}/PySide/lib
    mkdir -p ${content_prefix}/PySide/lib
    cp -r ../../leap_client_launcher/build/LEAPClient/lib/PySide ${content_prefix}/PySide/lib/

    # thandy
    rm_noerror ${content_prefix}/thandy/apps
    mkdir -p ${content_prefix}/thandy/apps
    cp -r ../../thandy/lib/thandy ${content_prefix}/thandy/apps/
}

function createThpConfig {
    # $1 thp_config
    # $2 scripts
    PYTHONPATH=~/Code/leap/thandy/lib/ python ../../thandy/lib/thandy/ThpHelper.py \
        thpconfig \
        --thp_name=$1 \
        --version_list=${versions[$1]} \
        --scan=../../package_contents/linux/$1/ \
        --os=linux \
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
        ../../package_contents/linux/$1/ \
        $1/ \
        ../../package_scripts/linux/$1/
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
    packages=$(echo */*.txt)
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
    ["leap"]=""
    ["libBoost"]=""
    ["libOpenSSL"]=""
    ["libPySide"]=""
    ["OpenSSL"]=""
    ["PyDeps"]=""
    ["PySide"]=""
    ["thandy"]=""
)

long_desc=(
    ["eip"]=""
    ["launcher"]=""
    ["leap"]=""
    ["libBoost"]=""
    ["libOpenSSL"]=""
    ["libPySide"]=""
    ["OpenSSL"]=""
    ["PyDeps"]=""
    ["PySide"]=""
    ["thandy"]=""
)

versions=(
    ["eip"]=1,1
    ["launcher"]=1,1
    ["leap"]=1,1
    ["libBoost"]=1,1
    ["libOpenSSL"]=1,1
    ["libPySide"]=1,1
    ["OpenSSL"]=1,1
    ["PyDeps"]=1,1
    ["PySide"]=1,1
    ["thandy"]=1,1
)

versions_str=(
    ["eip"]="1.1"
    ["launcher"]="1.1"
    ["leap"]="1.1"
    ["libBoost"]="1.1"
    ["libOpenSSL"]="1.1"
    ["libPySide"]="1.1"
    ["OpenSSL"]="1.1"
    ["PyDeps"]="1.1"
    ["PySide"]="1.1"
    ["thandy"]="1.1"
)

scripts=(
    ["eip"]=""
    ["launcher"]="['executablelauncher.py',['postinst']]"
    ["leap"]=""
    ["libBoost"]=""
    ["libOpenSSL"]=""
    ["libPySide"]=""
    ["OpenSSL"]=""
    ["PyDeps"]=""
    ["PySide"]=""
    ["thandy"]=""
)

packages="eip launcher leap libBoost libOpenSSL libPySide OpenSSL PyDeps PySide thandy"
comma_packages=${packages// /,}

stty -echo
read -p "Password for Thandy: " passw; echo
stty echo

echo "Populating contents"
populateContents

echo "Cleaning all the pyc, and emacs backup files"
cleanAll

for i in ${packages}; do
    if [ -d $i ]; then
        echo "Creating thp config for $i"
        createThpConfig $i ${scripts[$i]}
        echo "Creating thp package for $i"
        createThp $i
        echo "Creating package config for $i"
        createPackageConfig $i
        echo "Making package..."
        makePackage mnz $i
    fi
done

createBundleConfig "LEAPClient-linux" "1,2" "/bundleinfo/LEAPClient/LEAPClient-1.2.txt" ${comma_packages}
makeBundle mnz LEAPClient
insertAll
timestamp