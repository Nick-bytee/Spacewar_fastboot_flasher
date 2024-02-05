@echo off
title Nothing Phone (1) Fastboot ROM Flasher (t.me/NothingPhone1)

echo ###########################################################
echo #                Pong Fastboot ROM Flasher                #
echo #                       開発/テスト者                          #
echo #  HELLBOY017、viralbanda、spike0en、PHATwalrus、arter97      #
echo #          [Nothing Phone (2) Telegram Dev Team]          #
echo #                [Nothing Phone (1)にも使用可能]              #
echo ###########################################################

cd %~dp0

if not exist platform-tools-latest (
    curl -L https://dl.google.com/android/repository/platform-tools-latest-windows.zip -o platform-tools-latest.zip
    Call :UnZipFile "%~dp0platform-tools-latest", "%~dp0platform-tools-latest.zip"
    del /f /q platform-tools-latest.zip
)

set fastboot=.\platform-tools-latest\platform-tools\fastboot.exe
if not exist %fastboot% (
    echo Fastbootを実行できません。中止します。
    pause
    exit
)

set boot_partitions=boot vendor_boot dtbo recovery
set firmware_partitions=abl aop aop_config bluetooth cpucp devcfg dsp featenabler hyp imagefv keymaster modem multiimgoem multiimgqti qupfw qweslicstore shrm tz uefi uefisecapp xbl xbl_config xbl_ramdump
set logical_partitions=system system_ext product vendor odm
set vbmeta_partitions=vbmeta_system vbmeta_vendor

echo #############################
echo #    FASTBOOTデバイスの確認       #
echo #############################
%fastboot% devices

%fastboot% getvar current-slot 2>&1 | find /c "current-slot: a" > tmpFile.txt
set /p active_slot= < tmpFile.txt
del /f /q tmpFile.txt
if %active_slot% equ 0 (
    echo #############################
    echo #      アクティブスロットをAに変更      #
    echo #############################
    call :SetActiveSlot
)

echo ###################
echo #   データのフォーマット    #
echo ###################
choice /m "データを消去しますか？"
if %errorlevel% equ 1 (
    echo 「このパーティションをフォーマットしますか？」の警告は無視してください。
    call :ErasePartition userdata
    call :ErasePartition metadata
)

echo ############################
echo #     ブートパーティションのフラッシュ     #
echo ############################
choice /m "両方のスロットにイメージをフラッシュしますか？ よく分からない場合はNと答えてください。"
if %errorlevel% equ 1 (
    set slot=all
) else (
    set slot=a
)

if %slot% equ all (
    for %%i in (%boot_partitions%) do (
        for %%s in (a b) do (
            call :FlashImage %%i_%%s, %%i.img
        )
    ) 
) else (
    for %%i in (%boot_partitions%) do (
        call :FlashImage %%i, %%i.img
    )
)

echo ##########################             
echo #    FASTBOOTDに再起動      #       
echo ##########################
%fastboot% reboot fastboot
if %errorlevel% neq 0 (
    echo fastbootdに再起動中にエラーが発生しました。中止します。
    pause
    exit
)

echo #####################
echo #   ファームウェアのフラッシュ   #
echo #####################
for %%i in (%firmware_partitions%) do (
    call :FlashImage "--slot=%slot% %%i", %%i.img
)

echo ###################
echo #  VBMETAのフラッシュ   #
echo ###################
set disable_avb=0
choice /m "Android Verified Bootを無効にしますか？ よく分からない場合はNと答えてください。Yを選択するとブートローダーがロックできなくなります。"
if %errorlevel% equ 1 (
    set disable_avb=1
    call :FlashImage "--slot=%slot% vbmeta --disable-verity --disable-verification", vbmeta.img
) else (
    call :FlashImage "--slot=%slot% vbmeta", vbmeta.img
)

echo ###############################
echo #      論理パーティションのフラッシュ       #
echo ###############################
echo 論理パーティションイメージをフラッシュしますか？
echo カスタムROMをインストールする場合はNと答えてください。
choice /m "よく分からない場合はYと答えてください。"
if %errorlevel% equ 1 (
    if not exist super.img (
        if exist super_empty.img (
            call :WipeSuperPartition
        ) else (
            call :ResizeLogicalPartition
        )
        for %%i in (%logical_partitions%) do (
            call :FlashImage %%i, %%i.img
        )
    ) else (
        call :FlashImage super, super.img
    )
)

echo ####################################
echo #      他のVBMETAパーティションのフラッシュ      #
echo ####################################
for %%i in (%vbmeta_partitions%) do (
    if %disable_avb% equ 1 (
        call :FlashImage "%%i --disable-verity --disable-verification", %%i.img
    ) else (
        call :FlashImage %%i, %%i.img
    )
)

echo #############
echo #   再起動    #
echo #############
choice /m "システムに再起動しますか？ よく分からない場合はYと答えてください。"
if %errorlevel% equ 1 (
    %fastboot% reboot
)

echo ########
echo #  完了 #
echo ########
echo Stock firmware restored.
echo 必要に応じてブートローダーを再ロックできます（Android Verified Bootが無効になっていない場合）。

pause
exit

:UnZipFile
set vbs="%temp%\_.vbs"
if exist %vbs% del /f /q %vbs%
>%vbs%  echo Set fso = CreateObject("Scripting.FileSystemObject")
>>%vbs% echo If NOT fso.FolderExists("%~1") Then
>>%vbs% echo fso.CreateFolder("%~1")
>>%vbs% echo End If
>>%vbs% echo set objShell = CreateObject("Shell.Application")
>>%vbs% echo set FilesInZip=objShell.NameSpace("%~2").items
>>%vbs% echo objShell.NameSpace("%~1").CopyHere(FilesInZip)
>>%vbs% echo Set fso = Nothing
>>%vbs% echo Set objShell = Nothing
cscript //nologo %vbs%
if exist %vbs% del /f /q %vbs%
exit /b

:ErasePartition
%fastboot% erase %~1
if %errorlevel% neq 0 (
    call :Choice "Erasing %~1 partition failed"
)
exit /b

:SetActiveSlot
%fastboot% --set-active=a
if %errorlevel% neq 0 (
    echo スロットAに切り替える際にエラーが発生しました。中止します。
    pause
    exit
)
exit /b

:WipeSuperPartition
%fastboot% wipe-super super_empty.img
if %errorlevel% neq 0 (
    echo スーパーパーティションの消去に失敗しました。論理パーティションの削除と作成にフォールバックします。
    call :ResizeLogicalPartition
)
exit /b

:ResizeLogicalPartition
for %%i in (%logical_partitions%) do (
    for %%s in (a b) do (
        call :DeleteLogicalPartition %%i_%%s-cow
        call :DeleteLogicalPartition %%i_%%s
        call :CreateLogicalPartition %%i_%%s, 1
    )
)
exit /b

:DeleteLogicalPartition
%fastboot% delete-logical-partition %~1
if %errorlevel% neq 0 (
    call :Choice "Deleting %~1 partition failed"
)
exit /b

:CreateLogicalPartition
%fastboot% create-logical-partition %~1 %~2
if %errorlevel% neq 0 (
    call :Choice "Creating %~1 partition failed"
)
exit /b

:FlashImage
%fastboot% flash %~1 %~2
if %errorlevel% neq 0 (
    call :Choice "Flashing %~2 failed"
)
exit /b

:Choice
choice /m "%~1 続行しますか？ よく分からない場合はNと答えてください。"
if %errorlevel% equ 2 (
    exit
)
exit /b
