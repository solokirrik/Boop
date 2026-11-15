# Debugging Scripts


___
**<p align=center>Debugging is only available in dev builds.</p>**
___

## Getting a dev build

To use debugging tools, you need a dev (Debug) build of Boop. Since macOS 13.3, JavaScriptCore (the thing that runs scripts) only lets Safari inspect scripts when the app opts in, and Boop does that in Debug builds only.

Dev builds aren't signed for distribution, so you need to make your own. For this, you'll need Xcode (free on the Mac App Store or the [Apple Developer Website](https://developer.apple.com)). Once you have it:

- Clone this repository, or download its source code.
- Open `Boop/Boop.xcodeproj` in Xcode.
- Make sure the `Boop` scheme is selected, then press ⌘R (or the play button in the top left corner). The dev build starts.

## Preparing the debugger

To see your script in the debugger, you'll need to run that script at least once. It does not matter if it doesn't work, Boop just needs to know you want to use it.

After running your script, open Safari. If you've never used its developer tools, open `Safari > Settings…`, go to the `Advanced` tab and enable `Show features for web developers`. This adds the `Develop` menu.

## Connecting the debugger

Your script now appears in Safari's `Develop` menu, in the submenu named after your Mac (in the screenshot, it's `Ivan MKII`; yours will be different), under the `Boop` section. Select the script you'd like to debug.

<p align="center">
  <img src="Images/developMenu.png?raw=true" width="663" alt="Safari's Develop menu listing a Boop script">
</p>

If you see `No Inspectable Applications`, please double check that:

- Boop is running
- It is a dev build (run from Xcode, not the copy in `/Applications`)
- You used your script at least once

## Using the debugger

The debugger is Safari's Web Inspector and works just like any in-browser inspector. The `Sources` tab shows the source of your script. *Editing it there will not affect the script within Boop, and any change will be lost.*

## Modules

Modules are shown as separate files in the `Sources` sidebar. You'll notice that a module's source has some added code above and below, surrounded with tags like this:

```javascript
/***********************************
*     Start of Boop's wrapper      *
***********************************/
```

This is how Boop makes sure modules are safe and compatible. The wrapper is added at runtime. It ain't pretty but it gets the job done.

## Console

When the debugger is active, the `console` object gets enabled. Use the `Console` tab, or the console at the bottom of the inspector, to read the output and use the interactive prompt.

Anything posted to the console before opening the debugger is recorded and shown when you open it, so you don't need to rush to open the debugger to see initialization messages, for example.

Please note that `console` is not available in non-debug builds, and using it will cause your script to throw an exception.

## Breakpoints

You can use breakpoints in the debugger, just like in any programming environment: click a line number in the `Sources` tab. The best place for one is somewhere called by the `main()` function.

When a breakpoint is hit, the inspector shows the current scope and variables in its sidebar, lets you step over or into code from its toolbar, and keeps the console available for interacting with the paused script.

While the breakpoint is active, Boop will become unresponsive. To make Boop usable again, resume the script with the continue (play) button in the debugger.

## Reloading scripts

When reloading scripts within Boop, the debugger **will not** automatically reload. If you want to check a new version of your script, close the debugger, run the script again for it to register, then re-open the debugger.

Leaving the debugger open will not release the previous version of the script, and therefore duplicates will show in the `Develop` menu.

When reopening previously opened scripts (even from a previous development session), the debugger will remember any breakpoints you set. Keep that in mind when debugging a module, as it's easy to forget you had a breakpoint in there.


## Final wisdom

Just like any software development environment, there is inherent danger in using those tools if you don't know what you're doing. Use at your own risk, avoid clicking stuff you don't know, and be nice to people.
