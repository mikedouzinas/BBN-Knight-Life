import 'server-only';
import type { Messaging } from 'firebase-admin/messaging';
import type { Notifier, PushMessage } from './scheduleNotify';

export class FcmNotifier implements Notifier {
  constructor(private readonly messaging: Messaging) {}

  async send(message: PushMessage): Promise<void> {
    await this.messaging.send({
      topic: message.topic,
      notification: { title: message.title, body: message.body },
    });
  }
}
