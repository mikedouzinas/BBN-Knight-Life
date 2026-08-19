'use client';

/**
 * The sandbox. Same components, two overrides: a planner route that holds no Firestore
 * client, and a publish function that only ever writes to this page's own state. There
 * is no code path from here to the school's data, which is what makes it safe to leave
 * open (HQ-613).
 */
import { useCallback, useState } from 'react';
import { IngestTool } from '@/components/IngestTool';
import type { PublishOutcome } from '@/components/useIngest';
import type { DatedScheduleDay } from '@/lib/schedule/types';
import { deriveLegacyDay } from '@/lib/schedule/derive';
import { toCanonicalKey } from '@/lib/schedule/dates';

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

  return (
    <>
      <h1>Demo</h1>
      <p className="banner">
        This is not the real tool. It reads pasted text and shows you the result, and publishing here
        writes to this page and nowhere else. {published.length > 0 && `${published.length} pretend published.`}
      </p>
      <IngestTool options={{ ingestUrl: '/api/demo/ingest', publishDay }} textOnly publishLabel="Pretend to publish" />
    </>
  );
}
