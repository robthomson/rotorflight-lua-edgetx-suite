---
title: Alignment
sidebar_label: Alignment
sidebar_position: 50
---

# Alignment

Set how the flight controller is mounted in the model -- its roll, pitch and yaw offsets and the
magnetometer's orientation -- and check the result on a live picture of the helicopter that follows
the board's attitude.

## Where to find it

*Configuration* → *Setup* → *Alignment*

Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| Roll | Board roll offset, in degrees, from -180 to 360. Disabled while Live View runs. |
| Pitch | Board pitch offset, in degrees, from -180 to 360. Disabled while Live View runs. |
| Yaw | Board yaw offset, in degrees, from -180 to 360. Disabled while Live View runs. |
| Mag | Magnetometer orientation: Default, CW 0/90/180/270 deg, the same four flipped, or Custom. Disabled while Live View runs. |
| Live View | Shows the board's attitude for 60 seconds, four readings a second; the button counts down and ends Live View early when pressed again. |
| Refresh | Reads the attitude once and redraws the picture. Disabled while Live View runs. |
| Save | Writes the offsets and the magnetometer orientation, then restarts the flight controller. |
| Reload | Reads the alignment from the flight controller again. |
| Star | Turns the view so the tail faces you, after a confirmation. |

## The live picture

The left panel shows the live roll, pitch and yaw, the offsets as set, the view's yaw, and the
nose direction (*Nose Up*, *Nose Down* or *Nose Level*, with *Leaning Left* or *Leaning Right*
when the board rolls more than 3.5 degrees). The picture on the right is the helicopter with the
offsets applied; its nose face is drawn in the accent colour.

The picture moves only when roll or pitch has changed by more than 0.3 degrees, or yaw has
changed, since it was last drawn, so a model lying still holds a steady picture. The readouts on
the left follow every reading.

## Notes

Saving restarts the flight controller, so the link drops for a moment after Save.

## Related

- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite 0.1.7.*
