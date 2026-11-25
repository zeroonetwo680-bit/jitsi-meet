import { IStore } from '../app/types';
import { IJitsiConference } from '../base/conference/reducer';
import { JitsiRecordingConstants } from '../base/lib-jitsi-meet';
import StateListenerRegistry from '../base/redux/StateListenerRegistry';
import { setStartRecordingIntent } from '../recording/actions.any';

import { shouldAutoRecord } from './functions';

/**
 * Conferences already handled: a moderator who stops the recording by hand must not have it started again.
 */
const attempted = new WeakSet<IJitsiConference>();

/**
 * Starts the file recording of a lecture as soon as a moderator whose token asks for it is in the room. Moderators come and go,
 * and the moderator role or the token features may arrive after joining, so this reacts to the state becoming true.
 */
StateListenerRegistry.register(
    /* selector */ shouldAutoRecord,
    /* listener */ (should: boolean, { dispatch, getState }: IStore) => {
        const { conference } = getState()['features/base/conference'];

        if (!should || !conference || attempted.has(conference)) {
            return;
        }

        attempted.add(conference);
        dispatch(setStartRecordingIntent({
            recording: true,
            transcription: false
        }));
        conference.startRecording({
            mode: JitsiRecordingConstants.mode.FILE,
            appData: JSON.stringify({ 'file_recording_metadata': { share: false } })
        });
    });
