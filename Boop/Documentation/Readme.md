# Boop

Hey there! Thanks for trying out Boop. This documentation should hopefully help you understand how it works, how you can extend it, and how you can contribute back.

## Child Pages

 - [Custom Scripts](CustomScripts.md)
 - [Modules](Modules.md)
 - [Debugging Scripts](Debugging.md)
 - [Converting Node Modules](ConvertingNodeModules.md)

## Getting Boop

This fork has no prebuilt releases. Clone the repository and follow the build instructions in the [README](../../README.md).

## Using Boop

Boop is pretty easy to use: Open it, paste some text, run some scripts, optionally copy the text out.

To run scripts, open the script picker by pressing `⌘P` (`⇧⌘P` and the classic `⌘B` work too) or in the top menu under `Scripts > Open Picker`. 

From the script picker, start typing to search for a script. You can then press `Enter ⏎` to pick the first script, or use the arrow keys to select another one. 

You can run the last script again by pressing `⇧⌘B` or from the option in the scripts menu.

To start over, you can clear the editor by pressing `⌘N`. 

If you are developing scripts, you can reload all the script by pressing `⇧⌘R` or  from the script menu as well.

## Questions

### Can I see a list of all scripts?

Yes! Simply open the script picker and search for `*`.

### Why can't I open/Save a file?

Because that's not the goal of Boop. It's not really an editor, more of an unstructured limbo for your plain text pasted content.

### Where can I find more scripts?

You can find more functions in the [Scripts folder](../../Scripts). It contains scripts suggested by the community that are not in the built-in script library. You can go there to find new functionality, or suggest your own!

### Can I make my own scripts?

Yes! Simply follow the instruction in the [Custom Scripts page](CustomScripts.md) to know how to get started.

### Does Boop collect data on me?

No. Boop makes no network requests of its own; the only links it opens are the Help and script pages, in your browser, when you ask for them.

### How can I report a problem?

The best way to do that is to [file an issue on GitHub](https://github.com/solokirrik/Boop/issues/new).

### How is Boop built?

Boop is a fork of [Boop by Ivan Mathy](https://github.com/IvanMathy/Boop). It is built in Swift with AppKit only, no third-party Swift packages; the editor is a standard `NSTextView`. Scripts are JavaScript, run with JavaScriptCore. The bundled [modules](Modules.md) are small wrappers over CryptoKit and Foundation, plus js-yaml and Papa Parse. Go ahead and open some of the scripts to check their license!

### Do I have to say "Boop" out loud when I press ⌘+B?

Yes.
