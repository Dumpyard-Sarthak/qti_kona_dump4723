#!/vendor/bin/sh
if ! applypatch --check EMMC:/dev/block/bootdevice/by-name/recovery:134217728:814a13fed8371239be8279c912bbed8a6eb8da14; then
  applypatch  \
          --patch /vendor/recovery-from-boot.p \
          --source EMMC:/dev/block/bootdevice/by-name/boot:100663296:8b4eb5570d7771cb0681023f11cde48a124db834 \
          --target EMMC:/dev/block/bootdevice/by-name/recovery:134217728:814a13fed8371239be8279c912bbed8a6eb8da14 && \
      log -t recovery "Installing new oplus recovery image: succeeded" && \
      setprop ro.boot.recovery.updated true || \
      log -t recovery "Installing new oplus recovery image: failed" && \
      setprop ro.boot.recovery.updated false
else
  log -t recovery "Recovery image already installed"
  setprop ro.boot.recovery.updated true
fi
