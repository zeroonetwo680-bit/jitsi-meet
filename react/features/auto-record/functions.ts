import { IReduxState } from '../app/types';
import { getCurrentConference } from '../base/conference/functions';
import { MEET_FEATURES } from '../base/jwt/constants';
import { isJwtFeatureEnabled } from '../base/jwt/functions';
import { isLocalParticipantModerator } from '../base/participants/functions';
import { getRecordButtonProps, isRecordingRunning } from '../recording/functions';

/**
 * Whether this participant should start the lecture recording right now. The academy turns it on per lecture from the
 * dashboard ("Lecture room settings"): the moderator's token then carries `auto-record`. Only a moderator who is allowed to
 * record, in a room where file recording is available, and only while nothing is being recorded yet.
 *
 * @param {IReduxState} state - The redux state.
 * @returns {boolean}
 */
export function shouldAutoRecord(state: IReduxState) {
    if (!getCurrentConference(state)
            || !isLocalParticipantModerator(state)
            || !isJwtFeatureEnabled(state, MEET_FEATURES.AUTO_RECORD, false)
            || isRecordingRunning(state)) {
        return false;
    }

    const { recordingService } = state['features/base/config'];
    const { visible, disabled } = getRecordButtonProps(state);

    return Boolean(recordingService?.enabled && visible && !disabled);
}
