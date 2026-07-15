# SneakyTimer

## Problem

As a parent of a child who responds well to visual timers, I often need to increase or decrease the remaining time. However, I don’t always have the patience or energy to explain why the duration needs to change.

I wanted a simple iPhone app that would let me adjust a visual timer without drawing attention to the change. Most visual timer apps I found either require restarting the timer or make it obvious that the remaining time has been modified.

That’s why I built SneakyTimer.

SneakyTimer is a visual timer that lets parents display one duration while the timer follows another. While the timer is running, you can increase or decrease the actual remaining time by subtly changing the speed of the countdown. The displayed timer continues moving naturally, making the adjustment far less noticeable.

<p align="center">
  <img src="docs/sneakytimer-demo.gif" alt="SneakyTimer app demonstration" width="320">
</p>

## Install On Your iPhone

You need a Mac, an iPhone, and a USB cable to install SneakyTimer on your iPhone. If you need help, I suggest asking an AI assistant to walk you through it step by step. Just copy and paste this prompt:

```
I want to install an iPhone app from GitHub onto my own iPhone using Xcode. Please guide me one step at a time and wait for me to confirm each step before continuing.

The app is called SneakyTimer. I need help with:
- installing Xcode
- downloading the GitHub repository (https://github.com/guidolang/sneakytimer)
- opening `SneakyTimer.xcodeproj` in Xcode
- selecting my iPhone as the run destination
- setting up Signing & Capabilities with my Apple ID
- changing the bundle identifier if necessary
- running the app on my iPhone
- enabling Developer Mode or trusting the developer account if iOS asks

Also explain that without an active Apple Developer Program membership, the app will need to be reinstalled after 7 days.
```


## Development

Build:

```sh
xcodebuild build -project SneakyTimer.xcodeproj -scheme SneakyTimer -destination 'platform=iOS Simulator,name=iPhone 17'
```

Test:

```sh
xcodebuild test -project SneakyTimer.xcodeproj -scheme SneakyTimer -destination 'platform=iOS Simulator,name=iPhone 17'
```

## Privacy

SneakyTimer does not collect, store, or transmit personal data. Everything is stored locally on the device.

## Support

For support, bug reports, or feature requests, please open a [GitHub issue](https://github.com/guidolang/sneakytimer/issues).
