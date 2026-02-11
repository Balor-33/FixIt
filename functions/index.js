const admin = require('firebase-admin');
const logger = require('firebase-functions/logger');
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {
  onDocumentCreated,
  onDocumentUpdated,
} = require('firebase-functions/v2/firestore');

admin.initializeApp();

function buildDataPayload(input = {}) {
  const output = {};
  for (const [key, value] of Object.entries(input)) {
    if (value === undefined || value === null) continue;
    output[key] = String(value);
  }
  return output;
}

function normalizeTopic(value = '') {
  return String(value)
    .trim()
    .toLowerCase()
    .replace(/[^a-zA-Z0-9-_.~%]/g, '_');
}

function jobTopicForCategory(category = '') {
  return `jobs_${normalizeTopic(category)}`;
}

exports.sendNotificationToUser = onCall(async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError('unauthenticated', 'Authentication required.');
  }

  const {
    userId,
    title = 'FixIt',
    body = '',
    type = 'general',
    issueId,
    threadId,
    data = {},
  } = request.data || {};

  if (!userId) {
    throw new HttpsError('invalid-argument', 'userId is required.');
  }

  const userDoc = await admin.firestore().collection('users').doc(userId).get();
  const token = userDoc.data()?.fcmToken;

  if (!token) {
    throw new HttpsError('not-found', 'No FCM token found for this user.');
  }

  const payload = {
    token,
    notification: {title, body},
    data: buildDataPayload({type, issueId, threadId, ...data}),
    android: {priority: 'high'},
    apns: {
      payload: {
        aps: {
          sound: 'default',
        },
      },
    },
  };

  const messageId = await admin.messaging().send(payload);
  logger.info('Sent user notification', {userId, messageId});

  return {ok: true, messageId};
});

exports.sendNotificationToTopic = onCall(async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError('unauthenticated', 'Authentication required.');
  }

  const {
    topic,
    title = 'FixIt',
    body = '',
    type = 'general',
    issueId,
    threadId,
    data = {},
  } = request.data || {};

  if (!topic) {
    throw new HttpsError('invalid-argument', 'topic is required.');
  }

  const payload = {
    topic,
    notification: {title, body},
    data: buildDataPayload({type, issueId, threadId, ...data}),
    android: {priority: 'high'},
    apns: {
      payload: {
        aps: {
          sound: 'default',
        },
      },
    },
  };

  const messageId = await admin.messaging().send(payload);
  logger.info('Sent topic notification', {topic, messageId});

  return {ok: true, messageId};
});

exports.notifyProfessionalsOnNewIssue = onDocumentCreated(
  'issues/{issueId}',
  async (event) => {
    const issueId = event.params.issueId;
    const issueData = event.data?.data();
    if (!issueData) return;

    const title = issueData.title || 'New job available';
    const category = issueData.category || 'General Repair';
    const address = issueData.address || '';
    const topic = jobTopicForCategory(category);

    const payload = {
      topic,
      notification: {
        title: 'New job available',
        body: `${title} - ${category}${address ? ` near ${address}` : ''}`,
      },
      data: buildDataPayload({
        type: 'job_assigned',
        issueId,
        category,
      }),
      android: {priority: 'high'},
      apns: {
        payload: {
          aps: {
            sound: 'default',
          },
        },
      },
    };

    const messageId = await admin.messaging().send(payload);
    logger.info('Notified professionals about new issue', {
      issueId,
      topic,
      messageId,
    });
  },
);

exports.notifyCustomerOnIssueAccepted = onDocumentUpdated(
  'issues/{issueId}',
  async (event) => {
    const issueId = event.params.issueId;
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();

    if (!before || !after) return;

    if (before.status === 'accepted' || after.status !== 'accepted') {
      return;
    }

    const customerId = after.customerId;
    if (!customerId) {
      logger.warn('Missing customerId for accepted issue', {issueId});
      return;
    }

    const customerDoc = await admin
      .firestore()
      .collection('users')
      .doc(customerId)
      .get();

    const customerToken = customerDoc.data()?.fcmToken;
    if (!customerToken) {
      logger.warn('Customer has no FCM token', {issueId, customerId});
      return;
    }

    const professionalId = after.assignedProfessionalId || '';
    let professionalName = 'A professional';

    if (professionalId) {
      const professionalDoc = await admin
        .firestore()
        .collection('users')
        .doc(professionalId)
        .get();
      const professionalData = professionalDoc.data() || {};
      professionalName =
        professionalData.displayName ||
        professionalData.name ||
        professionalData.email ||
        professionalName;
    }

    const payload = {
      token: customerToken,
      notification: {
        title: 'Your job was accepted',
        body: `${professionalName} accepted your request.`,
      },
      data: buildDataPayload({
        type: 'job_accepted',
        issueId,
        professionalId,
      }),
      android: {priority: 'high'},
      apns: {
        payload: {
          aps: {
            sound: 'default',
          },
        },
      },
    };

    const messageId = await admin.messaging().send(payload);
    logger.info('Notified customer for accepted issue', {
      issueId,
      customerId,
      messageId,
    });
  },
);
