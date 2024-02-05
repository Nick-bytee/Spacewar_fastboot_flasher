#!/bin/bash

echo "###########################################################"
echo "#                Pong Fastboot ROM Flasher                #"
echo "#                   Developed/Tested By                   #"
echo "#  HELLBOY017, viralbanda, spike0en, PHATwalrus, arter97  #"
echo "#          [Nothing Phone (2) Telegram Dev Team]          #"
echo "#              [Nothing Phone (1)にも使用可能]              #"
echo "###########################################################"

fastboot=bin/fastboot

if [ ! -f $fastboot ] || [ ! -x $fastboot ]; then
    echo "Fastboot cannot be executed, exiting"
    exit 1
fi

echo "#############################"
echo "#       スロットAに変更        #"
echo "#############################"
$fastboot --set-active=a

echo "###################"
echo "#   データの初期化   #"
echo "###################"
read -p "データを初期化しますか? (Y/N) " DATA_RESP
case $DATA_RESP in
    [yY] )
        echo '"Did you mean to format this partition?"という警告のメッセージは無視をしてください'
        $fastboot erase userdata
        $fastboot erase metadata
        ;;
esac

read -p "両方のスロットにFlashされたイメージが存在しますか? 不明の場合は「N」と入力。 (Y/N) " SLOT_RESP
case $SLOT_RESP in
    [yY] )
        SLOT="--slot=all"
        ;;
esac

echo "##########################"
echo "#  bootとrecoveryをFlash  #"
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
echo "#    FASTBOOTDで再起動     #"       
echo "##########################"
$fastboot reboot fastboot

echo "######################"
echo "# ファームウェアをFlash #"
echo "######################"
for i in abl aop aop_config bluetooth cpucp devcfg dsp featenabler hyp imagefv keymaster modem multiimgoem multiimgqti qupfw qweslicstore shrm tz uefi uefisecapp xbl xbl_config xbl_ramdump; do
    $fastboot flash $SLOT $i $i.img
done

echo "###################"
echo "#  vbmetaのFlash   #"
echo "###################"
read -p "AVBを無効化しますか? 不明な場合は「N」と入力、「Y」を入力するとブートローダーはロックできなくなります。 (Y/N) " VBMETA_RESP
case $VBMETA_RESP in
    [yY] )
        $fastboot flash $SLOT vbmeta --disable-verity --disable-verification vbmeta.img
        ;;
    *)
        $fastboot flash $SLOT vbmeta vbmeta.img
        ;;
esac

echo "logical partitionイメージをFlashしますか?"
echo "独自のlogical partitionを分散するカスタムROMをインストールしようとしている場合は、「N」を入力してください。"
read -p "よくわからない場合は「Y」と入力してください。 (Y/N) " LOGICAL_RESP
case $LOGICAL_RESP in
    [yY] )
        echo "###############################"
        echo "#   logical partitionのFlash   #"
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
echo "#  vbmeta system/vendorをFlash   #"
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
echo "#   再起動   #"
echo "#############"
read -p "システムを再起動しますか? よくわからない場合は「Y」と入力してください。 (Y/N) " REBOOT_RESP
case $REBOOT_RESP in
    [yY] )
        $fastboot reboot
        ;;
esac

echo "#########"
echo "#  完了  #"
echo "#########"
echo "Stock ROMの復元が完了しました。"
echo "AVBを無効化していない場合は、オプションでブートローダーの再ロックができるようになりました。"
