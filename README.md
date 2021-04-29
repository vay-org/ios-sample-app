# IOS Sample App

A minimalistic app that demonstrates some basic aspects of how to utilize [Vay's API][1].

The single screen app's working code does the following:
- Following [this][2] guide, camera images are extracted and passed to the view controller.
- A connection to the server is setup and a listener defined that handles server responses.
- The camera images are properly formated, scaled and converted to be sent to the server.
- A preview of the camera is shown.
- The received keypoints are used to visualize a skeleton on the preview.
- Correct reps are counted and a single (out of possibly multiple) correction is shown for incorrect reps.

Note that screen rotation is not handled and therefore the apps orientation is locked in portrait mode. 

Also feel free to change the exercise key to test other exercises.

###### Important: The server address has been ommited, as this is a publicly accessable repo.

[1]: https://api.docs.vay.ai/
[2]: https://medium.com/ios-os-x-development/ios-camera-frames-extraction-d2c0f80ed05a
