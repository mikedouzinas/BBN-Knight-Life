/**
 * An in-memory ScheduleStore. This is what the demo route and the tests publish into,
 * and it is why the publish path can be tested without a single write to production.
 */
import type { ScheduleDay } from './types';
import type { PublishPlan, ScheduleStore } from './publish';

export class MemoryScheduleStore implements ScheduleStore {
  readonly canonical = new Map<string, ScheduleDay>();
  readonly legacy = new Map<string, unknown>();
  readonly commits: PublishPlan[] = [];

  constructor(seed?: Record<string, ScheduleDay>) {
    for (const [key, day] of Object.entries(seed ?? {})) this.canonical.set(key, day);
  }

  async commit(plan: PublishPlan): Promise<void> {
    this.canonical.set(plan.canonicalKey, plan.canonicalValue);
    this.legacy.set(plan.legacyId, plan.legacyDoc);
    this.commits.push(plan);
  }

  async readDay(isoDate: string): Promise<ScheduleDay | null> {
    const [y, m, d] = isoDate.split('-').map(Number);
    return this.canonical.get(`${y}/${m}/${d}`) ?? null;
  }
}
