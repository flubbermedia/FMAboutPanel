Purpose
--------------

FMAboutPanel is a class designed to show an "About Panel" with many useful features.

Supported OS & SDK Versions
-----------------------------

* Supported build target - iOS 5.1 (Xcode 4.4, Apple LLVM compiler 4.0)
* Earliest compatible deployment target - iOS 5.0

NOTE: 'Supported' means that the library has been tested with this version. 'Compatible' means that the library should work on this OS version (i.e. it doesn't rely on any unavailable SDK features) but is no longer being tested for compatibility and may require tweaking or bug fixes to run correctly.

ARC Compatibility
------------------

FMAboutPanel works only with ARC enabled.

Third party dependencies
------------------------

FMAboutPanel uses an external library to handle the unzipping of the remote file:
https://github.com/pixelglow/zipzap

and Chimpkit to handle the MailChimp newsletter signup functionality:
https://github.com/mailchimp/ChimpKit2