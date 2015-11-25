# Guppy Pro Image Acquisition

The AVT Guppy Pro is a compact firewire camera, easily adapted for MOT monitoring and catch imaging applications in ultracold experiments. 

## Installation:
**Quick install**: double click `ImageAcquisitionGUI.mlappinstall`. This installs a packaged app into the "Apps" tab of MATLAB.

**Full install**: clone this repo, add path, and run `ImageAqcuisitionGUI.m`

## Usage
1) Plug in a Guppy Pro camera and run the program

2) Select a device in the upper right corner

3) To use continuous mode (live-view), click on Start Preview

4) To take a single picture, click on Manual snapshot

5) To change the exposure time, click on camera settings

6) To trigger a single acquisition, connect a Guppy trigger cable, and set the exposure time. Click on Acquire One.

7) To mark an image, click on Mark toolbox, set a threshold and save the mark edge. Show the mark in preview to see it while changing stuff on the monitor.

## To do
- Improve this readme
- Fix Acquire repeatedly and abort (both of these cause the program to crash).