#! /system/bin/sh

CURTIME=`date +%F_%H-%M-%S`
CURTIME_FORMAT=`date "+%Y-%m-%d %H:%M:%S"`

BASE_PATH=/sdcard/Android/data/com.oplus.logkit
SDCARD_LOG_BASE_PATH=${BASE_PATH}/files/Log
SDCARD_LOG_TRIGGER_PATH=${SDCARD_LOG_BASE_PATH}/trigger

DATA_DEBUGGING_PATH=/data/debugging
DATA_OPLUS_LOG_PATH=/data/persist_log
ANR_BINDER_PATH=${DATA_DEBUGGING_PATH}/anr_binder_info
CACHE_PATH=${DATA_DEBUGGING_PATH}/cache

config="$1"

#================================== COMMON LOG =========================

function transfer_log() {
    traceTransferState "TRANSFER_LOG3:start...."
    LOG_TYPE=`getprop persist.sys.debuglog.config`

    # mkdir by stoptime
    stoptime=`getprop sys.oplus.log.stoptime`
    newpath="${SDCARD_LOG_BASE_PATH}/log@stop@${stoptime}"
    mkdir -p ${newpath}

    #Custom transferModule
    transfer_logtype_${LOG_TYPE}
    setprop sys.tranfer.finished 1

    logcat -t 8000 > ${newpath}/transferlog_done_logcat.txt
    dmesg > ${newpath}/transferlog_done_dmesg.txt
    traceTransferState "TRANSFER_LOG:catch transfer dmesg & logcat done...."

    chmod 2770 ${BASE_PATH} -R
    SDCARDFS_ENABLED=`getprop external_storage.sdcardfs.enabled 1`
    traceTransferState "TRANSFER_LOG:SDCARDFS_ENABLED is ${SDCARDFS_ENABLED}"
    if [ "${SDCARDFS_ENABLED}" == "0" ]; then
        chown system:ext_data_rw ${SDCARD_LOG_BASE_PATH} -R
    fi

    #Zhangxueqiang@ANDROID.UPDATABILITY, 2020/11/24, add for save update_engine log
    mv ${SDCARD_LOG_BASE_PATH}/recovery_log/ ${newpath}/

    traceTransferState "TRANSFER_LOG:done...."
    mv ${SDCARD_LOG_BASE_PATH}/logkit_transfer.log ${newpath}/
    traceTransferState "TRANSFER_LOG3:done...."
}


function transferModules() {
    for element in ${moduleConfig[@]}
    do
        traceTransferState "${element}Business transfer start..."
        collect_modulelog_${element}
    done
}

function traceTransferState() {
    content=$1

    if [[ -d ${BASE_PATH} ]]; then
        if [[ ! -d ${SDCARD_LOG_BASE_PATH} ]]; then
            mkdir -p ${SDCARD_LOG_BASE_PATH}
            chmod 2770 ${BASE_PATH} -R
            echo "${CURTIME_FORMAT} TRACETRANSFERSTATE:${SDCARD_LOG_BASE_PATH} " >> ${SDCARD_LOG_BASE_PATH}/logkit_transfer.log
        fi

        currentTime=`date "+%Y-%m-%d %H:%M:%S"`
        echo "${currentTime} ${content} " >> ${SDCARD_LOG_BASE_PATH}/logkit_transfer.log
    fi

    LOG_LEVEL=$2
    if [[ "${LOG_LEVEL}" == "" ]]; then
        LOG_LEVEL=d
    fi
    log -p ${LOG_LEVEL} -t Debuglog ${content}
}

function checkNumberSizeAndCopy(){
    LOG_SOURCE_PATH="$1"
    LOG_TARGET_PATH="$2"
    LIMIT_SIZE="$3"
    LIMIT_NUM=500
    if [[ "${LIMIT_SIZE}" == "" ]]; then
        #500*1024KB
        LIMIT_SIZE="512000"
    fi
    traceTransferState "CHECKNUMBERSIZEANDCOPY:FROM ${LOG_SOURCE_PATH}"

    if [[ -d "${LOG_SOURCE_PATH}" ]] && [[ ! "`ls -A ${LOG_SOURCE_PATH}`" = "" ]]; then
        TMP_LOG_NUM=`ls -lR ${LOG_SOURCE_PATH} |grep "^-"|wc -l | awk '{print $1}'`
        TMP_LOG_SIZE=`du -s -k ${LOG_SOURCE_PATH} | awk '{print $1}'`
        traceTransferState "CHECKNUMBERSIZEANDCOPY:NUM:${TMP_LOG_NUM}/${LIMIT_NUM} SIZE:${TMP_LOG_SIZE}/${LIMIT_SIZE}"
        if [[ ${TMP_LOG_NUM} -le ${LIMIT_NUM} ]] && [[ ${TMP_LOG_SIZE} -le ${LIMIT_SIZE} ]]; then
            if [[ ! -d ${LOG_TARGET_PATH} ]];then
                mkdir -p ${LOG_TARGET_PATH}
            fi

            cp -rf ${LOG_SOURCE_PATH}/* ${LOG_TARGET_PATH}
            traceTransferState "CHECKNUMBERSIZEANDCOPY:${LOG_SOURCE_PATH} done" "i"
        else
            traceTransferState "CHECKNUMBERSIZEANDCOPY:${LOG_SOURCE_PATH} NUM:${TMP_LOG_NUM}/${LIMIT_NUM} SIZE:${TMP_LOG_SIZE}/${LIMIT_SIZE}" "e"
            rm -rf ${LOG_SOURCE_PATH}/*
        fi
    fi
}

function checkSmallSizeAndCopy(){
    LOG_SOURCE_PATH="$1"
    LOG_TARGET_PATH="$2"
    traceTransferState "CHECKSMALLSIZEANDCOPY:from ${LOG_SOURCE_PATH}"
    # 10M
    LIMIT_SIZE="10240"

    if [ -d "${LOG_SOURCE_PATH}" ]; then
        TMP_LOG_SIZE=`du -s -k ${LOG_SOURCE_PATH} | awk '{print $1}'`
        if [ ${TMP_LOG_SIZE} -le ${LIMIT_SIZE} ]; then  #log size less then 10M
            mkdir -p ${newpath}/${LOG_TARGET_PATH}
            cp -rf ${LOG_SOURCE_PATH}/* ${newpath}/${LOG_TARGET_PATH}
            traceTransferState "CHECKSMALLSIZEANDCOPY:${LOG_SOURCE_PATH} done"
        else
            traceTransferState "CHECKSMALLSIZEANDCOPY:${LOG_SOURCE_PATH} SIZE:${TMP_LOG_SIZE}/${LIMIT_SIZE}"
        fi
    fi
}

function checkNumberSizeAndMove(){
    LOG_SOURCE_PATH="$1"
    LOG_TARGET_PATH="$2"
    LOG_LIMIT_NUM="$3"
    LOG_LIMIT_SIZE="$4"
    traceTransferState "CHECKNUMBERSIZEANDMOVE:FROM ${LOG_SOURCE_PATH}"
    LIMIT_NUM=500
    #500*1024KB
    LIMIT_SIZE="512000"

    if [[ -d "${LOG_SOURCE_PATH}" ]] && [[ ! "`ls -A ${LOG_SOURCE_PATH}`" = "" ]]; then
        TMP_LOG_NUM=`ls -lR ${LOG_SOURCE_PATH} |grep "^-"|wc -l | awk '{print $1}'`
        TMP_LOG_SIZE=`du -s -k ${LOG_SOURCE_PATH} | awk '{print $1}'`
        traceTransferState "CHECKNUMBERSIZEANDMOVE:NUM:${TMP_LOG_NUM}/${LIMIT_NUM} SIZE:${TMP_LOG_SIZE}/${LIMIT_SIZE}"
        if [[ ${TMP_LOG_NUM} -le ${LIMIT_NUM} ]] && [[ ${TMP_LOG_SIZE} -le ${LIMIT_SIZE} ]]; then
            if [[ ! -d ${LOG_TARGET_PATH} ]];then
                mkdir -p ${LOG_TARGET_PATH}
            fi

            mv ${LOG_SOURCE_PATH}/* ${LOG_TARGET_PATH}
            traceTransferState "CHECKNUMBERSIZEANDMOVE:${LOG_SOURCE_PATH} done" "i"
        else
            traceTransferState "CHECKNUMBERSIZEANDMOVE:${LOG_SOURCE_PATH} NUM:${TMP_LOG_NUM}/${LIMIT_NUM} SIZE:${TMP_LOG_SIZE}/${LIMIT_SIZE}" "e"
            rm -rf ${LOG_SOURCE_PATH}/*
        fi
    fi
}

#=============================TYPES=============================#

function transfer_logtype_call() {
    moduleConfig=(common performance bluetooth power thirdpart stability recovery audio)
    transferModules
}

function transfer_logtype_media() {
    transfer_logtype_call
}

function transfer_logtype_bluetooth() {
    transfer_logtype_call
}

function transfer_logtype_gps() {
    transfer_logtype_call
}

function transfer_logtype_network() {
    transfer_logtype_call
}

function transfer_logtype_wifi() {
    transfer_logtype_call
}

function transfer_logtype_performance() {
    transfer_logtype_call
}

function transfer_logtype_stability() {
    transfer_logtype_call
}

function transfer_logtype_heat() {
    transfer_logtype_call
}

function transfer_logtype_power() {
    transfer_logtype_call
}

function transfer_logtype_charging() {
    transfer_logtype_call
}

function transfer_logtype_thirdpart() {
    transfer_logtype_call
}

function transfer_logtype_camera() {
    transfer_logtype_call
}

function transfer_logtype_sensor() {
    transfer_logtype_call
}

function transfer_logtype_touch() {
    transfer_logtype_call
}

function transfer_logtype_fingerprint() {
    transfer_logtype_call
}

function transfer_logtype_other() {
    transfer_logtype_call
}

#=============================MODULES=============================#

function collect_modulelog_common() {
    #dumpsys /data/debugging/SI_stop
    collect_function_common_dumpSystem
    #/data/debugging
    collect_function_common_debugging
    #/data/debugging/SI_stop
    collect_function_common_systemInfo
    #user
    collect_function_common_user
    #/sdcard/Android/data/com.oplus.logkit/files/Log/trigger
    collect_function_common_trigger
    #/data/media/${m}/Pictures/Screenshots
    collect_function_common_screenshots
    #mv wm
    collect_function_common_wm
    #/data/persist_log/  egrep -v 'DCS|data_vendor|TMP|hprofdump
    collect_function_common_persistLog
    #/data/persist_log/DCS/de
    collect_function_common_dcs
    #os app
    collect_function_common_systemApp
}

function collect_modulelog_performance() {
    #/data/local/traces
    collect_function_performance_systemTrace
}

function collect_modulelog_bluetooth() {
    #bluetooth log
    collect_function_bluetooth_default
}

function collect_modulelog_power() {
    #copy thermalrec and powermonitor log
    collect_function_power_default
}

function collect_modulelog_thirdpart() {
    #copy third-app log
    collect_function_thirdpart_default
    #Rui.Liu@ANDROID.DEBUG, 2020/09/17, Add for copy wxlog and qlog
    collect_function_thirdpart_wx
    collect_function_thirdpart_q
}

function collect_modulelog_stability() {
    #/data/tombstones
    collect_function_stability_tombstones
    #/data/persist_log/hprofdump
    collect_function_stability_hprofDump
}

function collect_modulelog_recovery() {
    #recovery
    collect_function_recovery_default
}

function collect_modulelog_audio() {
    #/data/persist_log/TMP/pcm_dump
    collect_function_audio_tmp
}


#=============================FUNCTIONS=============================#

#/data/debugging
function collect_function_common_debugging() {
    chmod -R 777 ${DATA_DEBUGGING_PATH}
    # filter SI_stop/
    traceTransferState "TRANSFERDEBUGGINGLOG start "
    if [ -d  ${DATA_DEBUGGING_PATH} ]; then
        ALL_SUB_DIR=`ls ${DATA_DEBUGGING_PATH} | grep -v SI_stop`
        for SUB_DIR in ${ALL_SUB_DIR};do
            if [ -d ${DATA_DEBUGGING_PATH}/${SUB_DIR} ] || [ -f ${DATA_DEBUGGING_PATH}/${SUB_DIR} ]; then
                cp ${DATA_DEBUGGING_PATH}/${SUB_DIR} ${newpath}
                traceTransferState "TRANSFERDEBUGGINGLOG:cp ${DATA_DEBUGGING_PATH}/${SUB_DIR} done"
            fi
        done
    fi
    traceTransferState "TRANSFERDEBUGGINGLOG done "
}

#dumpsys xxx > xxx.txt
function collect_function_common_dumpSystem() {
    setprop ctl.start dump_system
}

#/data/debugging/SI_stop
function collect_function_common_systemInfo() {
   DUMP_SYSTEM_LOG=${DATA_DEBUGGING_PATH}/SI_stop

    # before mv ${DATA_DEBUGGING_PATH}, wait for dumpmeminfo done
    count=0
    while [ $count -le 30 ] && [ ! -f ${DUMP_SYSTEM_LOG}/finish_system ];do
        traceTransferState "TRANSFERREALTIMELOG_DUMPSYSTEM:count=$count"
        count=$((count + 1))
        sleep 1
    done

    mv ${DUMP_SYSTEM_LOG} ${newpath}
}

#/data/persist_log/DCS/de
function collect_function_common_dcs() {
    TARGET_DATA_DCS_LOG=${newpath}/log/DCS

    DATA_DCS_LOG=${DATA_OPLUS_LOG_PATH}/DCS/de
    if [ -d  ${DATA_DCS_LOG} ]; then
        ALL_SUB_DIR=`ls ${DATA_DCS_LOG}`
        for SUB_DIR in ${ALL_SUB_DIR};do
            if [ -d ${DATA_DCS_LOG}/${SUB_DIR} ] || [ -f ${DATA_DCS_LOG}/${SUB_DIR} ]; then
                checkNumberSizeAndCopy "${DATA_DCS_LOG}/${SUB_DIR}" "${TARGET_DATA_DCS_LOG}/${SUB_DIR}"
            fi
        done
    fi

    DATA_DCS_OTRTA_LOG=${DATA_OPLUS_LOG_PATH}/backup
    if [ -d  ${DATA_DCS_LOG} ]; then
        ALL_SUB_DIR=`ls ${DATA_DCS_OTRTA_LOG}`
        for SUB_DIR in ${ALL_SUB_DIR};do
            if [ -d ${DATA_DCS_OTRTA_LOG}/${SUB_DIR} ] || [ -f ${DATA_DCS_OTRTA_LOG}/${SUB_DIR} ]; then
                checkNumberSizeAndCopy "${DATA_DCS_OTRTA_LOG}/${SUB_DIR}" "${TARGET_DATA_DCS_LOG}/${SUB_DIR}"
            fi
        done
    fi
}

#/data/persist_log/hprofdump
function collect_function_stability_hprofDump() {
    DATA_HPROF_LOG=${DATA_OPLUS_LOG_PATH}
    TARGET_DATA_HPROF_LOG=${newpath}/assistlog

    if [[ -d ${DATA_HPROF_LOG} ]]; then
        ALL_SUB_DIR=`ls ${DATA_HPROF_LOG} | grep hprofdump`
        for SUB_DIR in ${ALL_SUB_DIR};do
            if [[ -d ${DATA_HPROF_LOG}/${SUB_DIR} ]] || [[ -f ${DATA_HPROF_LOG}/${SUB_DIR} ]]; then
                checkAgingAndMove "${DATA_HPROF_LOG}/${SUB_DIR}" "${TARGET_DATA_HPROF_LOG}/${SUB_DIR}"
            fi
        done
    fi
}

#/data/persist_log/TMP/pcm_dump
function collect_function_audio_tmp() {
    DATA_TMP_LOG=${DATA_OPLUS_LOG_PATH}/TMP
    TARGET_DATA_TMP_LOG=${newpath}/log

    if [[ -d ${DATA_TMP_LOG} ]]; then
        ALL_SUB_DIR=`ls ${DATA_TMP_LOG}`
        for SUB_DIR in ${ALL_SUB_DIR};do
            if [[ -d ${DATA_TMP_LOG}/${SUB_DIR} ]] || [[ -f ${DATA_TMP_LOG}/${SUB_DIR} ]]; then
                checkNumberSizeAndMove "${DATA_TMP_LOG}/${SUB_DIR}" "${TARGET_DATA_TMP_LOG}/${SUB_DIR}"
            fi
        done
    fi
}

#/sdcard/Android/data/com.oplus.logkit/files/Log/trigger
function collect_function_common_trigger() {
    mv ${SDCARD_LOG_TRIGGER_PATH} ${newpath}/
}

#/data/media/${m}/Pictures/Screenshots
function collect_function_common_screenshots() {
    MAX_NUM=5
    is_release=`getprop ro.build.release_type`
    if [ x"${is_release}" != x"true" ]; then
        #Zhiming.chen@ANDROID.DEBUG.BugID 2724830, 2019/12/17,The log tool captures child user screenshots
        ALL_USER=`ls -t /data/media/`
        for m in $ALL_USER;
        do
            IDX=0
            screen_shot="/data/media/${m}/Pictures/Screenshots/"
            if [ -d "${screen_shot}" ]; then
                mkdir -p ${newpath}/Screenshots/$m
                touch ${newpath}/Screenshots/${m}/.nomedia
                ALL_FILE=`ls -t ${screen_shot}`
                for index in ${ALL_FILE};
                do
                    let IDX=${IDX}+1;
                    if [ "$IDX" -lt ${MAX_NUM} ] ; then
                       cp $screen_shot/${index} ${newpath}/Screenshots/${m}/
                       traceTransferState "${IDX}: ${index} done"
                    fi
                done
                traceTransferState "copy /${m} screenshots done"
            fi
        done
    fi
}

#/data/misc/bluetooth/logs
#/data/misc/bluetooth/cached_hci
function collect_function_bluetooth_default() {
    checkNumberSizeAndCopy "/data/misc/bluetooth/logs" "${newpath}/btsnoop_hci"
    #Laixin@CONNECTIVITY.BT.Basic.Log.70745, modify for auto capture hci log
    checkNumberSizeAndCopy "/data/misc/bluetooth/cached_hci" "${newpath}/btsnoop_hci"
}

#/data/system/thermal/dcs
#/data/system/thermalstats.bin
#/data/oplus/psw/powermonitor
#/data/oplus/psw/powermonitor_backup/
function collect_function_power_default() {
    # Add for thermalrec log
    dumpsys batterystats --thermalrec
    thermalrec_dir="/data/system/thermal/dcs"
    thermalstats_file="/data/system/thermalstats.bin"
    if [ -f ${thermalstats_file} ] || [ -d ${thermalrec_dir} ]; then
        mkdir -p ${newpath}/power/thermalrec/
        chmod 770 ${thermalstats_file}
        cp -rf ${thermalstats_file} ${newpath}/power/thermalrec/

        echo "copy Thermalrec..."
        chmod 770 /data/system/thermal/ -R
        cp -rf ${thermalrec_dir}/* ${newpath}/power/thermalrec/
    fi

    #Add for powermonitor log
    POWERMONITOR_DIR="/data/oplus/psw/powermonitor"
    chmod 770 ${POWERMONITOR_DIR} -R
    checkNumberSizeAndCopy "${POWERMONITOR_DIR}" "${newpath}/power/powermonitor"

    POWERMONITOR_BACKUP_LOG=/data/oplus/psw/powermonitor_backup/
    chmod 770 ${POWERMONITOR_BACKUP_LOG} -R
    checkNumberSizeAndCopy "${POWERMONITOR_BACKUP_LOG}" "${newpath}/power/powermonitor_backup"
}

#/sdcard/Android/data/com.tencent.tmgp.pubgmhd/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Logs
function collect_function_thirdpart_default() {
    #Chunbo.Gao@ANDROID.DEBUG.NA, 2019/6/21, Add for pubgmhd.ig
    app_pubgmhd_dir="/sdcard/Android/data/com.tencent.tmgp.pubgmhd/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Logs"
    if [ -d ${app_pubgmhd_dir} ]; then
        mkdir -p ${newpath}/os/Tencentlogs/pubgmhd
        echo "copy pubgmhd..."
        cp -rf ${app_pubgmhd_dir} ${newpath}/os/Tencentlogs/pubgmhd
    fi
    traceTransferState "transfer log:copy third app done"
}

#/sdcard/Android/data/com.tencent.mm/MicroMsg/xlog
#/sdcard/Android/data/com.tencent.mm/MicroMsg/crash
#/storage/ace-999/Android/data/com.tencent.mm/MicroMsg/xlog/$i
#Chunbo.Gao@ANDROID.DEBUG, 2020/01/17, Add for copy wx xlog
function collect_function_thirdpart_wx() {
    LOG_TYPE=`getprop persist.sys.debuglog.config`
    if [ "${LOG_TYPE}" != "thirdpart" ]; then
        return
    fi
    stoptime=`getprop sys.oplus.log.stoptime`;
    newpath="${SDCARD_LOG_BASE_PATH}/log@stop@${stoptime}"
    saveallxlog=`getprop sys.oplus.log.save_all_xlog`
    argtrue='true'
    XLOG_MAX_NUM=35
    XLOG_IDX=0
    XLOG_DIR="/sdcard/Android/data/com.tencent.mm/MicroMsg/xlog"
    CRASH_DIR="/sdcard/Android/data/com.tencent.mm/MicroMsg/crash"
    mkdir -p ${newpath}/wxlog
    if [ "${saveallxlog}" = "${argtrue}" ]; then
        mkdir -p ${newpath}/wxlog/xlog
        if [ -d "${XLOG_DIR}" ]; then
            cp -rf ${XLOG_DIR}/*.xlog ${newpath}/wxlog/xlog/
        fi
    else
        if [ -d "${XLOG_DIR}" ]; then
            mkdir -p ${newpath}/wxlog/xlog
            ALL_FILE=`find ${XLOG_DIR} -iname '*.xlog' | xargs ls -t`
            for i in $ALL_FILE;
            do
                echo "now we have Xlog file $i"
                let XLOG_IDX=$XLOG_IDX+1;
                echo ========file num is $XLOG_IDX===========
                if [ "$XLOG_IDX" -lt $XLOG_MAX_NUM ] ; then
                    #echo  $i >> ${newpath}/xlog/.xlog.txt
                    cp $i ${newpath}/wxlog/xlog/
                fi
            done
        fi
    fi
    setprop sys.tranfer.finished cp:xlog
    mkdir -p ${newpath}/wxlog/crash
    if [ -d "${CRASH_DIR}" ]; then
            cp -rf ${CRASH_DIR}/* ${newpath}/wxlog/crash/
    fi

    XLOG_IDX=0
    if [ "${saveallxlog}" = "${argtrue}" ]; then
        mkdir -p ${newpath}/sub_wxlog/xlog
        cp -rf /storage/ace-999/Android/data/com.tencent.mm/MicroMsg/xlog/* ${newpath}/sub_wxlog/xlog
    else
        if [ -d "/storage/ace-999/Android/data/com.tencent.mm/MicroMsg/xlog" ]; then
            mkdir -p ${newpath}/sub_wxlog/xlog
            ALL_FILE=`ls -t /storage/ace-999/Android/data/com.tencent.mm/MicroMsg/xlog`
            for i in $ALL_FILE;
            do
                echo "now we have subXlog file $i"
                let XLOG_IDX=$XLOG_IDX+1;
                echo ========file num is $XLOG_IDX===========
                if [ "$XLOG_IDX" -lt $XLOG_MAX_NUM ] ; then
                   echo  $i\!;
                    cp  /storage/ace-999/Android/data/com.tencent.mm/MicroMsg/xlog/$i ${newpath}/sub_wxlog/xlog
                fi
            done
        fi
    fi
    setprop sys.tranfer.finished cp:sub_wxlog
}

#/sdcard/Tencent/msflogs/com/tencent/mobileqq
#/storage/ace-999/Tencent/msflogs/com/tencent/mobileqq
#Rui.Liu@ANDROID.DEBUG, 2020/09/17, Add for copy qlog
function collect_function_thirdpart_q() {
    LOG_TYPE=`getprop persist.sys.debuglog.config`
    if [ "${LOG_TYPE}" != "thirdpart" ]; then
        return
    fi
    stoptime=`getprop sys.oplus.log.stoptime`;
    newpath="${SDCARD_LOG_BASE_PATH}/log@stop@${stoptime}"
    argtrue='true'
    QLOG_MAX_NUM=100
    QLOG_IDX=0
    QLOG_DIR="/sdcard/Tencent/msflogs/com/tencent/mobileqq"
    mkdir -p ${newpath}/qlog
    if [ -d "${QLOG_DIR}" ]; then
        mkdir -p ${newpath}/qlog
            Q_FILE=`find ${QLOG_DIR} -iname '*log' | xargs ls -t`
        for i in $Q_FILE;
        do
            echo "now we have Qlog file $i"
            let QLOG_IDX=$QLOG_IDX+1;
            echo ========file num is $QLOG_IDX===========
            if [ "$QLOG_IDX" -lt $QLOG_MAX_NUM ] ; then
                cp $i ${newpath}/qlog
            fi
        done
    fi
    setprop sys.tranfer.finished cp:qlog

    QLOG_IDX=0
    if [ -d "/storage/ace-999/Tencent/msflogs/com/tencent/mobileqq" ]; then
        mkdir -p ${newpath}/sub_qlog
        ALL_FILE=`ls -t /storage/ace-999/Tencent/msflogs/com/tencent/mobileqq`
        for i in $ALL_FILE;
        do
            echo "now we have subQlog file $i"
            let QLOG_IDX=$QLOG_IDX+1;
            echo ========file num is $QLOG_IDX===========
            if [ "$QLOG_IDX" -lt $QLOG_MAX_NUM ] ; then
               echo  $i\!;
                cp  /storage/ace-999/Tencent/msflogs/com/tencent/mobileqq/$i ${newpath}/sub_qlog
            fi
        done
    fi
    setprop sys.tranfer.finished cp:sub_qlog
}

#/data/tombstones
function collect_function_stability_tombstones() {
    mkdir -p ${newpath}/tombstones/
    cp /data/tombstones/tombstone* ${newpath}/tombstones/
}

#/cache/recovery
function collect_function_recovery_default() {
    setprop ctl.start mvrecoverylog
}

#/data/local/traces
function collect_function_performance_systemTrace() {
    SYSTRACE_PATH=/data/local/traces
    checkNumberSizeAndMove "${SYSTRACE_PATH}" "${newpath}/systrace"
}

#/sdcard/Documents/TraceLog
#/sdcard/Documents/OVMS
#/sdcard/Android/data/com.heytap.pictorial/files/xlog
#/sdcard/DCIM/Camera/spdebug
#/sdcard/Android/data/com.heytap.browser/files/xlog
#/sdcard/Android/data/com.oplus.onetrace/files/xlog
#/sdcard/Documents/*/.dog/* ${newpath}/os/
function collect_function_common_systemApp() {
    #TraceLog
    TRACELOG=/sdcard/Documents/TraceLog
    checkSmallSizeAndCopy "${TRACELOG}" "os/TraceLog"

    #OVMS
    OVMS_LOG=/sdcard/Documents/OVMS
    checkSmallSizeAndCopy "${OVMS_LOG}" "os/OVMS"

    #Pictorial
    PICTORIAL_LOG=/sdcard/Android/data/com.heytap.pictorial/files/xlog
    checkSmallSizeAndCopy "${PICTORIAL_LOG}" "os/Pictorial"

    #Camera
    CAMERA_LOG=/sdcard/DCIM/Camera/spdebug
    checkSmallSizeAndCopy "${CAMERA_LOG}" "os/Camera"

    #Browser
    BROWSER_LOG=/sdcard/Android/data/com.heytap.browser/files/xlog
    checkSmallSizeAndCopy "${BROWSER_LOG}" "os/com.heytap.browser"

    #MIDAS
    MIDAS_LOG=/sdcard/Android/data/com.oplus.onetrace/files/xlog
    checkSmallSizeAndCopy "${MIDAS_LOG}" "os/com.oplus.onetrace"

    #common path
    cp /sdcard/Documents/*/.dog/* ${newpath}/os/
    traceTransferState "transfer log:copy system app done"
}

#/data/debugging/wm/*
function collect_function_common_wm() {
    mkdir -p ${newpath}/wm
    mv -f ${DATA_DEBUGGING_PATH}/wm/* ${newpath}/wm
}

#/data/system/users/0
function collect_function_common_user() {
    stoptime=`getprop sys.oplus.log.stoptime`
    userpath="${SDCARD_LOG_BASE_PATH}/log@stop@${stoptime}"

    DATA_USER_LOG=/data/system/users/0
    TARGET_DATA_USER_LOG=${userpath}/user_0

    checkNumberSizeAndCopy "${DATA_USER_LOG}" "${TARGET_DATA_USER_LOG}"
}

#/data/persis_log/  egrep -v 'DCS|data_vendor|TMP|hprofdump
function collect_function_common_persistLog() {
    TARGET_DATA_OPLUS_LOG=${newpath}/log

    chmod 777 ${DATA_OPLUS_LOG_PATH}/ -R
    #tar -czvf ${newpath}/LOG.dat.gz -C ${DATA_OPLUS_LOG_PATH} .
    #tar -czvf ${TARGET_DATA_OPLUS_LOG}/LOG.tar.gz ${DATA_OPLUS_LOG_PATH}

    # filter DCS
    if [ -d  ${DATA_OPLUS_LOG_PATH} ]; then
        ALL_SUB_DIR=`ls ${DATA_OPLUS_LOG_PATH} | grep -v DCS | grep -v data_vendor | grep -v TMP | grep -v hprofdump`
        for SUB_DIR in ${ALL_SUB_DIR};do
            if [ -d ${DATA_OPLUS_LOG_PATH}/${SUB_DIR} ] || [ -f ${DATA_OPLUS_LOG_PATH}/${SUB_DIR} ]; then
                checkNumberSizeAndCopy "${DATA_OPLUS_LOG_PATH}/${SUB_DIR}" "${TARGET_DATA_OPLUS_LOG}/${SUB_DIR}"
            fi
        done
    fi
}

case "$config" in
    "transfer_log")
        transfer_log
        ;;
       *)

      ;;
esac
