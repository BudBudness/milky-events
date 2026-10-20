"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

export async function submitOrganizerApplication(formData: FormData) {
  const supabase = await createClient();
  if (!supabase) redirect("/organizer?error=setup");
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login?next=/organizer");

  const name = String(formData.get("name") ?? "").trim();
  const description = String(formData.get("description") ?? "").trim();
  const contactPhone = String(formData.get("contact_phone") ?? "").trim();
  if (name.length < 2 || name.length > 160 || contactPhone.length < 7 || contactPhone.length > 40) {
    redirect("/organizer?error=invalid");
  }

  const { error } = await supabase.from("organizers").insert({
    user_id: user.id,
    name,
    description: description || null,
    contact_phone: contactPhone,
    status: "pending",
  });
  if (error) redirect("/organizer?error=save");
  revalidatePath("/organizer");
  redirect("/organizer?submitted=1");
}
