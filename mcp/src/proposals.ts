/**
 * Proposals live in this process's memory and nowhere else.
 *
 * That is deliberate. A proposal id is not a capability and cannot be replayed after a
 * restart, and there is no store for an agent to reach into and publish something a person
 * never saw. If the server restarts between propose and publish, the publish fails and the
 * agent proposes again, which costs one model call and is the correct trade.
 */
import type { ProposedDay, ProposedRange } from './format.js';

export interface Proposal {
  id: string;
  days: ProposedDay[];
  ranges: ProposedRange[];
  createdAt: number;
}

/** Long enough for a real conversation, short enough that a stale plan cannot resurface. */
const TTL_MS = 60 * 60 * 1000;

export class ProposalStore {
  private readonly items = new Map<string, Proposal>();
  private counter = 0;

  constructor(private readonly now: () => number = Date.now) {}

  create(days: ProposedDay[], ranges: ProposedRange[] = []): Proposal {
    this.sweep();
    this.counter += 1;
    const proposal: Proposal = { id: `p${this.counter}`, days, ranges, createdAt: this.now() };
    this.items.set(proposal.id, proposal);
    return proposal;
  }

  get(id: string): Proposal | undefined {
    this.sweep();
    return this.items.get(id);
  }

  /** Publishing consumes the proposal, so the same plan cannot be published twice. */
  take(id: string): Proposal | undefined {
    const proposal = this.get(id);
    if (proposal) this.items.delete(id);
    return proposal;
  }

  private sweep(): void {
    const cutoff = this.now() - TTL_MS;
    for (const [id, proposal] of this.items) {
      if (proposal.createdAt < cutoff) this.items.delete(id);
    }
  }
}
