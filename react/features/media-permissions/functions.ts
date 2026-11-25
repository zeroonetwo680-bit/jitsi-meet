import { IReduxState } from '../app/types';
import { MEET_FEATURES } from '../base/jwt/constants';
import { isJwtFeatureEnabled } from '../base/jwt/functions';

/**
 * Whether the local participant may turn the camera on. Granted only by the `camera` feature of the token
 * (set per role from the academy dashboard). Without a token, or a token without the feature, the camera stays off.
 *
 * @param {IReduxState} state - The redux state.
 * @returns {boolean}
 */
export function isCameraAllowed(state: IReduxState) {
    return isJwtFeatureEnabled(state, MEET_FEATURES.CAMERA, false);
}

/**
 * Whether the local participant may unmute the microphone. Allowed unless the token says `microphone: false`.
 *
 * @param {IReduxState} state - The redux state.
 * @returns {boolean}
 */
export function isMicrophoneAllowed(state: IReduxState) {
    return isJwtFeatureEnabled(state, MEET_FEATURES.MICROPHONE, true);
}

/**
 * Toolbar and pre-join buttons to hide because the token does not allow what they turn on.
 *
 * @param {IReduxState} state - The redux state.
 * @returns {string[]}
 */
export function getMediaPermissionHiddenButtons(state: IReduxState) {
    const hidden: string[] = [];

    if (!isCameraAllowed(state)) {
        hidden.push('camera', 'select-background');
    }
    if (!isMicrophoneAllowed(state)) {
        hidden.push('microphone');
    }
    if (!isJwtFeatureEnabled(state, MEET_FEATURES.SCREEN_SHARING, true)) {
        hidden.push('desktop');
    }

    return hidden;
}
