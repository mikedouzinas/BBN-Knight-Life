'use client';

/**
 * The tool itself, with no idea whether it is talking to Firestore or to a mock. Both
 * pages render this component and differ only in the options they hand `useIngest`.
 */
import { SourceForm } from './SourceForm';
import { DayCard } from './DayCard';
import { useIngest, type UseIngestOpts } from './useIngest';

export function IngestTool({
  options,
  textOnly = false,
  publishLabel,
}: {
  options: UseIngestOpts;
  textOnly?: boolean;
  publishLabel?: string;
}) {
  const tool = useIngest(options);

  return (
    <>
      <SourceForm onSubmit={tool.read} busy={tool.reading} textOnly={textOnly} />

      {tool.error && <p className="error card">{tool.error}</p>}

      {tool.message && !tool.days.length && !tool.reading && <p className="card note">{tool.message}</p>}

      {tool.rejected.length > 0 && (
        <div className="card">
          <h3>Could not be read</h3>
          <p className="note">These were rejected by the schema and were never publishable. Fix the source or type them in.</p>
          {tool.rejected.map((entry, index) => (
            <ul key={index} className="warnings">
              {entry.issues.map((issue) => (
                <li key={issue}>{issue}</li>
              ))}
            </ul>
          ))}
        </div>
      )}

      {tool.days.map((candidate) => (
        <DayCard
          key={candidate.date}
          candidate={candidate}
          publishing={tool.publishing === candidate.date}
          publishedDetail={tool.published[candidate.date]}
          onPublish={() => tool.publish({ date: candidate.date, day: candidate.day })}
          onDiscard={() => tool.discard(candidate.date)}
          publishLabel={publishLabel}
        />
      ))}
    </>
  );
}
