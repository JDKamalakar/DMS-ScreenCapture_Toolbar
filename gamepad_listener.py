#!/usr/bin/env python3
import struct
import sys
import glob
import os
import subprocess
import time
import select

def log(msg):
    with open('/tmp/gamepad_log.txt', 'a') as f:
        f.write(f"{time.time()}: {msg}\n")

def get_joysticks():
    return glob.glob('/dev/input/js*')

def main():
    log("Started gamepad_listener.py")
    fds = {}
    
    def scan_devices():
        for dev in get_joysticks():
            if dev not in fds:
                try:
                    f = open(dev, 'rb')
                    fds[dev] = f
                    log(f"Opened joystick: {dev}")
                except Exception as e:
                    log(f"Failed to open {dev}: {e}")

    axis_state = {}
    last_scan = 0
    has_joystick = None

    while True:
        now = time.time()
        if now - last_scan > 2:
            scan_devices()
            last_scan = now
            
        current_has_joystick = len(fds) > 0
        if current_has_joystick != has_joystick:
            has_joystick = current_has_joystick
            log(f"Joystick connected status changed to: {has_joystick}")
            subprocess.Popen([
                "dms", "ipc", "screenCaptureToolbar", 
                "controllerConnectionChange", "true" if has_joystick else "false"
            ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        if not fds:
            time.sleep(1)
            continue
            
        ready, _, _ = select.select(list(fds.values()), [], [], 1.0)
        
        for f in ready:
            try:
                ev_buf = f.read(8)
                if not ev_buf:
                    dev = [k for k, v in fds.items() if v == f][0]
                    f.close()
                    del fds[dev]
                    continue
                    
                time_ms, value, type_, number = struct.unpack('IhBB', ev_buf)
                if type_ & 0x80:
                    continue
                    
                btn_name = None
                if type_ == 1 and value == 1:
                    if number == 0: btn_name = "A"
                    elif number == 1: btn_name = "B"
                    elif number == 4: btn_name = "LB"
                    elif number == 5: btn_name = "RB"
                    elif number == 6: btn_name = "LT"
                    elif number == 7: btn_name = "RT"
                    elif number == 8: btn_name = "HOME" # Guide button
                    # Fallback for D-Pad as buttons (common on some drivers)
                    elif number == 11: btn_name = "UP"
                    elif number == 12: btn_name = "DOWN"
                    elif number == 13: btn_name = "LEFT"
                    elif number == 14: btn_name = "RIGHT"
                elif type_ == 2:
                    is_pressed = value > 16000
                    was_pressed = axis_state.get(f"{f.fileno()}_{number}_pos", False)
                    if is_pressed and not was_pressed:
                        if number == 2: btn_name = "LT"
                        elif number == 5: btn_name = "RT"
                        elif number == 6: btn_name = "RIGHT"
                        elif number == 7: btn_name = "DOWN"
                    axis_state[f"{f.fileno()}_{number}_pos"] = is_pressed
                    
                    is_neg = value < -16000
                    was_neg = axis_state.get(f"{f.fileno()}_{number}_neg", False)
                    if is_neg and not was_neg:
                        if number == 6: btn_name = "LEFT"
                        elif number == 7: btn_name = "UP"
                    axis_state[f"{f.fileno()}_{number}_neg"] = is_neg
                
                if btn_name:
                    log(f"Triggered action: {btn_name}")
                    subprocess.Popen([
                        "dms", "ipc", "screenCaptureToolbar", 
                        f"controllerAction{btn_name}"
                    ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            except Exception as e:
                dev = [k for k, v in fds.items() if v == f][0]
                f.close()
                del fds[dev]

if __name__ == "__main__":
    main()
