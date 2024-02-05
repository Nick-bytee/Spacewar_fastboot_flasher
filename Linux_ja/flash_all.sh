#!/bin/bash

echo "###########################################################"
echo "#                Pong Fastboot ROM Flasher                #"
echo "#                   Developed/Tested By                   #"
echo "#  HELLBOY017, viralbanda, spike0en, PHATwalrus, arter97  #"
echo "#          [Nothing Phone (2) Telegram Dev Team]          #"
echo "#              [Nothing Phone (1)�ɂ��g�p�\]              #"
echo "###########################################################"

fastboot=bin/fastboot

if [ ! -f $fastboot ] || [ ! -x $fastboot ]; then
    echo "Fastboot cannot be executed, exiting"
    exit 1
fi

echo "#############################"
echo "#       �X���b�gA�ɕύX        #"
echo "#############################"
$fastboot --set-active=a

echo "###################"
echo "#   �f�[�^�̏�����   #"
echo "###################"
read -p "�f�[�^�����������܂���? (Y/N) " DATA_RESP
case $DATA_RESP in
    [yY] )
        echo '"Did you mean to format this partition?"�Ƃ����x���̃��b�Z�[�W�͖��������Ă�������'
        $fastboot erase userdata
        $fastboot erase metadata
        ;;
esac

read -p "�����̃X���b�g��Flash���ꂽ�C���[�W�����݂��܂���? �s���̏ꍇ�́uN�v�Ɠ��́B (Y/N) " SLOT_RESP
case $SLOT_RESP in
    [yY] )
        SLOT="--slot=all"
        ;;
esac

echo "##########################"
echo "#  boot��recovery��Flash  #"
echo "##########################"
for i in boot vendor_boot dtbo recovery; do
    if [ $SLOT = "--slot=all" ]; then
        for s in a b; do
            $fastboot flash ${i}_${s} $i.img
        done
    else
        $fastboot flash $i $i.img
    fi
done

echo "##########################"             
echo "#    FASTBOOTD�ōċN��     #"       
echo "##########################"
$fastboot reboot fastboot

echo "######################"
echo "# �t�@�[���E�F�A��Flash #"
echo "######################"
for i in abl aop aop_config bluetooth cpucp devcfg dsp featenabler hyp imagefv keymaster modem multiimgoem multiimgqti qupfw qweslicstore shrm tz uefi uefisecapp xbl xbl_config xbl_ramdump; do
    $fastboot flash $SLOT $i $i.img
done

echo "###################"
echo "#  vbmeta��Flash   #"
echo "###################"
read -p "AVB�𖳌������܂���? �s���ȏꍇ�́uN�v�Ɠ��́A�uY�v����͂���ƃu�[�g���[�_�[�̓��b�N�ł��Ȃ��Ȃ�܂��B (Y/N) " VBMETA_RESP
case $VBMETA_RESP in
    [yY] )
        $fastboot flash $SLOT vbmeta --disable-verity --disable-verification vbmeta.img
        ;;
    *)
        $fastboot flash $SLOT vbmeta vbmeta.img
        ;;
esac

echo "logical partition�C���[�W��Flash���܂���?"
echo "�Ǝ���logical partition�𕪎U����J�X�^��ROM���C���X�g�[�����悤�Ƃ��Ă���ꍇ�́A�uN�v����͂��Ă��������B"
read -p "�悭�킩��Ȃ��ꍇ�́uY�v�Ɠ��͂��Ă��������B (Y/N) " LOGICAL_RESP
case $LOGICAL_RESP in
    [yY] )
        echo "###############################"
        echo "#   logical partition��Flash   #"
        echo "###############################"
        for i in system system_ext product vendor odm; do
            for s in a b; do
                $fastboot delete-logical-partition ${i}_${s}-cow
                $fastboot delete-logical-partition ${i}_${s}
                $fastboot create-logical-partition ${i}_${s} 1
            done

            $fastboot flash $i $i.img
        done
        ;;
esac

echo "#################################"
echo "#  vbmeta system/vendor��Flash   #"
echo "#################################"
for i in vbmeta_system vbmeta_vendor; do
    case $VBMETA_RESP in
        [yY] )
            $fastboot flash $i --disable-verity --disable-verification $i.img
            ;;
        *)
            $fastboot flash $i $i.img
            ;;
    esac
done

echo "#############"
echo "#   �ċN��   #"
echo "#############"
read -p "�V�X�e�����ċN�����܂���? �悭�킩��Ȃ��ꍇ�́uY�v�Ɠ��͂��Ă��������B (Y/N) " REBOOT_RESP
case $REBOOT_RESP in
    [yY] )
        $fastboot reboot
        ;;
esac

echo "#########"
echo "#  ����  #"
echo "#########"
echo "Stock ROM�̕������������܂����B"
echo "AVB�𖳌������Ă��Ȃ��ꍇ�́A�I�v�V�����Ńu�[�g���[�_�[�̍ă��b�N���ł���悤�ɂȂ�܂����B"
