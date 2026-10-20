import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Milky Events | Discover Mbarara",
  description: "Discover local events and get digital tickets with Milky Events.",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
