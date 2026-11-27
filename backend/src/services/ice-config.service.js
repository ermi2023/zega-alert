const stunServers = [
  { urls: 'stun:stun.l.google.com:19302' },
  { urls: 'stun:stun1.l.google.com:19302' },
];

export const buildIceServers = ({ turnUrls = [], turnUsername = '', turnCredential = '' }) => {
  if (!turnUrls.length) {
    if (turnUsername || turnCredential) {
      throw new Error('TURN_URLS, TURN_USERNAME, and TURN_CREDENTIAL must be configured together.');
    }
    return stunServers;
  }
  if (!turnUsername || !turnCredential) {
    throw new Error('TURN_URLS, TURN_USERNAME, and TURN_CREDENTIAL must be configured together.');
  }
  return [
    ...stunServers,
    ...turnUrls.map((urls) => ({
      urls,
      username: turnUsername,
      credential: turnCredential,
    })),
  ];
};
