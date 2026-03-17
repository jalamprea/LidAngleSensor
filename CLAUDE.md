# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

LidAngleSensor is a macOS utility that reads the MacBook's internal lid angle sensor via IOKit HID and displays the angle in real-time. It optionally plays audio that responds to lid movement — either a door creak sound (sample-based) or a theremin tone (synthesized sine wave).

Written in Objective-C as a native Cocoa app. No Swift, no SwiftUI, no storyboards — the UI is built programmatically in `AppDelegate.m`.

## Build

Open `LidAngleSensor.xcodeproj` in Xcode and build (Cmd+B). Requires Xcode; tested on Xcode 26.

There is no command-line build system, test suite, or linter configured.

## Architecture

**Sensor layer** — `LidAngleSensor.h/.m`
- Interfaces with the HID device via IOKit (`IOHIDManager`, `IOHIDDevice`)
- Hard-coded to Apple VID `0x05AC`, PID `0x8104`, Sensor page `0x0020`, Orientation usage `0x008A`
- Reads a 3-byte feature report; bytes 1-2 are a 16-bit little-endian angle value in degrees
- Returns `-2.0` on read failure
- Known not to work on M1 devices

**Audio engines** — two independent engines, both conforming to an informal protocol (`startEngine`, `stopEngine`, `updateWithLidAngle:`, `isEngineRunning`, `currentVelocity`, `setAngularVelocity:`)
- `CreakAudioEngine` — plays a looping `CREAK_LOOP.wav` via `AVAudioPlayerNode` + `AVAudioUnitVarispeed`. Slow lid movement = loud creak; fast movement = silent. Gain and pitch are smoothly ramped.
- `ThereminAudioEngine` — real-time sine wave synthesis via `AVAudioSourceNode` render block. Lid angle maps to frequency (110–440 Hz), velocity modulates volume. Includes vibrato.

Both engines share the same multi-stage signal processing pipeline: raw angle → EMA smoothing → velocity calculation with movement threshold → velocity smoothing + decay → parameter mapping via smoothstep → smooth ramping to target values.

**UI layer** — `AppDelegate.m`
- Programmatic window with Auto Layout constraints
- 60Hz `NSTimer` polls the sensor and updates both the display and the active audio engine
- `NSLabel` is a small `NSTextField` subclass configured as a non-editable label

## Key Constants

Audio tuning constants are defined as `static const` at the top of each engine's `.m` file (deadzone, velocity thresholds, smoothing factors, ramp times). These are the primary knobs for adjusting audio behavior.

## Hardware Compatibility

The sensor was introduced with the 2019 16-inch MacBook Pro. Does not work on M1 devices. The app also works on iMacs (the sensor reports desk tilt). Users whose sensor isn't detected should run the diagnostic gist linked in the README.
