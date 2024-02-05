#!/bin/bash

echo "###########################################################"
echo "#                Spacewar Fastboot ROM Flasher            #"
echo "#                        �J��/�e�X�g��                         #"
echo "#  HELLBOY017, viralbanda, spike0en, PHATwalrus, arter97  #"
echo "#          [Nothing Phone (2) Telegram Dev Team]          #"
echo "#               [Nothing Phone (1)�ɂ��g�p�\]               #"
echo "###########################################################"

##----------------------------------------------------------##
if [ ! -d platform-tools ]; then
    wget https://dl.google.com/android/repository/platform-tools-latest-linux.zip -O platform-tools-latest.zip
    unzip platform-tools-latest.zip
    rm platform-tools-latest.zip
fi

fastboot=platform-tools/fastboot

if [ ! -f $fastboot ] || [ ! -x $fastboot ]; then
    echo "Fastboot �����s�ł��܂���B�I�����܂�"
    exit 1
fi

# �p�[�e�B�V�����ϐ�
boot_partitions="boot vendor_boot dtbo recovery"
firmware_partitions="abl aop aop_config bluetooth cpucp devcfg dsp featenabler hyp imagefv keymaster modem multiimgoem multiimgqti qupfw qweslicstore shrm tz uefi uefisecapp xbl xbl_config xbl_ramdump"
logical_partitions="system system_ext product vendor odm"
vbmeta_partitions="vbmeta_system vbmeta_vendor"

function SetActiveSlot {
    $fastboot --set-active=a
    if [ $? -ne 0 ]; then
        echo "�X���b�g A �ւ̐؂�ւ����ɃG���[���������܂����B���~���܂�"
        exit 1
    fi
}

function handle_fastboot_error {
    if [ ! $FASTBOOT_ERROR = "n" ] || [ ! $FASTBOOT_ERROR = "N" ] || [ ! $FASTBOOT_ERROR = "" ]; then
       exit 1
    fi  
}

function ErasePartition {
    $fastboot erase $1
    if [ $? -ne 0 ]; then
        read -p "$1 �p�[�e�B�V�����̏����Ɏ��s���܂����B���s���܂����H�s�m���ȏꍇ�� N �Ɠ��͂��Ă��������B[Enter �L�[�������Ƒ��s���܂�] (Y/N)" FASTBOOT_ERROR
        handle_fastboot_error
    fi
}

function FlashImage {
    $fastboot flash $1 $2
    if [ $? -ne 0 ]; then
        read -p "$2 �̃t���b�V���Ɏ��s���܂����B���s���܂����H�s�m���ȏꍇ�� N �Ɠ��͂��Ă��������B[Enter �L�[�������Ƒ��s���܂�] (Y/N)" FASTBOOT_ERROR
        handle_fastboot_error
    fi
}

function DeleteLogicalPartition {
    $fastboot delete-logical-partition $1
    if [ $? -ne 0 ]; then
        read -p "$1 �p�[�e�B�V�����̍폜�Ɏ��s���܂����B���s���܂����H�s�m���ȏꍇ�� N �Ɠ��͂��Ă��������B[Enter �L�[�������Ƒ��s���܂�] (Y/N)" FASTBOOT_ERROR
        handle_fastboot_error
    fi
}

function CreateLogicalPartition {
    $fastboot create-logical-partition $1 $2
    if [ $? -ne 0 ]; then
        read -p "$1 �p�[�e�B�V�����̍쐬�Ɏ��s���܂����B���s���܂����H�s�m���ȏꍇ�� N �Ɠ��͂��Ă��������B[Enter �L�[�������Ƒ��s���܂�] (Y/N)" FASTBOOT_ERROR
        handle_fastboot_error
    fi
}

function ResizeLogicalPartition {
    for i in $logical_partitions; do
        for s in a b; do 
            DeleteLogicalPartition "${i}_${s}-cow"
            DeleteLogicalPartition "${i}_${s}"
            CreateLogicalPartition "${i}_${s}" \ "1"
        done
    done
}

function WipeSuperPartition {
    $fastboot wipe-super super_empty.img
    if [ $? -ne 0 ]; then 
        echo "�X�[�p�[�p�[�e�B�V�����̏����Ɏ��s���܂����B�_���p�[�e�B�V�����̍폜����э쐬�Ƀt�H�[���o�b�N���܂�"
        ResizeLogicalPartition
    fi
}
##----------------------------------------------------------##

echo "#############################"
echo "#     FASTBOOT �f�o�C�X�̊m�F     #"
echo "#############################"
$fastboot devices

ACTIVE_SLOT=$($fastboot getvar current-slot 2>&1 | awk 'NR==1{print $2}')
if [ ! $ACTIVE_SLOT = "waiting" ] && [ ! $ACTIVE_SLOT = "a" ]; then
    echo "#############################"
    echo "#    �A�N�e�B�u�X���b�g�� A �ɕύX      #"
    echo "#############################"
    SetActiveSlot
fi

echo "###################"
echo "#    �f�[�^�̃t�H�[�}�b�g  #"
echo "###################"
read -p "�f�[�^���������܂����H (Y/N) " DATA_RESP
case $DATA_RESP in
    [yY] )
        echo '�u���̃p�[�e�B�V�������t�H�[�}�b�g�������ł����H�v�̌x���͖������Ă��������B'
        ErasePartition userdata
        ErasePartition metadata
        ;;
esac

echo "############################"
echo "#     �u�[�g�p�[�e�B�V�����̃t���b�V��    #"
echo "############################"
read -p "�����̃X���b�g�ɃC���[�W���t���b�V�����܂����H�s�m���ȏꍇ�� N �Ɠ��͂��Ă��������B (Y/N) " SLOT_RESP
case $SLOT_RESP in
    [yY] )
        SLOT="--slot=all"
        ;;
    *)
        SLOT="--slot=a"
        ;;
esac

if [ $SLOT = "--slot=all" ]; then
    for i in $boot_partitions; do
        for s in a b; do
            FlashImage "${i}_${s}" \ "$i.img"
        done
    done
else
    for i in $boot_partitions; do
        FlashImage "$i" \ "$i.img"
    done
fi

echo "##########################"             
echo "#    FASTBOOTD �ւ̍ċN��   #"       
echo "##########################"
$fastboot reboot fastboot
if [ $? -ne 0 ]; then
    echo "fastbootd �ւ̍ċN�����ɃG���[���������܂����B���~���܂�"
    exit 1
fi

echo "#####################"
echo "#   �t�@�[���E�F�A�̃t���b�V��   #"
echo "#####################"
for i in $firmware_partitions; do
    FlashImage "$SLOT $i" \ "$i.img"
done

echo "###################"
echo "#  VBMETA �̃t���b�V��  #"
echo "###################"
read -p "Android �̌��؃u�[�g�𖳌��ɂ��܂����H�s�m���ȏꍇ�� N �Ɠ��͂��Ă��������BY ��I������ƃu�[�g���[�_�[�̓��b�N�ł��܂���B (Y/N) " VBMETA_RESP
case $VBMETA_RESP in
    [yY] )
        FlashImage "$SLOT vbmeta --disable-verity --disable-verification" \ "vbmeta.img"
        ;;
    *)
        FlashImage "$SLOT vbmeta" \ "vbmeta.img"
        ;;
esac

echo "###############################"
echo "#       �_���p�[�e�B�V�����̃t���b�V��      #"
echo "###############################"
echo "�_���p�[�e�B�V�����C���[�W���t���b�V�����܂����H"
echo "�J�X�^�� ROM ���C���X�g�[������ꍇ�� N �Ɠ��͂��Ă��������B"
read -p "�s�m���ȏꍇ�� Y �Ɠ��͂��Ă��������B (Y/N) " LOGICAL_RESP
case $LOGICAL_RESP in
    [yY] )
        if [ ! -f super.img ]; then
            if [ -f super_empty.img ]; then
                WipeSuperPartition
            else
                ResizeLogicalPartition
            fi
            for i in $logical_partitions; do
                FlashImage "$i" \ "$i.img"
            done
        else
            FlashImage "super" \ "super.img"
        fi
        ;;
esac

echo "####################################"
echo "#      ���� VBMETA �p�[�e�B�V�����̃t���b�V��    #"
echo "####################################"
for i in $vbmeta_partitions; do
    case $VBMETA_RESP in
        [yY] )
            FlashImage "$i --disable-verity --disable-verification" \ "$i.img"
            ;;
        *)
            FlashImage "$i" \ "$i.img"
            ;;
    esac
done

echo "#############"
echo "#   �ċN��    #"
echo "#############"
read -p "�V�X�e���ɍċN�����܂����H�s�m���ȏꍇ�� Y �Ɠ��͂��Ă��������B (Y/N) " REBOOT_RESP
case $REBOOT_RESP in
    [yY] )
        $fastboot reboot
        ;;
esac

echo "########"
echo "#  ���� #"
echo "########"
echo "�X�g�b�N�t�@�[���E�F�A����������܂����B"
echo "�K�v�ɉ����ău�[�g���[�_�[���ă��b�N�ł��܂��iAndroid �̌��؃u�[�g�������̏ꍇ�̓I�v�V�����ł��j"