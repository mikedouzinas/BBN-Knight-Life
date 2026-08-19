'use client';

import { useRef, useState } from 'react';
import type { IngestRequest } from './useIngest';

const ACCEPT = 'application/pdf,image/png,image/jpeg,image/gif,image/webp';
const MAX_BYTES = 4_500_000;

async function toBase64(file: File): Promise<string> {
  const buffer = await file.arrayBuffer();
  let binary = '';
  const bytes = new Uint8Array(buffer);
  for (let i = 0; i < bytes.length; i += 1) binary += String.fromCharCode(bytes[i]);
  return btoa(binary);
}

export function SourceForm({
  onSubmit,
  busy,
  textOnly = false,
}: {
  onSubmit: (request: IngestRequest) => void;
  busy: boolean;
  textOnly?: boolean;
}) {
  const [text, setText] = useState('');
  const [files, setFiles] = useState<File[]>([]);
  const [hintDate, setHintDate] = useState('');
  const [notes, setNotes] = useState('');
  const [error, setError] = useState<string | null>(null);
  const fileInput = useRef<HTMLInputElement>(null);

  const submit = async (event: React.FormEvent) => {
    event.preventDefault();
    setError(null);
    if (!text.trim() && !files.length) {
      setError('Paste the schedule, or attach the PDF or photo.');
      return;
    }
    const tooBig = files.find((f) => f.size > MAX_BYTES);
    if (tooBig) {
      setError(`${tooBig.name} is over 4.5 MB. Send a smaller scan, or paste the text.`);
      return;
    }
    const attachments = await Promise.all(
      files.map(async (file) => ({ mediaType: file.type, data: await toBase64(file), filename: file.name })),
    );
    onSubmit({
      text: text.trim() || undefined,
      attachments: attachments.length ? attachments : undefined,
      hintDate: hintDate || undefined,
      notes: notes.trim() || undefined,
    });
  };

  return (
    <form className="card" onSubmit={submit}>
      <h2>The schedule BB&amp;N sent</h2>

      <label htmlFor="source-text">Paste it</label>
      <textarea
        id="source-text"
        value={text}
        onChange={(e) => setText(e.target.value)}
        rows={12}
        placeholder={'Wednesday, September 4\n8:15-9:00  E\n9:05-9:50  C\n...'}
        disabled={busy}
      />

      {!textOnly && (
        <>
          <label htmlFor="source-file">Or attach a PDF or a photo</label>
          <input
            id="source-file"
            ref={fileInput}
            type="file"
            accept={ACCEPT}
            multiple
            disabled={busy}
            onChange={(e) => setFiles(Array.from(e.target.files ?? []))}
          />
          {files.length > 0 && (
            <p className="note">
              {files.map((f) => f.name).join(', ')}{' '}
              <button
                type="button"
                className="link"
                onClick={() => {
                  setFiles([]);
                  if (fileInput.current) fileInput.current.value = '';
                }}
              >
                remove
              </button>
            </p>
          )}
        </>
      )}

      <div className="row">
        <div>
          <label htmlFor="hint-date">Date, if the source is vague</label>
          <input id="hint-date" type="date" value={hintDate} onChange={(e) => setHintDate(e.target.value)} disabled={busy} />
        </div>
        <div className="grow">
          <label htmlFor="notes">Anything it should know</label>
          <input
            id="notes"
            type="text"
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            placeholder="Seniors are off campus after lunch"
            disabled={busy}
          />
        </div>
      </div>

      {error && <p className="error">{error}</p>}

      <button type="submit" className="primary" disabled={busy}>
        {busy ? 'Reading it...' : 'Read it'}
      </button>
      <p className="note">Nothing is published until you look at the result and press Publish.</p>
    </form>
  );
}
