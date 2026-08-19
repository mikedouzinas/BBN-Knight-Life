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

export function Glow({
  color = '202, 226, 255',
  intensity = 0.4,
  size = 200,
}: {
  color?: string;
  intensity?: number;
  size?: number;
}) {
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
