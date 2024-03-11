#!/bin/bash

echo "###########################################################"
echo "#                Spacewar Fastboot ROM Flasher            #"
echo "#                        開発/テスト者                     #"
echo "#  HELLBOY017、viralbanda、spike0en、PHATwalrus、arter97   #"
echo "#          [Nothing Phone (2) Telegram Dev Team]          #"
echo "#              [Nothing Phone (1)にも使用可能]             #"
echo "###########################################################"

##----------------------------------------------------------##
if [ ! -d platform-tools ]; then
    wget https://dl.google.com/android/repository/platform-tools-latest-linux.zip -O platform-tools-latest.zip
    unzip platform-tools-latest.zip
    rm platform-tools-latest.zip
fi

fastboot=platform-tools/fastboot

if [ ! -f $fastboot ] || [ ! -x $fastboot ]; then
    echo "Fastboot を実行できません。終了します。"
    exit 1
fi

# パーティション変数
boot_partitions="boot vendor_boot dtbo"
firmware_partitions="abl aop bluetooth cpucp devcfg dsp dtbo featenabler hyp imagefv keymaster modem multiimgoem qupfw shrm tz uefisecapp xbl xbl_config"
logical_partitions="system system_ext product vendor odm"
vbmeta_partitions="vbmeta_system"

function SetActiveSlot {
    $fastboot --set-active=a
    if [ $? -ne 0 ]; then
        echo "スロット A への切り替え中にエラーが発生しました。中止します。"
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
        read -p "$1 パーティションの消去に失敗しました。続行しますか？不確かな場合は N と入力してください。[Enter キーを押すと続行します] (Y/N)" FASTBOOT_ERROR
        handle_fastboot_error
    fi
}

function FlashImage {
    $fastboot flash $1 $2
    if [ $? -ne 0 ]; then
        read -p "$2 のフラッシュに失敗しました。続行しますか？不確かな場合は N と入力してください。[Enter キーを押すと続行します] (Y/N)" FASTBOOT_ERROR
        handle_fastboot_error
    fi
}

function DeleteLogicalPartition {
    $fastboot delete-logical-partition $1
    if [ $? -ne 0 ]; then
        read -p "$1 パーティションの削除に失敗しました。続行しますか？不確かな場合は N と入力してください。[Enter キーを押すと続行します] (Y/N)" FASTBOOT_ERROR
        handle_fastboot_error
    fi
}

function CreateLogicalPartition {
    $fastboot create-logical-partition $1 $2
    if [ $? -ne 0 ]; then
        read -p "$1 パーティションの作成に失敗しました。続行しますか？不確かな場合は N と入力してください。[Enter キーを押すと続行します] (Y/N)" FASTBOOT_ERROR
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
        echo "スーパーパーティションの消去に失敗しました。論理パーティションの削除および作成にフォールバックします。"
        ResizeLogicalPartition
    fi
}
##----------------------------------------------------------##

echo "##########################"
echo "# FASTBOOT デバイスの確認 #"
echo "##########################"
$fastboot devices

ACTIVE_SLOT=$($fastboot getvar current-slot 2>&1 | awk 'NR==1{print $2}')
if [ ! $ACTIVE_SLOT = "waiting" ] && [ ! $ACTIVE_SLOT = "a" ]; then
    echo "###############################"
    echo "# アクティブスロットを A に変更 #"
    echo "###############################"
    SetActiveSlot
fi

echo "######################"
echo "# データのフォーマット #"
echo "######################"
read -p "データを消去しますか？ (Y/N) " DATA_RESP
case $DATA_RESP in
    [yY] )
        echo '「このパーティションをフォーマットするつもりですか？」の警告は無視してください。'
        ErasePartition userdata
        ErasePartition metadata
        ;;
esac

echo "#################################"
echo "# ブートパーティションのフラッシュ #"
echo "#################################"
read -p "両方のスロットにイメージをフラッシュしますか？不確かな場合は N と入力してください。 (Y/N) " SLOT_RESP
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

echo "#######################"
echo "# FASTBOOTD への再起動 #"
echo "#######################"
$fastboot reboot fastboot
if [ $? -ne 0 ]; then
    echo "fastbootd への再起動中にエラーが発生しました。中止します。"
    exit 1
fi

echo "###########################"
echo "# ファームウェアのフラッシュ #"
echo "###########################"
for i in $firmware_partitions; do
    FlashImage "$SLOT $i" \ "$i.img"
done

echo "######################"
echo "# VBMETA のフラッシュ #"
echo "######################"
read -p "Android の検証ブートを無効にしますか？不確かな場合は N と入力してください。Y を選択するとブートローダーはロックできません。 (Y/N) " VBMETA_RESP
case $VBMETA_RESP in
    [yY] )
        FlashImage "$SLOT vbmeta --disable-verity --disable-verification" \ "vbmeta.img"
        ;;
    *)
        FlashImage "$SLOT vbmeta" \ "vbmeta.img"
        ;;
esac

echo "###############################"
echo "# 論理パーティションのフラッシュ #"
echo "###############################"
echo "論理パーティションイメージをフラッシュしますか？"
echo "カスタム ROM をインストールする場合は N と入力してください。"
read -p "不確かな場合は Y と入力してください。 (Y/N) " LOGICAL_RESP
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

echo "#######################################"
echo "# 他の VBMETA パーティションのフラッシュ #"
echo "#######################################"
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

echo "#########"
echo "# 再起動 #"
echo "#########"
read -p "システムに再起動しますか？不確かな場合は Y と入力してください。 (Y/N) " REBOOT_RESP
case $REBOOT_RESP in
    [yY] )
        $fastboot reboot
        ;;
esac

echo "########"
echo "# 完了 #"
echo "########"
echo "ストックファームウェアが復元されました。"
echo "必要に応じてブートローダーを再ロックできます（Android の検証ブートが無効の場合はオプションです）"
