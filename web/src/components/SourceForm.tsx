'use client';

import { useRef, useState } from 'react';
import type { IngestRequest } from './useIngest';
import { Glow } from './Glow';

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
      setError('Paste the message, or attach the PDF or photo.');
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
      <Glow size={300} intensity={0.1} />

      <h2>Schedule changer</h2>
      <p className="note lede">
        A snow day, a delayed start, an assembly schedule. Give it whatever BB&amp;N sent, in
        whatever form it arrived.
      </p>

      <label htmlFor="source-text">Paste the email, text, or note</label>
      <div className="field">
        <Glow size={120} intensity={0.26} />
        <textarea
          id="source-text"
          value={text}
          onChange={(e) => setText(e.target.value)}
          rows={12}
          placeholder={'Snow days Monday and Tuesday. Wednesday we come back on a delayed start,\nE 10:00-10:40, C 10:45-11:25...'}
          disabled={busy}
        />
      </div>

      {!textOnly && (
        <>
          <label htmlFor="source-file">Or attach the PDF or a photo of it</label>
          <div className="field">
            <Glow size={120} intensity={0.26} />
            <input
              id="source-file"
              ref={fileInput}
              type="file"
              accept={ACCEPT}
              multiple
              disabled={busy}
              onChange={(e) => setFiles(Array.from(e.target.files ?? []))}
            />
          </div>
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
          <label htmlFor="hint-date">Date, if the message does not say</label>
          <div className="field">
            <Glow size={110} intensity={0.26} />
            <input
              id="hint-date"
              type="date"
              value={hintDate}
              onChange={(e) => setHintDate(e.target.value)}
              disabled={busy}
            />
          </div>
        </div>
        <div className="grow">
          <label htmlFor="notes">Anything else it should know</label>
          <div className="field">
            <Glow size={140} intensity={0.26} />
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
      </div>

      {error && <p className="error">{error}</p>}

      <button type="submit" className="primary" disabled={busy}>
        <Glow size={140} intensity={0.3} color="255, 214, 130" />
        {busy ? 'Reading…' : 'Propose the change'}
      </button>
      <p className="note">
        You get one proposed day per card. Nothing reaches students until you check a card
        and press Publish on it.
      </p>
    </form>
  );
}
