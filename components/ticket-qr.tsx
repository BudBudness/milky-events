"use client";

import { QRCodeSVG } from "qrcode.react";

export default function TicketQr({ value }: { value: string }) {
  return <div style={{display:"inline-flex",background:"white",padding:12,borderRadius:12,border:"1px solid var(--line)"}}>
    <QRCodeSVG value={value} size={168} level="Q" includeMargin aria-label="Ticket QR code"/>
  </div>;
}
