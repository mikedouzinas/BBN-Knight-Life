import Link from 'next/link';

export default function Home() {
  return (
    <>
      <h1>Knight Life admin</h1>
      <div className="card">
        <p>
          BB&amp;N sends a schedule change. Paste it, or drop in the PDF or a photo of it. The tool reads it,
          shows you the result as the students will see it, and publishes only after you say it is right.
        </p>
        <p>
          <Link href="/admin">Open the tool</Link>
        </p>
        <p className="note">
          You need a Knight Life admin account. An existing admin adds one by creating a document at
          admins/your-email in Firestore. There is no other list.
        </p>
      </div>
      <div className="card">
        <h2>Want to see it without an account?</h2>
        <p className="note">
          <Link href="/demo">The demo</Link> runs the same screens against nothing. It cannot write a schedule.
        </p>
      </div>
    </>
  );
}
