'use client';

/**
 * The sandbox. Same components, two overrides: a planner route that holds no Firestore
 * client, and a publish function that only ever writes to this page's own state. There
 * is no code path from here to the school's data, which is what makes it safe to leave
 * open (HQ-613).
 */
import { withBasePath } from '@/lib/basePath';
import { useCallback, useState } from 'react';
import { IngestTool } from '@/components/IngestTool';
import type { PublishOutcome } from '@/components/useIngest';
import type { DatedScheduleDay } from '@/lib/schedule/types';
import { deriveLegacyDay } from '@/lib/schedule/derive';
import { toBreakKey, toCanonicalKey } from '@/lib/schedule/dates';
import type { ScheduleRange } from '@/lib/schedule/schema';

export default function DemoPage() {
  const [published, setPublished] = useState<DatedScheduleDay[]>([]);

  const publishDay = useCallback(async (day: DatedScheduleDay): Promise<PublishOutcome> => {
    setPublished((prev) => [...prev.filter((d) => d.date !== day.date), day]);
    const legacy = deriveLegacyDay(day.date, day.day);
    return {
      ok: true,
      detail: `Nothing was written. The real tool would write schedules/special.${toCanonicalKey(day.date)} and special-schedules/${legacy.id}.`,
    };
  }, []);

  // The sandbox needs its own range stub for the same reason it needs publishDay: without an
  // override, useIngest would POST to the real /api/admin/publish-range. The demo's guarantee
  // is that nothing it does can reach Firestore, and that guarantee is per-write-path.
  const publishRange = useCallback(async (range: ScheduleRange): Promise<PublishOutcome> => {
    return {
      ok: true,
      detail: `Nothing was written. The real tool would write schedules/break.${toBreakKey(range.startDate, range.endDate)}.`,
    };
  }, []);

  return (
    <>
      <h1>Demo</h1>
      <p className="banner">
        This is not the real tool. It reads pasted text and shows you the result, and publishing here
        writes to this page and nowhere else. {published.length > 0 && `${published.length} pretend published.`}
      </p>
      <IngestTool options={{ ingestUrl: withBasePath('/api/demo/ingest'), publishDay, publishRange }} textOnly publishLabel="Pretend to publish" />
    </>
  );
}
