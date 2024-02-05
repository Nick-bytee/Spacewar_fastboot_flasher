@echo off
title Nothing Phone (1) Fastboot ROM Flasher (t.me/NothingPhone1)

echo ###########################################################
echo #                Pong Fastboot ROM Flasher                #
echo #                   Developed/Tested By                   #
echo #  HELLBOY017, viralbanda, spike0en, PHATwalrus, arter97  #
echo #          [Nothing Phone (2) Telegram Dev Team]          #
echo #              [Nothing Phone (1)�ɂ��g�p�\]            #
echo ###########################################################

cd %~dp0

if not exist platform-tools-latest (
    curl -L https://dl.google.com/android/repository/platform-tools-latest-windows.zip -o platform-tools-latest.zip
    Call :UnZipFile "%~dp0platform-tools-latest", "%~dp0platform-tools-latest.zip"
    del /f /q platform-tools-latest.zip
)

set fastboot=.\platform-tools-latest\platform-tools\fastboot.exe
if not exist %fastboot% (
    echo Fastboot cannot be executed. Aborting
    pause
    exit
)

echo #############################
echo #  FASTBOOT�f�o�C�X�̊m�F   #
echo #############################
%fastboot% devices

%fastboot% getvar current-slot 2>&1 | find /c "current-slot: a" > tmpFile.txt
set /p active_slot= < tmpFile.txt
del /f /q tmpFile.txt
if %active_slot% equ 0 (
    echo #############################
    echo #      �X���b�gA�ɕύX      #
    echo #############################
    call :SetActiveSlot
)

echo ####################
echo #  �f�[�^�̏�����  #
echo ####################
choice /m "�f�[�^�����������܂���?"
if %errorlevel% equ 1 (
    echo "Did you mean to format this partition?"�Ƃ����x���̃��b�Z�[�W�͖��������Ă�������
    call :ErasePartition userdata
    call :ErasePartition metadata
)

echo ###########################
echo #  boot��recovery��Flash  #
echo ###########################
choice /m "�����̃X���b�g��Flash���ꂽ�C���[�W�����݂��܂���? �s���̏ꍇ�́uN�v�Ɠ��́B"
if %errorlevel% equ 1 (
    set slot=all
) else (
    set slot=a
)

for %%i in (boot vendor_boot dtbo recovery) do (
    if %slot% equ all (
        for %%s in (a b) do (
            call :FlashImage %%i_%%s, %%i.img
        )
    ) else (
        call :FlashImage %%i, %%i.img
    )
)

echo ##########################             
echo #   FASTBOOTD�ōċN��    #       
echo ##########################
%fastboot% reboot fastboot
if %errorlevel% neq 0 (
    echo fastoot�̍ċN�����ɃG���[���������܂����B���~�����܂��B
    pause
    exit
)

echo #########################
echo # �t�@�[���E�F�A��Flash #
echo #########################
for %%i in (abl aop aop_config bluetooth cpucp devcfg dsp featenabler hyp imagefv keymaster modem multiimgoem multiimgqti qupfw qweslicstore shrm tz uefi uefisecapp xbl xbl_config xbl_ramdump) do (
    call :FlashImage "--slot=%slot% %%i", %%i.img
)

echo ###################
echo #  vbmeta��Flash  #
echo ###################
set disable_avb=0
choice /m "AVB�𖳌������܂���? �s���ȏꍇ�́uN�v�Ɠ��́A�uY�v����͂���ƃu�[�g���[�_�[�̓��b�N�ł��Ȃ��Ȃ�܂��B"
if %errorlevel% equ 1 (
    set disable_avb=1
    call :FlashImage "--slot=%slot% vbmeta --disable-verity --disable-verification", vbmeta.img
) else (
    call :FlashImage "--slot=%slot% vbmeta", vbmeta.img
)

if not exist super.img (
    echo ###############################
    echo #  logical partition��Flash   #
    echo ###############################
    if exist super_empty.img (
        call :WipeSuperPartition
    ) else (
        call :ResizeLogicalPartition
    )
    for %%i in (system system_ext product vendor odm) do (
        call :FlashImage %%i, %%i.img
    )
) else (
    echo ##################
    echo #  Super��Flash  #
    echo ##################
    call :FlashImage super, super.img
)

echo ##################################
echo #  vbmeta system/vendor��Flash   #
echo ##################################
for %%i in (vbmeta_system vbmeta_vendor) do (
    if %disable_avb% equ 1 (
        call :FlashImage "%%i --disable-verity --disable-verification", %%i.img
    ) else (
        call :FlashImage %%i, %%i.img
    )
)

echo ##############
echo #   �ċN��   #
echo ##############
choice /m "�V�X�e�����ċN�����܂���? �悭�킩��Ȃ��ꍇ�́uY�v�Ɠ��͂��Ă��������B"
if %errorlevel% equ 1 (
    %fastboot% reboot
)

echo ##########
echo #  ����  #
echo ##########
echo Stock ROM�̕������������܂����B
echo AVB�𖳌������Ă��Ȃ��ꍇ�́A�I�v�V�����Ńu�[�g���[�_�[�̍ă��b�N���ł���悤�ɂȂ�܂����B

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
    echo Error occured while switching to slot A. Aborting
    pause
    exit
)
exit /b

:WipeSuperPartition
%fastboot% wipe-super super_empty.img
if %errorlevel% neq 0 (
    echo Wiping super partition failed. Fallback to deleting and creating logical partitions
    call :ResizeLogicalPartition
)
exit /b

:ResizeLogicalPartition
for %%i in (system system_ext product vendor odm) do (
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
choice /m "%~1 continue? If unsure say N"
if %errorlevel% equ 2 (
    exit
)
exit /b