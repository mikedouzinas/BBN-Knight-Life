'use client';

/**
 * A cursor-following glow clipped to its parent, ported from mikeveson.com's
 * ContainedMouseGlow. The parent must be `position: relative` and `overflow: hidden`
 * so the clip follows its corner radius.
 *
 * One shared mousemove listener across every mounted instance, reference counted. The
 * portfolio learned this the hard way: a listener per glow means a hundred identical
 * handlers running on every mousemove, a cost that scales with how much is on screen and
 * never shows up in a render profile.
 *
 * Renders nothing on touch-only devices, where a cursor glow has nothing to follow.
 */
import { useEffect, useRef, useState } from 'react';

const pointer = { x: 0, y: 0 };
let subscribers = 0;
function onMove(e: MouseEvent) {
  pointer.x = e.clientX;
  pointer.y = e.clientY;
}
function subscribe(): () => void {
  if (subscribers === 0) window.addEventListener('mousemove', onMove);
  subscribers += 1;
  return () => {
    subscribers -= 1;
    if (subscribers === 0) window.removeEventListener('mousemove', onMove);
  };
}

/**
 * The ceiling on a glow, in pixels.
 *
 * Past about this width the effect stops reading as a point of light following the cursor
 * and starts reading as an inward glow washing the whole surface, which is the thing
 * globals.css says this design does not do. The card glows had drifted to 280 and 300,
 * where it is most visible because those cards are the widest.
 *
 * Clamped here rather than left as a convention. A convention about a number comes back the
 * first time somebody types `size={300}` on a narrow card where it looks fine.
 */
const MAX_SIZE = 160;

export function Glow({
  color = '202, 226, 255',
  intensity = 0.4,
  size: requestedSize = MAX_SIZE,
}: {
  color?: string;
  intensity?: number;
  size?: number;
}) {
  const size = Math.min(requestedSize, MAX_SIZE);
  const dot = useRef<HTMLDivElement>(null);
  const [fine, setFine] = useState(false);

  useEffect(() => {
    if (!window.matchMedia('(pointer: fine)').matches) return;
    setFine(true);
    const unsubscribe = subscribe();
    let frame = 0;
    const tick = () => {
      const el = dot.current;
      const host = el?.parentElement?.parentElement;
      if (el && host) {
        const box = host.getBoundingClientRect();
        const inside =
          pointer.x >= box.left && pointer.x <= box.right &&
          pointer.y >= box.top && pointer.y <= box.bottom;
        el.style.opacity = inside ? '1' : '0';
        if (inside) {
          el.style.left = `${pointer.x - box.left - size / 2}px`;
          el.style.top = `${pointer.y - box.top - size / 2}px`;
        }
      }
      frame = requestAnimationFrame(tick);
    };
    frame = requestAnimationFrame(tick);
    return () => {
      cancelAnimationFrame(frame);
      unsubscribe();
    };
  }, [size]);

  if (!fine) return null;

  return (
    <div className="glow-layer" aria-hidden>
      <div
        ref={dot}
        className="glow-dot"
        style={{
          width: size,
          height: size,
          background: `radial-gradient(circle, rgba(${color}, ${intensity}) 0%, rgba(${color}, ${intensity * 0.45}) 40%, rgba(${color}, 0) 70%)`,
        }}
      />
    </div>
  );
}
