#!/bin/bash

BT_PARAM="/data/params/d/BluetoothEnabled"
if [ -f "$BT_PARAM" ] && [ "$(< $BT_PARAM)" == "1" ]; then
  echo "Enabling Bluetooth"
  systemctl start btattach
else
  echo "Disabling Bluetooth"
  systemctl stop btattach
fi
