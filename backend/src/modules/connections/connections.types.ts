// The addressee-facing view of a Connection, collapsed from the raw
// ConnectionStatus + which side the caller is on — this is what other
// modules (users, matching) annotate their listings with.
export type ConnectionStatusView = "NONE" | "REQUESTED" | "CONNECTED";
