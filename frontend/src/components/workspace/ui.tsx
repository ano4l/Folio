import { useEffect, useId, useRef, type ReactNode } from "react";
import { X, FileText, AlertCircle } from "lucide-react";
export function IconButton({
  label,
  children,
  onClick,
  disabled = false,
  className = "",
}: {
  label: string;
  children: ReactNode;
  onClick: () => void;
  disabled?: boolean;
  className?: string;
}) {
  return (
    <button
      type="button"
      className={`ws-icon ${className}`}
      title={label}
      aria-label={label}
      onClick={onClick}
      disabled={disabled}
    >
      {children}
    </button>
  );
}
export function Modal({
  title,
  children,
  onClose,
  wide = false,
}: {
  title: string;
  children: ReactNode;
  onClose: () => void;
  wide?: boolean;
}) {
  const titleId = useId(),
    ref = useRef<HTMLDivElement>(null),
    close = useRef(onClose);
  close.current = onClose;
  useEffect(() => {
    const previous = document.activeElement as HTMLElement | null;
    const targets = () =>
      Array.from(
        ref.current?.querySelectorAll<HTMLElement>(
          'button:not([disabled]),input:not([disabled]),textarea:not([disabled]),select:not([disabled]),a[href],[tabindex="0"]',
        ) || [],
      );
    targets()[0]?.focus();
    const key = (event: KeyboardEvent) => {
      if (event.key === "Escape") close.current();
      if (event.key === "Tab") {
        const items = targets();
        if (event.shiftKey && document.activeElement === items[0]) {
          event.preventDefault();
          items.at(-1)?.focus();
        } else if (!event.shiftKey && document.activeElement === items.at(-1)) {
          event.preventDefault();
          items[0]?.focus();
        }
      }
    };
    const overflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    document.addEventListener("keydown", key);
    return () => {
      document.removeEventListener("keydown", key);
      document.body.style.overflow = overflow;
      previous?.focus();
    };
  }, []);
  return (
    <div
      className="ws-modal-backdrop"
      onMouseDown={(event) => {
        if (event.target === event.currentTarget) onClose();
      }}
    >
      <div
        className={`ws-modal ${wide ? "wide" : ""}`}
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
        ref={ref}
      >
        <header>
          <h2 id={titleId}>{title}</h2>
          <IconButton label="Close dialog" onClick={onClose}>
            <X size={19} />
          </IconButton>
        </header>
        {children}
      </div>
    </div>
  );
}
export function Empty({
  title,
  children,
  action,
}: {
  title: string;
  children?: ReactNode;
  action?: ReactNode;
}) {
  return (
    <div className="ws-empty">
      <FileText size={28} />
      <h3>{title}</h3>
      {children && <p>{children}</p>}
      {action}
    </div>
  );
}
export function ErrorNotice({ message }: { message: string }) {
  return message ? (
    <p className="ws-error" role="alert">
      <AlertCircle size={16} />
      {message}
    </p>
  ) : null;
}
export function PageHeader({
  title,
  children,
  subtitle,
}: {
  title: string;
  children?: ReactNode;
  subtitle?: string;
}) {
  return (
    <header className="ws-page-header">
      <div>
        <h1>{title}</h1>
        {subtitle && <p>{subtitle}</p>}
      </div>
      <div className="ws-actions">{children}</div>
    </header>
  );
}
