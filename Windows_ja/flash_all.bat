@echo off
title Nothing Phone (1) Fastboot ROM Flasher (t.me/NothingPhone1)

echo ###########################################################
echo #                Pong Fastboot ROM Flasher                #
echo #                       �J��/�e�X�g��                          #
echo #  HELLBOY017�Aviralbanda�Aspike0en�APHATwalrus�Aarter97      #
echo #          [Nothing Phone (2) Telegram Dev Team]          #
echo #                [Nothing Phone (1)�ɂ��g�p�\]              #
echo ###########################################################

cd %~dp0

if not exist platform-tools-latest (
    curl -L https://dl.google.com/android/repository/platform-tools-latest-windows.zip -o platform-tools-latest.zip
    Call :UnZipFile "%~dp0platform-tools-latest", "%~dp0platform-tools-latest.zip"
    del /f /q platform-tools-latest.zip
)

set fastboot=.\platform-tools-latest\platform-tools\fastboot.exe
if not exist %fastboot% (
    echo Fastboot�����s�ł��܂���B���~���܂��B
    pause
    exit
)

set boot_partitions=boot vendor_boot dtbo recovery
set firmware_partitions=abl aop aop_config bluetooth cpucp devcfg dsp featenabler hyp imagefv keymaster modem multiimgoem multiimgqti qupfw qweslicstore shrm tz uefi uefisecapp xbl xbl_config xbl_ramdump
set logical_partitions=system system_ext product vendor odm
set vbmeta_partitions=vbmeta_system vbmeta_vendor

echo #############################
echo #    FASTBOOT�f�o�C�X�̊m�F       #
echo #############################
%fastboot% devices

%fastboot% getvar current-slot 2>&1 | find /c "current-slot: a" > tmpFile.txt
set /p active_slot= < tmpFile.txt
del /f /q tmpFile.txt
if %active_slot% equ 0 (
    echo #############################
    echo #      �A�N�e�B�u�X���b�g��A�ɕύX      #
    echo #############################
    call :SetActiveSlot
)

echo ###################
echo #   �f�[�^�̃t�H�[�}�b�g    #
echo ###################
choice /m "�f�[�^���������܂����H"
if %errorlevel% equ 1 (
    echo �u���̃p�[�e�B�V�������t�H�[�}�b�g���܂����H�v�̌x���͖������Ă��������B
    call :ErasePartition userdata
    call :ErasePartition metadata
)

echo ############################
echo #     �u�[�g�p�[�e�B�V�����̃t���b�V��     #
echo ############################
choice /m "�����̃X���b�g�ɃC���[�W���t���b�V�����܂����H �悭������Ȃ��ꍇ��N�Ɠ����Ă��������B"
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
echo #    FASTBOOTD�ɍċN��      #       
echo ##########################
%fastboot% reboot fastboot
if %errorlevel% neq 0 (
    echo fastbootd�ɍċN�����ɃG���[���������܂����B���~���܂��B
    pause
    exit
)

echo #####################
echo #   �t�@�[���E�F�A�̃t���b�V��   #
echo #####################
for %%i in (%firmware_partitions%) do (
    call :FlashImage "--slot=%slot% %%i", %%i.img
)

echo ###################
echo #  VBMETA�̃t���b�V��   #
echo ###################
set disable_avb=0
choice /m "Android Verified Boot�𖳌��ɂ��܂����H �悭������Ȃ��ꍇ��N�Ɠ����Ă��������BY��I������ƃu�[�g���[�_�[�����b�N�ł��Ȃ��Ȃ�܂��B"
if %errorlevel% equ 1 (
    set disable_avb=1
    call :FlashImage "--slot=%slot% vbmeta --disable-verity --disable-verification", vbmeta.img
) else (
    call :FlashImage "--slot=%slot% vbmeta", vbmeta.img
)

echo ###############################
echo #      �_���p�[�e�B�V�����̃t���b�V��       #
echo ###############################
echo �_���p�[�e�B�V�����C���[�W���t���b�V�����܂����H
echo �J�X�^��ROM���C���X�g�[������ꍇ��N�Ɠ����Ă��������B
choice /m "�悭������Ȃ��ꍇ��Y�Ɠ����Ă��������B"
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
echo #      ����VBMETA�p�[�e�B�V�����̃t���b�V��      #
echo ####################################
for %%i in (%vbmeta_partitions%) do (
    if %disable_avb% equ 1 (
        call :FlashImage "%%i --disable-verity --disable-verification", %%i.img
    ) else (
        call :FlashImage %%i, %%i.img
    )
)

echo #############
echo #   �ċN��    #
echo #############
choice /m "�V�X�e���ɍċN�����܂����H �悭������Ȃ��ꍇ��Y�Ɠ����Ă��������B"
if %errorlevel% equ 1 (
    %fastboot% reboot
)

echo ########
echo #  ���� #
echo ########
echo Stock firmware restored.
echo �K�v�ɉ����ău�[�g���[�_�[���ă��b�N�ł��܂��iAndroid Verified Boot�������ɂȂ��Ă��Ȃ��ꍇ�j�B

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
    echo �X���b�gA�ɐ؂�ւ���ۂɃG���[���������܂����B���~���܂��B
    pause
    exit
)
exit /b

:WipeSuperPartition
%fastboot% wipe-super super_empty.img
if %errorlevel% neq 0 (
    echo �X�[�p�[�p�[�e�B�V�����̏����Ɏ��s���܂����B�_���p�[�e�B�V�����̍폜�ƍ쐬�Ƀt�H�[���o�b�N���܂��B
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
choice /m "%~1 ���s���܂����H �悭������Ȃ��ꍇ��N�Ɠ����Ă��������B"
if %errorlevel% equ 2 (
    exit
)
exit /b
