// Appended to config.js by the jitsi/web image (course platform defaults).
// Everyone joins with camera and microphone off. A choice remembered in the browser cannot override this
// (see getStartWithAudioMuted / getStartWithVideoMuted in react/features/base/media/functions.ts).
config.startWithVideoMuted = true;
config.startWithAudioMuted = true;
config.disableInitialGUM = false;

// Arabic first: the academy's audience. A language chosen in the settings dialog still wins.
config.defaultLanguage = 'ar';

// Who may turn the camera, microphone or screen sharing on is decided per role in the academy dashboard
// ("Lecture room settings") and travels in the token's context.features. The buttons below are hidden for
// anyone the token does not allow (react/features/media-permissions/functions.ts); without a token the
// camera stays hidden and off.
// The instructor starts and stops the lecture recording from the main toolbar, not from the "more" menu. Buttons a
// participant may not use (students: camera, screen share, recording) are skipped and the next button takes the slot.
config.mainToolbarButtons = [
    [ 'microphone', 'camera', 'desktop', 'recording', 'chat', 'raisehand', 'participants-pane', 'tileview' ],
    [ 'microphone', 'camera', 'desktop', 'recording', 'chat', 'raisehand', 'participants-pane' ],
    [ 'microphone', 'camera', 'recording', 'chat', 'raisehand', 'participants-pane' ],
    [ 'microphone', 'camera', 'recording', 'chat', 'participants-pane' ],
    [ 'microphone', 'camera', 'recording', 'chat' ],
    [ 'microphone', 'recording', 'chat' ],
    [ 'microphone', 'recording' ]
];

// Everyone sees the recording label and the start / stop notifications.
config.hideRecordingLabel = false;

config.toolbarButtons = [
    'microphone',
    'camera',
    'desktop',
    'recording',
    'chat',
    'raisehand',
    'participants-pane',
    'tileview',
    'fullscreen',
    'settings',
    'security',
    'hangup'
];
