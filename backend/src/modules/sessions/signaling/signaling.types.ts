// Shared WS message protocol for session signaling (video calls + chat).
// Keep in sync with frontend/lib/features/sessions/data/signaling_message_types.dart

export const SignalingMessageType = {
  ROOM_SNAPSHOT: "room-snapshot",
  PARTICIPANT_JOINED: "participant-joined",
  PARTICIPANT_LEFT: "participant-left",
  OFFER: "offer",
  ANSWER: "answer",
  ICE_CANDIDATE: "ice-candidate",
  CHAT_MESSAGE: "chat-message",
  SCREEN_SHARE_STATE: "screen-share-state",
  MIC_STATE: "mic-state",
  CAMERA_STATE: "camera-state",
  RECONNECTED_STATE: "reconnected-state",
  SESSION_ENDED: "session-ended",
  ERROR: "error",
} as const;

// Separate, payload-less protocol for the "/users/ws" channel (see
// user-registry.ts) — clients just refetch their sessions on receipt rather
// than the server shuttling session data through the socket.
export const NotificationMessageType = {
  SESSIONS_CHANGED: "sessions-changed",
} as const;

export interface CallParticipant {
  userId: string;
  name: string;
  isMicMuted: boolean;
  isCameraOff: boolean;
  isScreenSharing: boolean;
}

// ── Inbound (client → server) ──────────────────────────────────────────────

export interface OfferInbound {
  type: typeof SignalingMessageType.OFFER;
  targetUserId: string;
  sdp: string;
}

export interface AnswerInbound {
  type: typeof SignalingMessageType.ANSWER;
  targetUserId: string;
  sdp: string;
}

export interface IceCandidateInbound {
  type: typeof SignalingMessageType.ICE_CANDIDATE;
  targetUserId: string;
  candidate: string;
  sdpMid?: string | null;
  sdpMLineIndex?: number | null;
}

export interface ChatMessageInbound {
  type: typeof SignalingMessageType.CHAT_MESSAGE;
  content: string;
}

export interface ScreenShareStateInbound {
  type: typeof SignalingMessageType.SCREEN_SHARE_STATE;
  isScreenSharing: boolean;
}

export interface MicStateInbound {
  type: typeof SignalingMessageType.MIC_STATE;
  isMicMuted: boolean;
}

export interface CameraStateInbound {
  type: typeof SignalingMessageType.CAMERA_STATE;
  isCameraOff: boolean;
}

export type InboundSignalingMessage =
  | OfferInbound
  | AnswerInbound
  | IceCandidateInbound
  | ChatMessageInbound
  | ScreenShareStateInbound
  | MicStateInbound
  | CameraStateInbound;
